# Lab 01 — Docker 기초: Spring Boot 이미지 만들고 숫자로 비교하기

W1(10/6~10/12) P0-1 "K8s 기본"에 들어가기 전 기반 실습. 근거: [06 학습 순서 1번](../../notes/research/06-tech-stack-map.md), [05 4.5주 일정](../../notes/research/05-learner-gap-analysis.md).

## 목표

1. 최소 Spring Boot API를 단일 스테이지(A)와 멀티스테이지(B) Dockerfile로 각각 이미지화한다
2. 이미지 크기, 빌드 시간(콜드, 캐시, src만 변경), 기동부터 `/health` 200까지 걸린 시간을 실측한다
3. "왜 B를 골랐나"를 ADR 1개로 남긴다 (목적 → 대안 2개 → 고른 이유 → 측정값 → 한계)

## 구조

```
labs/01-docker-basics/
├── app/
│   ├── pom.xml                 Spring Boot 4.1.1 / Java 21, jar 이름은 app.jar 로 고정
│   ├── src/main/java/...       /health, /hello 두 개
│   ├── .dockerignore
│   ├── Dockerfile.single       A: maven 이미지 하나로 빌드+실행 (기준선)
│   └── Dockerfile.multi        B: build → runtime 분리, non-root, TODO(human) 2곳
├── scripts/measure.sh          A/B 측정 스크립트
└── results/                    측정 로그 (*.log 는 git 제외)
```

로컬에 Maven이 없어도 된다. 빌드는 전부 컨테이너 안의 `maven:3.9-eclipse-temurin-21`에서 한다.

## 진행 순서

1. **A 빌드와 실행**
   ```bash
   docker build -f app/Dockerfile.single -t lab01-hello:single app
   docker run --rm -p 8080:8080 lab01-hello:single
   curl localhost:8080/hello
   ```
2. **B의 TODO(human) 채우기** (`app/Dockerfile.multi`)
   - 런타임 베이스 이미지 선택 → `ARG RUNTIME_IMAGE=` 기본값
   - `HEALTHCHECK` (베이스 이미지에 curl/wget/셸이 있는지에 따라 방식이 달라짐)
3. **측정**
   ```bash
   scripts/measure.sh single
   scripts/measure.sh multi
   ```
   마지막에 출력되는 표 한 줄을 아래 표에 붙인다.
4. **관찰할 것**
   - `docker history lab01-hello:single` 와 `:multi` 레이어 비교. 어떤 레이어가 크고 왜 큰가
   - src만 바꿨을 때 A는 의존성을 다시 받고 B는 캐시를 쓰는가
   - `docker inspect --format '{{.State.Health.Status}}' <컨테이너>` 로 HEALTHCHECK 상태 변화 (starting → healthy)
   - `docker run --rm lab01-hello:multi id` 또는 `docker top` 으로 non-root 실행 확인
5. **기록:** 측정표와 ADR을 `notes/`에 남긴다

## 측정표

측정 환경: Docker 29.3.1, Docker Desktop 메모리 약 7.7GB, CPU 16

| 변형 | 이미지 크기 | 콜드 빌드 | 캐시 빌드 | src 변경 후 빌드 | 기동 → /health 200 |
|---|---|---|---|---|---|
| single (A) | | | | | |
| multi (B), 베이스: ___ | | | | | |

## 다음 단계 (Lab 02 후보)

- `docker compose`로 이 앱과 Postgres를 함께 띄우기: 서비스 이름 DNS, 볼륨, `depends_on: condition: service_healthy`
- `kind load docker-image lab01-hello:multi` 후 Deployment/Service로 배포. HEALTHCHECK 값을 readiness/liveness probe로 옮기기
