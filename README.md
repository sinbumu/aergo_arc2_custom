# aergo_arc2_custom
aergo arc2 contract custom example


arc2.lua #초기 arc2 샘플 기반으로 만든 컨트랙트 예

arc2_receiver.lua #arc2 토큰을 받을 수 있는 컨트랙트의 경우 필요한 함수 예

arc2_proxy.lua #프록시 컨트랙트를 쓰기로 한뒤 사용한 프록시 컨트랙트 예

arc2_proxy_logic_mk1.lua #프록시 컨트랙트가 가르키는 로직 컨트랙트 예


올리는 시점에서 실제 사용하는 방식은, 

arc2_proxy 와 arc2_proxy_logic_mk1 둘을 디플로이 한뒤 설정을 잡고

arc2_proxy 컨트랙트를 사용
