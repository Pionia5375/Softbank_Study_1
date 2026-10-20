# 샘플 함수 v2 (일부러 고장). import 는 되니까 Revision 은 Ready 가 된다 → 쿠버네티스 눈에는 "정상".
# 하지만 요청마다 500. 에이전트가 get_metrics 의 probe 로 이걸 찾아 rollback 을 제안하는 게 데모 시나리오
def handle(body: bytes):
    raise RuntimeError("v2 bug: 설정 키 이름을 잘못 읽음")
