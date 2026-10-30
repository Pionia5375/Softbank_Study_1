로드맵 위치: 본선 D-8 / 컨트롤 플레인 스택 재점검 (Fastify · Zod · pg-boss) / 본선 연결점: 컨트롤 플레인 API(WP1), 이전 오케스트레이션(FR-MIG), IR(가져오기 → 중립 IR → 어댑터)

# 15. Fastify + Zod + pg-boss — 각각 뭐였고, 대안과 비교하면

작성 2026-10-30. 버전은 같은 날 `npm view`로 확인한 값.
표시: 【사실】(출처) 【추정】 【미확인】 【사용자】

---

## 0. 세 개가 한 그림 안에서 어디에 있나

예선 camellia 구조를 한 줄로 쓰면 이렇다 【사실: notes/research/12 §2.2】.

```
웹 콘솔 ──HTTP──▶ API (Fastify) ──▶ Postgres ◀── Worker
                    │                 ├ 상태 테이블 (프로젝트·배포·환경 락)
                    │                 └ pg-boss 작업 큐 (job 테이블)
                    └ 요청 검증·IR 검증 = Zod
```

- **Fastify** = 요청을 받는 문. "HTTP 요청이 오면 어떤 함수를 부를지"를 정하는 웹 프레임워크.
- **Zod** = 데이터의 모양 검사기. "이 JSON이 우리가 정한 모양인가?"를 실행 중에 검사하고, 같은 정의에서 TypeScript 타입도 뽑아 준다. camellia에선 IR 스키마 자체가 Zod 코드였다 (`packages/ir-schema/src/schema.ts`, 428줄) 【사실: notes/research/02 F1】.
- **pg-boss** = 할 일 목록(작업 큐). API가 "배포해" 요청을 받으면 바로 배포하지 않고 Postgres 테이블에 작업 한 줄을 넣는다. Worker가 그 줄을 가져가서 실제로 빌드·프로비저닝·전환을 한다.

왜 API와 Worker를 나눴나: 배포·이전은 수십 초~수 분 걸린다. HTTP 요청 하나가 그동안 붙잡혀 있으면 타임아웃·재시도·서버 재시작에 약하다. 그래서 "접수(API)"와 "실행(Worker)"을 나누고 그 사이를 큐로 잇는다.

---

## 1. Fastify

### 1.1 무엇인가 (0부터)
- Node.js에서 HTTP 서버를 만드는 프레임워크 【사실: fastify 5.12.7, npm】.
- 라우트 = "`POST /deployments`가 오면 이 함수 실행" 같은 연결 규칙.
- Fastify의 특징 세 가지:
  1. **스키마 기반**: 라우트마다 요청 body·응답 모양을 JSON Schema로 붙이면, 들어올 때 검사(Ajv 사용)하고 나갈 때 그 모양대로 빠르게 직렬화한다 【사실: Fastify 공식 문서 Validation-and-Serialization】.
  2. **플러그인 + 캡슐화**: DB 연결, 인증 같은 걸 플러그인으로 붙이고, 플러그인 범위 밖으로 새지 않게 막는다.
  3. **훅(lifecycle hook)**: `onRequest` → `preValidation` → `preHandler` → 핸들러 → `onSend`. 인증·감사 로그를 여기에 건다. 로깅은 pino가 기본 내장.

### 1.2 대안 비교

| 후보 | 한 줄 정의 | 장점 | 단점 | 우리 상황 |
|---|---|---|---|---|
| **Fastify** (현행) | 스키마·플러그인 중심 Node 프레임워크 | 예선 코드 재사용, 빠름, 검증·로깅 내장 | Express보다 예제가 적음 | 예선 코드 ~34.7k줄이 이미 여기 있음 |
| Express 5.3 | 가장 오래된 Node 프레임워크 | 자료·미들웨어 최다 | 검증·직렬화 없음(직접 붙임), 느림 | 갈아탈 이유 없음 |
| NestJS 12 | DI·데코레이터 구조를 강제하는 프레임워크 (내부 엔진으로 Fastify 사용 가능) | 큰 팀에서 구조 통일 | 보일러플레이트 많음, 7.5시간 개발에 과함 | 팀원이 Nest만 안다면 고려 |
| Hono 4 | 웹 표준(Request/Response) 기반 경량 프레임워크 | Cloudflare Workers·Lambda 등 어디서나 실행 | 생태계 작음, 예선 코드 이식 필요 | 컨트롤 플레인이 엣지에 갈 이유 없음 |
| Go (net/http, Gin) | 정적 컴파일 언어 | 단일 바이너리, k8s 생태계(client-go)와 같은 언어 | 언어 전환 비용, 예선 코드 버림 | k8s 컨트롤러를 직접 짤 때만 |
| Spring Boot / Ktor | JVM 프레임워크 | 【사용자】 Jeong이 가장 익숙 | 예선 TS 코드 전부 재작성 | 팀원 다수가 Java일 때만 |

