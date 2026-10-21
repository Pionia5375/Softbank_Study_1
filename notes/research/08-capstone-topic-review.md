로드맵 위치: 본선 외 / 졸업작품(2027-1학기) 주제 검토 / 본선 PoC의 테넌트 격리·Cilium·MCP 가드레일과 직접 연결

# 졸업작품 컨셉 검토: "MSA + MCP + AI + eBPF 올인원 보안 솔루션"

작성 2026-10-21. 팀 단톡 스크린샷(【사용자】) 기준 검토.

## 0. 한 줄 결론

방향은 좋다. 특히 지도교수 후보(이승수 교수)의 연구와 거의 정확히 겹친다.
다만 지금 안은 **제품 2개(커널·네트워크 보안 대시보드 + 범용 자연어 코드 실행 에이전트)를 한 번에 만드는 구조**라서
1학기·4명으로는 넓다. "올인원"을 버리고 **"관측 → AI가 최소권한 정책 제안 → 검증 → 사람 승인 후 적용"** 하나의 흐름으로 묶으면 된다.

## 1. 원안 정리 【사용자】

- 컨셉: MSA에 MCP + AI를 연결한 네트워크 + 커널(eBPF) 수준 올인원 보안 솔루션
- 역할: 프론트(대시보드·시각화) / 백1(MCP 서버 + AI 가드레일) / 백2(mocking MSA + 옵저버빌리티) / 인프라(k8s, eBPF, 데이터 파이프라인: AWS 관리형 또는 Kafka + Flink)
- 기능 1: 대시보드에서 내 MSA 서비스의 커널 수준 위협 + 네트워크 보안 상태 확인
- 기능 2: 자연어 질의 → 기존 API를 MCP로 감싸 LLM이 샌드박스(컨테이너 격리)에서 코드 생성·실행 → 결과 반환
- 일정: 중간고사 후 이승수 교수님께 링크드인 연락, 11/11 설명회 전에 선점

## 2. 지도교수 적합성

