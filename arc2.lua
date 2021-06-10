------------------------------------------------------------------------------
-- Aergo Standard NFT Interface (Proposal) - 20210425
------------------------------------------------------------------------------

-- A internal type check function
-- @type internal
-- @param x variable to check
-- @param t (string) expected type
local function _typecheck(x, t)
    if (x and t == 'address') then
      assert(type(x) == 'string', "address must be string type")
      -- check address length
      assert(52 == #x, string.format("invalid address length: %s (%s)", x, #x))
      -- check character
      local invalidChar = string.match(x, '[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
      assert(nil == invalidChar, string.format("invalid address format: %s contains invalid char %s", x, invalidChar or 'nil'))
    elseif (x and t == 'str128') then
      assert(type(x) == 'string', "str128 must be string type")
      -- check address length
      assert(128 >= #x, string.format("too long str128 length: %s", #x))
    else
      -- check default lua types
      assert(type(x) == t, string.format("invalid type: %s != %s", type(x), t or 'nil'))
    end
end

address0 = '1111111111111111111111111111111111111111111111111111'

state.var {
    _name = state.value(), -- token name
    _symbol = state.value(), -- token symbol
    --additional value
    _baseURI = state.value(), -- base uri (contract creator updatable)
    _keepAddress = state.value(), -- ether swap 등 요청시 옮겨놓는 지갑주소.
    _burnAddress = state.value(), -- 소각시 옮겨놓는 지갑주소.
    _isMinterEveryOne = state.value(), -- mint 함수 호출 가능 여부 값.
    --minter 관련 변수들
    _isMinters = state.map(),
    _minters = state.array(1000000),
    _minterIndex = state.value(),
    --delegation white list
    _delegationAllowList = state.map(),

    _owners = state.map(), -- unsigned_bignum -> address
    _tokens = state.map(), -- owner 의 address를 주면 tokenId array 를 반환.
    _balances = state.map(), -- address -> unsigned_bignum
    _tokenApprovals = state.map(), -- unsigned_bignum -> address
    _operatorApprovals = state.map(), -- address/address -> bool
}

-- call this at constructor
local function _init(name, symbol)
    _typecheck(name, 'string')
    _typecheck(symbol, 'string')

    _name:set(name)
    _symbol:set(symbol)
    _minterIndex:set(1)
    _isMinterEveryOne:set(false)
end


-- Approve `to` to operate on `tokenId`
-- Emits a approve event
local function _approve(to, tokenId)
  _tokenApprovals[tokenId] = to
  contract.event("approve", ownerOf(tokenId), to, tokenId)
end


local function _exists(tokenId)
  owner = _owners[tokenId] or address0
  return owner ~= address0
end

local function _callOnARC2Received(from, to, tokenId, ...)
  if to ~= address0 and system.isContract(to) then
    contract.call(to, "onARC2Received", system.getSender(), from, tokenId, ...)
  end
end

local function setTokens(to, tokenId)
  local tokens = {}
  if _tokens[to] ~= nil then
    tokens = _tokens[to]
  end
  table.insert(tokens, tokenId);
  _tokens[to] = tokens;
end

local function removeTokens(owner, tokenId)
  local tokens = {}
  if _tokens[owner] ~= nil then
    tokens = _tokens[owner]
  end
  for i, v in ipairs (tokens) do
      if (v == tokenId) then
        table.remove(tokens, i);
        break
      end
  end
  _tokens[owner] = tokens;
end

function getTokensByAddress(address)
  return _tokens[address];
end

local function _mint(to, tokenId)
  _typecheck(to, 'address')
  _typecheck(tokenId, 'str128')

  assert(to ~= address0, "ARC2: mint - to the zero address")
  assert(not _exists(tokenId), "ARC2: mint - already minted token")

  _balances[to] = (_balances[to] or bignum.number(0)) + 1
  _owners[tokenId] = to
  setTokens(to, tokenId);

  contract.event("transfer", address0, to, tokenId)
end

function constructor()
  _init('cccv_test_token', 'CTT')
  setBaseURI('test::9090')
  setKeepAddress('AmPVco1XU9PMghEzNZzVuXo5Cr8dnX3c5uKraYah91pk9s1E7caW')
  setBurnAddress('AmQEki2sncw5ujB97B9GwFMb34ZvzzCQPVHxUGLQF3rMrLWSDmjm')
  setMinter(system.getSender(), true)
  setDelegationAllow(system.getSender(), true)
end

function setIsMinterEveryOne(b)
  _typecheck(b, 'boolean')
  _isMinterEveryOne:set(b)
  contract.event("setIsMinterEveryOne", b)
end

function mint(to, tokenId)
  assert(_isMinterEveryOne:get(), "ARC2: mint - _isMinterEveryOne false")
  _mint(to, tokenId)
end

function safeMint(to, tokenId)
  _minterCheck()
  _delegationAllowCheck()
  _mint(to, tokenId)
end

-- Get a token name
-- @type    query
-- @return  (string) name of this token
function name()
  return _name:get()
end


-- Get a token symbol
-- @type    query
-- @return  (string) symbol of this token
function symbol()
  return _symbol:get()
end

local function getBaseURI()
  return _baseURI:get();
end

function setBaseURI(URIString)
  local uri = getBaseURI();
  _baseURI:set(URIString);
  contract.event("setBaseURI", uri, URIString)
end

local function getKeepAddress()
  return _keepAddress:get();
end

function setKeepAddress(address)
  _typecheck(address, 'address')
  local keepAddress = getKeepAddress();
  assert(system.getSender() == system.getCreator(), "ARC2: setKeepAddress - only contract creator can set keep address")
  _keepAddress:set(address);
  contract.event("setKeepAddress", keepAddress, address)
end

local function getBurnAddress()
  return _burnAddress:get();
end

function setBurnAddress(address)
  _typecheck(address, 'address')
  local burnAddress = getBurnAddress();
  assert(system.getSender() == system.getCreator(), "ARC2: setBurnAddress - only contract creator can set burnAddress")
  _burnAddress:set(address);
  contract.event("setBurnAddress", burnAddress, address)
end

-- Get a token URI
-- @type  query
-- @param tokenId (str128) token id
-- @return (string) URL for tokenId
function tokenURI(tokenId)
  assert(_exists(tokenId), "ARC2: tokenURI - nonexisting token")

  baseURI = getBaseURI()

  if (baseURI ~= "") then
    return baseURI .. tokenId
  end

  return "";
end

-- Count of all NFTs assigned to an owner
-- @type    query
-- @param   owner  (address) a target address
-- @return  (ubig) the number of NFT tokens of owner
function balanceOf(owner)
  assert(owner ~= address0, "ARC2: balanceOf - query for zero address")
  return _balances[owner] or bignum.number(0)
end


-- Find the owner of an NFT
-- @type    query
-- @param   tokenId (str128) the NFT id
-- @return  (address) the address of the owner of the NFT
function ownerOf(tokenId)
  owner = _owners[tokenId] or address0;
  assert(owner ~= address0, "ARC2: ownerOf - query for nonexistent token")
  return owner
end



-- Transfer a token of 'from' to 'to'
-- @type    call
-- @param   from    (address) a sender's address
-- @param   to      (address) a receiver's address
-- @param   tokenId (str128) the NFT token to send
-- @param   ...     (Optional) addtional data, MUST be sent unaltered in call to 'onARC2Received' on 'to'
-- @event   transfer(from, to, value)
function safeTransferFrom(from, to, tokenId, ...)
  _delegationAllowCheck()

  _typecheck(from, 'address')
  _typecheck(to, 'address')
  _typecheck(tokenId, 'str128')

  assert(_exists(tokenId), "ARC2: safeTransferFrom - nonexisting token")
  owner = ownerOf(tokenId)
  assert(owner == from, "ARC2: safeTransferFrom - transfer of token that is not own")
  assert(to ~= address0, "ARC2: safeTransferFrom - transfer to the zero address")

  spender = system.getSender()
  assert(spender == owner or getApproved(tokenId) == spender or isApprovedForAll(owner, spender), "ARC2: safeTransferFrom - caller is not owner nor approved")

  -- Clear approvals from the previous owner
  _approve(address0, tokenId)

  _balances[from] = _balances[from] - 1
  _balances[to] = (_balances[to] or bignum.number(0)) + 1
  _owners[tokenId] = to
  setTokens(to, tokenId)
  removeTokens(from, tokenId)

  _callOnARC2Received(from, to, tokenId, ...)

  contract.event("transfer", from, to, tokenId)
end

function keepARC2Token(from, tokenId, ...)
  assert(system.getSender() == system.getCreator(), "ARC2: keepARC2Token - only contract creator can mint")

  _typecheck(from, 'address')
  _typecheck(tokenId, 'str128')
  local keepAddress = getKeepAddress();
  _typecheck(keepAddress, 'address')

  assert(_exists(tokenId), "ARC2: keepARC2Token - nonexisting token")
  owner = ownerOf(tokenId)
  assert(owner == from, "ARC2: keepARC2Token - transfer of token that is not own")

  -- Clear approvals from the previous owner
  _approve(address0, tokenId)

  _balances[from] = _balances[from] - 1
  _balances[keepAddress] = (_balances[keepAddress] or bignum.number(0)) + 1
  _owners[tokenId] = keepAddress
  setTokens(keepAddress, tokenId)
  removeTokens(from, tokenId)

  _callOnARC2Received(from, keepAddress, tokenId, ...)

  contract.event("transfer", from, keepAddress, tokenId)
end

-- Change or reaffirm the approved address for an NFT
-- @type    call
-- @param   to          (address) the new approved NFT controller
-- @param   tokenId     (str128) the NFT token to approve
-- @event   approve(owner, to, tokenId)
function approve(to, tokenId)
  _typecheck(to, 'address')
  _typecheck(tokenId, 'str128')

  owner = ownerOf(tokenId)
  assert(owner ~= to, "ARC2: approve - to current owner")
  assert(system.getSender() == owner or isApprovedForAll(owner, system.getSender()),
    "ARC2: approve - caller is not owner nor approved for all")

  _approve(to, tokenId);
end

-- Get the approved address for a single NFT
-- @type    query
-- @param   tokenId  (str128) the NFT token to find the approved address for
-- @return  (address) the approved address for this NFT, or the zero address if there is none
function getApproved(tokenId)
  _typecheck(tokenId, 'str128')
  assert(_exists(tokenId), "ARC2: getApproved - nonexisting token")

  return _tokenApprovals[tokenId] or address0;
end


-- Allow operator to control all sender's token
-- @type    call
-- @param   operator  (address) a operator's address
-- @param   approved  (boolean) true if the operator is approved, false to revoke approval
-- @event   approvalForAll(owner, operator, approved)
function setApprovalForAll(operator, approved)
  _typecheck(operator, 'address')
  _typecheck(approved, 'boolean')

  assert(operator ~= system.getSender(), "ARC2: setApprovalForAll - to caller")
  _operatorApprovals[system.getSender() .. '/' .. operator] = approved

  contract.event("approvalForAll", system.getSender(), operator, approved)
end


-- Get allowance from owner to spender
-- @type    query
-- @param   owner       (address) owner's address
-- @param   operator    (address) allowed address
-- @return  (bool) true/false
function isApprovedForAll(owner, operator)
  return _operatorApprovals[owner .. '/' .. operator] or false
end

--minter
-- Set/Add minter.
-- @type call
-- @param minter (address)
-- @param state (boolean)
-- @event MinterSet(minter, state)
function setMinter(minter, state)
    assert(system.getSender() == system.getCreator(), "ARC2: setMinter - only contract creator can setMinter")
    _typecheck(minter, 'address')
    _typecheck(state, 'boolean')

    if nil == _isMinters[minter] then
        -- temporary code
        _minters[math.floor(_minterIndex:get())] = minter
        -- original code
        -- _minters[_minterIndex:get()] = minter
        _minterIndex:set(_minterIndex:get() + 1)
    end
    _isMinters[minter] = state
    contract.event("MinterSet", minter, state)
end

-- Get the minter state.
-- @type query
-- @param  minter (adderss) minter address.
-- @return (boolean) minter state.
function isMinter(minter)
    _typecheck(minter, 'address')
    return _isMinters[minter] or false;
end

-- Get minter address list.
-- @type query
-- @return  minter list.
function getMinters()
    local enables = {}
    local disables = {}
    local i =1
    local j = 1
    local k = 1
    while _minters[k] ~= nil do
        if _isMinters[_minters[k]] ==  true then
            enables[i] = _minters[k]
            i = i + 1
        else
            disables[j] = _minters[k]
            j = j + 1
        end
        k = k + 1
    end
    return enables, disables
end

function _minterCheck()
    assert(isMinter(system.getSender()), string.format("invalid minter: %s", system.getSender()))
end

function _delegationAllowCheck()
    assert(isDelegationAllow(system.getSender()), string.format("invalid fee_delegation sender: %s", system.getSender()))
end

function isDelegationAllow(address)
    _typecheck(address, 'address')
    if _delegationAllowList[address] ~= nil then
      return _delegationAllowList[address]
    end
    return false
end

function setDelegationAllow(address, state)
    assert(system.getSender() == system.getCreator(), "ARC2: setDelegationAllow - only contract creator can setDelegationAllow")
    _typecheck(address, 'address')
    _typecheck(state, 'boolean')

    _delegationAllowList[address] = state
    contract.event("setDelegationAllow", address, state)
end

function check_delegation(fname, arg0)
    if (fname == "safeMint" or fname == "safeTransferFrom") then
        return _delegationAllowList[system.getSender()]
    end
    return false
end

local function _burn(tokenId)
  _typecheck(tokenId, 'str128')

  local burnAddress = getBurnAddress();
  _typecheck(burnAddress, 'address')

  owner = ownerOf(tokenId)
  assert(burnAddress == owner, "ARC2: _burn - token already has burnAddress")

  -- Clear approvals from the previous owner
  _approve(address0, tokenId);

  _balances[owner] = _balances[owner] - 1
  _balances[burnAddress] = (_balances[burnAddress] or bignum.number(0)) + 1
  _owners[tokenId] = burnAddress
  setTokens(burnAddress, tokenId)
  removeTokens(owner, tokenId)

  _callOnARC2Received(owner, burnAddress, tokenId)

  contract.event("transfer", owner, burnAddress, tokenId)
end

function burn(tokenId)
  assert(_exists(tokenId), "ARC2: burn - nonexisting token")
  owner = ownerOf(tokenId)
  spender = system.getSender()
  assert(spender == owner or getApproved(tokenId) == spender or isApprovedForAll(owner, spender) or spender == system.getCreator(), "ARC2: burn - caller is not owner nor approved")

  _burn(tokenId)
end

abi.register(setApprovalForAll, safeTransferFrom, approve, mint, safeMint, burn, setKeepAddress, setBaseURI, keepARC2Token, setMinter, setIsMinterEveryOne, setDelegationAllow, setBurnAddress)
abi.register_view(name, symbol, balanceOf, ownerOf, getApproved, isApprovedForAll, tokenURI, getTokensByAddress, isMinter, getMinters)
abi.fee_delegation(safeMint, safeTransferFrom)