**판단 기준**: 프레임워크 성능 차이는 이 앱에서 병목이 아니다 【추정: 컨트롤 플레인 요청은 초당 수 건, 병목은 클라우드 API 호출(수 초)】. 그래서 기준은 "예선 코드 재사용량"과 "팀원이 당일 바로 고칠 수 있는가"다.

---

## 2. Zod

### 2.1 무엇인가 (0부터)
- TypeScript의 타입은 **컴파일할 때만** 존재한다. 실행 중 들어온 JSON(사용자 입력, AI가 만든 IR 초안)은 타입이 뭐든 그냥 들어온다.
- Zod는 스키마를 **실행 중에 쓸 수 있는 값**으로 정의한다. 한 번 정의하면 두 가지가 나온다 【사실: zod 4.6.7, zod.dev】.
  - `schema.parse(data)` → 모양이 틀리면 어디가 틀렸는지 에러로 알려 준다.
  - `z.infer<typeof schema>` → 같은 정의에서 TS 타입을 뽑는다. 정의가 하나라서 "타입과 검사가 서로 어긋나는" 일이 없다.
- Zod 4부터 `z.toJSONSchema()`로 JSON Schema를 뽑을 수 있다 【사실: Zod 4 릴리스 노트】.

```ts
import { z } from "zod";

const Service = z.object({
  name: z.string().min(1),
  port: z.number().int().min(1).max(65535),
  health: z.object({ path: z.string().startsWith("/") }),
});
type Service = z.infer<typeof Service>;   // { name: string; port: number; health: {path: string} }

Service.parse({ name: "web", port: 99999, health: { path: "healthz" } });
// → ZodError: port 는 65535 이하, health.path 는 "/"로 시작해야 함
```

### 2.2 본선에서 Zod가 하는 일
- 가져오기(import) 흐름: 관찰 역할로 읽은 ECS task def·ALB·RDS → **AI가 IR 초안 작성** → Zod로 검사 → 사람 확인 → 어댑터.
- AI 출력은 틀릴 수 있다. "AI가 만든 걸 스키마로 막는다"는 게 AI 10점 + 안전성 설명의 근거가 된다 【추정】.

### 2.3 대안 비교

| 후보 | 한 줄 정의 | 장점 | 단점 |
|---|---|---|---|
| **Zod 4** (현행) | TS 우선 런타임 스키마 | 타입 자동 추론, 에러 메시지 좋음, 예선 IR 428줄 재사용 | TS 전용. Go/Python 에이전트와 공유하려면 JSON Schema로 내보내야 함 |
| JSON Schema + Ajv | 언어 중립 표준 스키마 | 어떤 언어든 같은 스키마, Fastify 기본 검증기 | TS 타입은 별도 생성 필요, 손으로 쓰기 장황 |
| TypeBox 0.34 | JSON Schema를 TS 코드로 쓰는 도구 | JSON Schema가 결과물이라 Fastify와 바로 붙음 + 타입 추론 | Zod보다 표현력·에러 메시지 약함 |
| Valibot 1.5 | Zod와 비슷한 경량 스키마 | 번들 작음(프론트에 유리) | 서버에선 크기 이점 없음 |
| CUE | 설정 언어 자체에 제약을 넣는 언어 (KubeVela가 사용) | 기본값·병합·제약을 한 언어로 | 학습 비용 큼, 해커톤 당일 디버깅 어려움 |
| Protobuf | 바이너리 직렬화 + 스키마 | 언어 중립, gRPC | 사람 확인 화면용 YAML/JSON엔 불편 |

**판단 기준**: IR을 **누가 읽나**. TS 코드만 읽으면 Zod 단독으로 충분. 에이전트(Python)나 k8s 쪽(Go)도 읽어야 하면 "Zod가 원본, `z.toJSONSchema()` 결과를 공유"로 간다. 이러면 예선 코드를 살리면서 언어 중립성 질문에도 답이 된다.