- 【사실】 이승수 교수: 인천대 컴퓨터공학부, 2021.9 부임, 주전공 클라우드 보안·네트워크 보안, KAIST 박사(신승원 교수 연구실) ([교수 소개](https://iti.inu.ac.kr/profl/information/1406/20211080/empView.do?viewType=&haksaDeptCode=0000077&majCd=), [학부 페이지](https://www.inu.ac.kr/user/indexSub.do?codyMenuSeq=2236524&siteId=isis))
- 【사실】 연구 분야: 클라우드 네이티브, SDN/NFV와 그 보안 ([연구실 사이트](https://sites.google.com/view/cclab-inu/ss), 검색 요약 기준)
- 【사실】 INFOCOM 2025 **KubeTeus**: 컨테이너(마이크로서비스) 환경의 네트워크 보안 정책을 자동 생성·검증하는 프레임워크 ([인천대 보도](https://unjapan.inu.ac.kr/inu/10771/subview.do?enc=Zm5jdDF8QEB8JTJGYmJzJTJGaW51JTJGMjU5NCUyRjM5ODQyNSUyRmFydGNsVmlldy5kbyUzRg%3D%3D))
- 【사실】 그 밖에 관련 논문: "Secure Inter-Container Communications Using XDP/eBPF"(IEEE/ACM ToN 2023), BASTION(컨테이너 네트워크 보안, USENIX ATC 2020), Kunerva(컨테이너 네트워크 정책 자동 탐색, IEEE Access 2023), ALPS(서버리스 함수 최소권한, INFOCOM 2026), "Cognition-Driven Security Policy Generation in Cloud-Native Environments"(JNCA 2026 게재 예정) (검색 결과 요약, dblp/연구실 페이지 직접 확인은 네트워크 차단으로 못 함)
- 【미확인】 위 2026 저널 논문이 LLM을 쓰는지. 초록 확인 못 함.
- 【추정】 교수님이 가장 반길 포인트는 "eBPF 대시보드"보다 **"MSA에서 보안 정책을 자동으로 만들고 검증한다"**는 부분이다. 반대로 기능 2(범용 자연어 코드 실행)는 연구실 주제와 거리가 있다.

## 3. 기존 도구와 겹치는 부분

| 원안 기능 | 이미 있는 것 | 겹침 |
|---|---|---|
| 커널 수준 위협 탐지 | Falco(CNCF 졸업, 시스콜 규칙 탐지), Tetragon(eBPF, 커널 안 차단까지 가능), Tracee | 거의 그대로 겹침 |
| 네트워크 흐름 가시화 | Cilium Hubble, Pixie | 거의 그대로 겹침 |
| 대시보드 | Grafana, Hubble UI, 상용 CNAPP | 겹침 |
| 자연어로 보안 상태 질의 | Kyverno MCP 서버(Nirmata), KubeGuard MCP 등 | 일부 겹침 |
| LLM 생성 코드 샌드박스 실행 | sandbox-mcp, LLM Sandbox 등 | 겹침 |

출처: [Falco vs Tetragon 비교 논문(SciTePress 2025)](https://scitepress.org/publishedPapers/2025/142727/pdf/index.html), [Isovalent Tetragon](https://isovalent.com/tetragon), [Nirmata Kyverno MCP](https://nirmata.com/?p=12179), [sandbox-mcp](https://glama.ai/mcp/servers/@pottekkat/sandbox-mcp/inspect).

- 【사실】 Falco는 주로 탐지, Tetragon은 커널 안에서 차단까지 가능.
- 【추정】 상용 보안 제품(Sysdig, Wiz, Datadog 등)도 AI 어시스턴트를 붙이는 추세라, "탐지 + 대시보드 + 챗봇" 자체로는 차별점이 약하다.
- 【추정】 검색 범위에서 **"eBPF 관측 데이터 → LLM이 정책 생성 → 정적 검증 → 승인 후 적용"**을 한 흐름으로 묶은 오픈소스는 못 찾았다. 여기가 차별점 후보다.

결론: eBPF 센서와 대시보드는 **직접 만들지 말고 Tetragon·Hubble을 센서로 쓰고**, 팀이 만드는 부분은 그 위의 "정책 자동화 + AI 가드레일"이어야 한다.

## 4. 범위와 과설계 위험

| 항목 | 위험 | 제안 |
|---|---|---|
| "올인원" | 심사·발표에서 "그래서 핵심이 뭐냐"가 흐려짐 | 핵심 흐름 1개로 정의 |
| eBPF 프로그램 직접 개발 | 커널·검증기 학습 비용이 큼. 1학기에 탐지 엔진까지는 무리 【추정】 | Tetragon TracingPolicy로 시작, 직접 eBPF는 1개(예: 특정 시스콜·연결 추적)만 |
| Kafka + Flink | 이벤트 양이 졸작 규모에선 작음. 운영 부담만 큼 【추정】 | 처음엔 Tetragon/Hubble → OTel Collector → Loki/ClickHouse 정도. Kafka는 "확장안"으로 문서에만 |
| mocking MSA 직접 개발 | 공수 대비 가치 낮음 | Online Boutique / Sock Shop 같은 공개 데모 앱 + 일부러 취약한 서비스 1~2개 추가 |
| 기능 2: 범용 코드 생성·실행 | 별개 제품 수준. 샌드박스 탈출·프롬프트 인젝션 방어까지 하면 또 하나의 졸작 | 범용 실행 대신 **읽기 전용 MCP 도구 + 정책 "제안"까지만**. 코드 실행이 꼭 필요하면 gVisor 샌드박스에서 쿼리 스크립트만 |

## 5. 기능 1·2를 한 제품으로 묶는 방법 (다듬은 주제안)

**가제: "AI가 제안하고 사람이 승인하는 MSA 최소권한 보안 정책 자동화"**

1. 관측: Tetragon(프로세스·시스콜·파일) + Hubble(서비스 간 L3/L4/L7 흐름) 수집
2. 학습: 일정 기간 정상 트래픽·행동으로 서비스별 "정상 프로필" 생성
3. 제안: LLM이 MCP 도구로 프로필을 조회해 CiliumNetworkPolicy / Tetragon TracingPolicy 초안 생성
4. 검증: 정책을 바로 적용하지 않고 (a) 문법·스키마 검사 (b) 과거 트래픽 재생으로 "정상 요청을 막는가" 시뮬레이션 (c) 권한 범위 diff
5. 승인·적용: 대시보드에서 사람이 diff 보고 승인 → GitOps(Argo CD)로 적용, 롤백 가능
6. 자연어: "결제 서비스가 외부로 나가는 연결 보여줘", "주문 서비스 최소권한 정책 만들어줘"를 같은 MCP 도구로 처리 (= 원안 기능 2를 이 흐름 안에 흡수)
7. 가드레일: LLM은 읽기 전용 도구 + "제안"만 가능, 적용 권한 없음. 프롬프트 인젝션(로그·헤더에 심은 지시문) 테스트를 평가 항목으로

평가 숫자(졸작 발표용): 정책 생성 후 정상 요청 차단율(오탐), 공격 시나리오 차단율, 정책 생성 시간, LLM 사용 vs 규칙 기반 비교.

이렇게 하면 교수님 KubeTeus 계열 연구와 연결되면서도 "LLM + MCP + 검증·승인" 부분이 학생 팀만의 기여가 된다. 【추정】

### 더 줄인 최소안 (일정이 밀릴 때)

- 네트워크 정책만(CiliumNetworkPolicy), 커널 정책은 탐지 표시만
- 검증은 문법 검사 + 트래픽 재생 1종

## 6. 역할 분담 재조정안

원안은 인프라 한 명에게 k8s + eBPF + 데이터 파이프라인이 몰리고, 프론트는 상대적으로 가볍다.

| 역할 | 원안 | 제안 |
|---|---|---|
| 프론트 | 대시보드·시각화 | 서비스 맵 + **정책 diff·승인 화면**(제품의 핵심 UX) |
| 백1 | MCP 서버 + AI 가드레일 | 같음 + 정책 생성 프롬프트·평가 |
| 백2 | mocking MSA + 옵저버빌리티 | 데모 앱 세팅 + **정책 검증기(트래픽 재생 시뮬레이터)** |
| 인프라 | k8s, eBPF, 파이프라인 | k8s(Cilium·Tetragon) + GitOps + 수집 파이프라인. 직접 eBPF 1개 |

## 7. Jeong 커리어 관점 【추정】

- 인프라 역할을 맡으면 SoftBank 클라우드 엔지니어 지향과 정확히 맞는다: Cilium NetworkPolicy, Tetragon, Argo CD, gVisor 샌드박스는 본선 PoC(03 테넌트 격리, 04 gVisor, 05 MCP 가드레일)에서 이미 다룬 것들이라 재사용된다.
- CKA(본선 후) → CKS(보안) 흐름으로 자연스럽게 이어진다.
- "AI가 정책을 만들고 사람이 승인" 구조는 면접에서 대안·트레이드오프(LLM vs 규칙, 자동 적용 vs 승인)를 말하기 좋다.

## 8. 팀에 보낼 짧은 의견 (그대로 복사용)

> 주제 방향 좋다고 봐요. 특히 이승수 교수님 연구(INFOCOM 2025 KubeTeus: 컨테이너 네트워크 보안 정책 자동 생성·검증, eBPF 기반 컨테이너 통신 보안)랑 많이 겹쳐서 지도 받기 좋을 것 같아요.
> 다만 "올인원"으로 가면 두 제품(eBPF 보안 대시보드 + 범용 자연어 코드 실행 에이전트)을 동시에 만드는 거라 1학기엔 넓고, 탐지·대시보드는 Falco/Tetragon/Hubble이 이미 해서 차별점이 약해요.
> 제안: eBPF 센서는 Tetragon·Hubble을 쓰고, 우리가 만드는 건 "관측 데이터 → LLM이 MCP로 최소권한 정책 제안 → 트래픽 재생으로 검증 → 대시보드에서 승인 → GitOps 적용" 한 흐름으로 묶기. 자연어 질의도 이 흐름 안 MCP 도구로 처리하고, LLM은 제안만 하고 적용 권한은 없게(가드레일).
> Kafka+Flink는 처음엔 빼고 확장안으로만 두고, mocking MSA는 Online Boutique 같은 공개 데모 앱 쓰면 공수 많이 줄 것 같아요.
> 교수님께 연락할 때도 "MSA 보안 정책 자동 생성·검증에 LLM+MCP를 붙인다"로 소개하면 연구실 주제랑 바로 연결될 것 같습니다.

## 핵심 결정 3개 (+대안)

1. eBPF 센서: Tetragon·Hubble 재사용 (대안: 직접 eBPF 개발 → 1학기 공수 과다로 1개만)
2. AI 역할: 정책 "제안"만, 적용은 사람 승인 + GitOps (대안: 자동 적용 → 오탐 시 서비스 장애, 가드레일 설명 어려움)
3. 파이프라인: OTel Collector + 저장소 단순 구성 (대안: Kafka+Flink → 규모 대비 운영 부담, 확장안으로 문서화)

## 셀프 연습 1개

- 본선 PoC 03(테넌트 격리)의 CiliumNetworkPolicy를 보고, "이 정책을 트래픽 기록으로부터 자동 생성하려면 어떤 입력이 필요한가"를 한 문단으로 써 보기 (본선 후).

## 검증

- 교수 정보: 위 인천대 교수 소개 링크에서 "주전공: 클라우드 보안, 네트워크 보안" 확인
- 【미확인】 JNCA 2026 논문 초록(LLM 사용 여부): 연구실 사이트 publications에서 확인 필요
