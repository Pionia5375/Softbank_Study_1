# hello 함수 이미지 (Claude 작성, 완성본). Kaniko 가 클러스터 안에서 이 파일로 빌드한다.
# 1단계: Go 컴파일러가 든 이미지에서 실행 파일 하나를 만든다
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod main.go ./
# CGO_ENABLED=0: C 라이브러리 없이 혼자 도는 실행 파일 → 아래 scratch(빈 이미지)에서도 돈다
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /hello .
# scratch 에는 /tmp 도 없다. ?work=io 가 쓸 빈 폴더를 미리 만들어 둔다
RUN mkdir -p /out/tmp

# 2단계: 빈 이미지에 실행 파일만. 이미지가 작을수록 콜드 스타트 때 이미지 받는 시간이 준다
FROM scratch
COPY --from=build /hello /hello
COPY --from=build --chown=65532:65532 /out/tmp /tmp
USER 65532:65532
ENTRYPOINT ["/hello"]