---

## 3. pg-boss

### 3.1 무엇인가 (0부터)
- 작업 큐 = "해야 할 일"을 줄 세워 두는 곳. 넣는 쪽(producer)과 꺼내 처리하는 쪽(worker)이 따로 돈다.
- pg-boss는 이 큐를 **Postgres 테이블 위에** 만든 Node 라이브러리다 【사실: pg-boss 12.38.0, npm】. Redis 같은 별도 서버가 필요 없다.
- 핵심 SQL은 `SELECT ... FOR UPDATE SKIP LOCKED` 【사실: pg-boss 12 `dist/plans.js` 501행】.
  - `FOR UPDATE` = 이 줄을 내가 잠근다.
  - `SKIP LOCKED` = 다른 Worker가 이미 잠근 줄은 기다리지 말고 건너뛴다.
  - 결과: Worker를 여러 개 띄워도 같은 작업을 두 명이 동시에 집지 않는다.
- 기능: 재시도 횟수·간격(백오프), 만료 시간, 예약 실행(cron), 싱글턴(같은 키 작업 하나만), 데드레터 큐(계속 실패한 작업을 따로 모음).

### 3.2 예선에서 pg-boss를 고른 진짜 이유 = 트랜잭션 하나로 묶기
- 【사실: notes/research/05 §학습자 강점, camellia D-11·D-14·D-29·D-30】 "상태 전이와 작업 생성을 한 트랜잭션"으로 처리했다.
- 무슨 뜻인가: "배포 상태를 `queued`로 바꾼다"와 "배포 작업을 큐에 넣는다"가 **같은 DB 트랜잭션**이면 둘 다 되거나 둘 다 안 된다.
- Redis 큐나 SQS를 쓰면 DB 커밋과 큐 전송이 서로 다른 시스템이라, 중간에 죽으면 "상태는 queued인데 작업이 없음"(영원히 대기) 또는 그 반대가 생긴다. 이걸 막으려고 보통 outbox 패턴(DB에 먼저 쓰고 별도 프로세스가 큐로 옮김)을 추가로 짠다.
- pg-boss 12도 `db` 옵션으로 내 트랜잭션 안에서 작업을 넣을 수 있다 【사실: pg-boss 12 `dist/types.d.ts` 71행 "Pass it as the `db` option on any pg-boss call"】.

### 3.3 대안 비교

| 후보 | 한 줄 정의 | 장점 | 단점 | 본선 적합도 |
|---|---|---|---|---|
| **pg-boss 12** (현행) | Postgres 위 작업 큐 | 추가 인프라 0, 상태와 같은 트랜잭션, 예선 코드 재사용 | 초당 수천 건 이상엔 Postgres 부하, 다단계 흐름은 직접 상태 머신으로 짜야 함 | 높음 |
| BullMQ 6 (Redis) | Redis 위 작업 큐 | 빠름, 대시보드·흐름(parent/child) 기능 | Redis 하나 더 운영, DB와 트랜잭션 분리(outbox 필요) | 중 |
| AWS SQS | 관리형 메시지 큐 | 운영 0, 무한 확장 | **AWS 종속** — "Beyond Lock-In" 주제와 정면 충돌, 온프레에서 못 씀 | 낮음 |
| Temporal | 내구성 있는 워크플로 엔진 | 다단계·장시간·보상(롤백) 흐름이 코드 그대로 재개됨. 이전(provision→sync→shift→cutover) 같은 긴 흐름에 딱 맞음 | Temporal 서버(+DB) 운영, 결정론 규칙 학습, 7.5시간 안에 도입 위험 | 중 (설계 문서의 "검토한 대안"으로 최적) |
| Argo Workflows | k8s 위 단계 실행 엔진 | k8s 안이면 자연스러움, UI 있음 | k8s 필수, 앱 코드와 상태 공유 어려움 | k8s안 선택 시만 |
| Graphile Worker 0.18 | Postgres 큐 (pg-boss와 같은 계열) | LISTEN/NOTIFY로 지연 짧음 | 갈아탈 만큼 차이 없음 | 낮음 (이유 없음) |
| Kafka / NATS JetStream | 이벤트 스트림 | 대량 이벤트, 재생 | "작업 하나를 한 번 처리" 용도엔 과함 | 낮음 |

