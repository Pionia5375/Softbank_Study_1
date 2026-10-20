"""함수 런타임 (Claude 작성, 완성본).

사용자가 올린 handler.py 의 handle(body: bytes) 를 HTTP 서버로 감싼다.
- 모든 경로, GET/POST 둘 다 handle 로 보낸다
- 반환값이 dict/list 면 JSON, bytes 면 그대로, 그 밖은 문자열로
- handle 이 예외를 던지면 500 + 서버 로그에 스택
Knative 가 PORT 환경 변수(기본 8080)를 넣어 준다.
"""
import json
import os
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import handler  # 사용자 코드. import 가 실패하면 컨테이너가 바로 죽고 Revision 이 Ready 가 안 된다


class FunctionHandler(BaseHTTPRequestHandler):
    def _serve(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        try:
            out = handler.handle(body)
            status = 200
        except Exception:  # 사용자 코드의 어떤 예외든 500 으로
            traceback.print_exc()
            out, status = {"error": "function raised an exception"}, 500

        if isinstance(out, (dict, list)):
            data, ctype = json.dumps(out, ensure_ascii=False).encode(), "application/json"
        elif isinstance(out, bytes):
            data, ctype = out, "application/octet-stream"
        else:
            data, ctype = str(out).encode(), "text/plain; charset=utf-8"

        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = _serve
    do_POST = _serve


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print(f"function runtime listening on :{port}", flush=True)
    ThreadingHTTPServer(("", port), FunctionHandler).serve_forever()
