# 함수 이미지 (Claude 작성, 완성본). 빌드 Job 의 kaniko 가 이 파일로 이미지를 만든다.
# 빌드 재료(handler.py, server.py, 이 파일)는 컨트롤 플레인이 ConfigMap 에 넣어 준다.
FROM python:3.12-slim
WORKDIR /app
COPY server.py handler.py ./
# root 가 아닌 숫자 UID. 3단계 테넌트 namespace 의 Pod Security(restricted)를 통과하려면 필요
USER 65532:65532
ENV PORT=8080 PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["python", "server.py"]
