# 샘플 함수 v1. 컨트롤 플레인에 이 파일 내용을 code 로 보낸다
def handle(body: bytes):
    name = body.decode().strip() or "world"
    return {"hello": name, "version": 1}