### 3.4 본선에서 달라지는 점
- 예선 작업은 "배포 1회" 단위였다. 본선 이전은 **단계가 길고 중간에 되돌려야 한다** (provision → sync → shift 10/50/100% → cutover → measure, 실패 시 롤백) 【사실: 메모리, 아키텍처 v0.1】.
- pg-boss로 가면: 단계마다 작업 하나, 단계 결과를 상태 테이블에 쓰고 다음 단계 작업을 **같은 트랜잭션에서** 넣는다. 롤백 = 역방향 단계 작업. 즉 상태 머신은 우리가 짠다.
- Temporal로 가면: 위 흐름을 함수 하나로 쓰고, 엔진이 죽었다 살아나도 이어서 실행해 준다. 대신 서버를 하나 더 띄우고 배워야 한다.
- 【추정】 해커톤 개발 시간(3.5h + 4h)과 예선 코드 재사용을 보면 pg-boss 유지 + 이전 상태 머신 추가가 현실적. Temporal은 "운영 단계에선 이걸로 간다"는 확장 경로로 문서에 남기면 대안 문서화 점수(20점)에 쓸 수 있다.

---

## 4. 심사 Q&A에서 나올 만한 질문 1개 + 답 뼈대

> Q. "왜 메시지 큐(SQS/Redis) 안 쓰고 DB를 큐로 썼나요?"

- 상태 변경과 작업 생성을 한 트랜잭션으로 묶어 "상태는 바뀌었는데 작업이 없는" 불일치를 없애려고. (outbox 없이)
- 처리량: 컨트롤 플레인 작업은 분당 수 건 수준이라 Postgres로 충분. 【미확인: 본선에서 직접 잴 것 — 셀프 연습 참고】
- 종속 회피: SQS는 AWS 전용. Postgres는 AWS·GCP·온프레 어디서나 같은 방식으로 뜬다. 주제(Beyond Lock-In)와 맞는다.
- 버린 대안: Temporal — 긴 이전 흐름엔 더 맞지만 운영 대상이 늘어 해커톤 기간엔 위험. 확장 경로로 기록.

---

## 핵심 결정 3개 (+대안)  — TODO(human): 팀에서 확정

1. **API 프레임워크 = Fastify 유지** / 대안: NestJS(구조 강제), Spring(Jeong 익숙), Go(k8s 생태계). 기준: 예선 코드 재사용량, 팀원 언어.
2. **IR 스키마 = Zod 원본 + `z.toJSONSchema()` 내보내기** / 대안: JSON Schema 직접 작성(Ajv), TypeBox, CUE. 기준: IR을 TS 밖(에이전트·k8s)에서도 읽나.
3. **이전 오케스트레이션 = pg-boss + 우리가 짠 상태 머신** / 대안: Temporal(내구성 워크플로), BullMQ(Redis), Argo Workflows(k8s). 기준: 개발 시간, 운영 대상 수, 롤백 흐름 표현력.

## 셀프 연습 1개
- 로컬 Postgres 하나에 Worker 2개를 띄우고 작업 100개를 넣은 뒤, **같은 작업을 두 Worker가 처리한 건수**와 **100개 처리 총 시간**을 3회 잰다. 기대: 중복 0건. 그다음 SQL에서 `SKIP LOCKED`를 뺀 버전(직접 쿼리)으로 같은 실험을 해서 무엇이 달라지는지(대기 또는 중복) 적는다.
- 실습은 로컬 데스크톱 세션에서. (이 스레드에선 실행 안 함)

## 검증 명령과 기대 출력
```bash
npm view fastify version     # 기대: 5.x  (10/30 기준 5.12.7)
npm view zod version         # 기대: 4.x  (10/30 기준 4.6.7)
npm view pg-boss version     # 기대: 12.x (10/30 기준 12.38.0)
```
- `npm view <패키지> version` = npm 저장소에 올라간 최신 버전 번호만 출력. 설치는 하지 않는다.
- 예선 레포에서 버전 확인: `grep -E '"(fastify|zod|pg-boss)"' apps/*/package.json packages/*/package.json` → 예선 당시 쓰던 버전이 나온다. 【미확인: 예선 레포 package.json은 이 스레드에서 안 열어 봄. 메이저 버전이 다르면(예: pg-boss 9→12) API가 바뀌었을 수 있음】
