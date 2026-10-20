# 작업자 공통 지침: FaaS PoC 가이드 한 장 쓰기

## 무엇을 만드나
- 레포 `/home/user/Softbank_Study_1` 의 `poc/01~07` (쿠버네티스 위 멀티테넌트 FaaS PoC) 를 설명하는 **웹 가이드의 한 장(HTML 한 파일)**.
- 독자: Jeong 한 명. Java/Spring 백엔드 + PM 출신, 인프라 실습 경험은 적다. SoftBank 해커톤 본선(11/7~8)에서 이 구조를 설명하고, 처음 보는 주제에 개념을 떠올려 적용할 수 있어야 한다. 하루 걸려 읽어도 되는 깊이. 분량 제한 없음 (길어도 된다. 품질이 우선).
- 나중에 설계 문서로 옮기기 쉽게: 절마다 독립적으로 읽히게, 그림마다 번호와 캡션.

## 반드시 지킬 형식
1. 출발점은 `docs/guide/_template.html` 을 복사. `guide.css` 의 클래스만 쓴다 (새 CSS 는 페이지 안 `<style>` 에 최소한으로, 색은 반드시 `var(--토큰)`). `guide.js`, mermaid 스크립트 태그는 템플릿 그대로 둔다.
2. 한국어만 (반말 아님. 평서문 "~다"). 일본어 넣지 않는다. 기술 용어는 영어 원어를 처음 한 번 괄호로.
3. 실측 숫자(ms, 초, 비용 금액)는 넣지 않는다. 설계와 구조, 동작 원리가 핵심. 기본값·설정값(예: 기본 폴링 주기, tolerationSeconds 20)은 넣어도 된다.
4. **깊이 3단계**: 핵심 기술마다 `<div class="tier" data-tier="1">` 개괄(무엇·왜·한 장 그림) → `data-tier="2"` 동작 원리(내부 구성 요소, 흐름, 상태) → `data-tier="3"` 세부 로직(공식 문서가 다루는 핵심 개념을 최대한 상세히: 필드, 알고리즘, 엣지 케이스, 의사코드, 순서도). 기준은 **공식 문서**. 각 기술 끝에 `callout fact` 로 공식 문서 링크 목록.
5. **다이어그램을 많이**. 장마다 최소 12개, 많을수록 좋다. 두 종류를 섞는다.
   - 손으로 그린 인라인 SVG: 구조도·배치도·계층도. `guide.css` 의 `d-*` 클래스 (`d-card`, `d-cp`, `d-pool`, `d-agent`, `d-*-box`, `d-ttl`, `d-sub`, `d-lbl`, `d-mono`, `d-e-api|async|prov|user|obs|fail|git`, 마커 `d-mk-*`) 를 쓴다. 이 어휘는 예선 팀의 v5.5 아키텍처 그림(카드형, 둥근 모서리 12, 점선 영역, 선 종류별 의미)과 같다: 회색 실선=API 호출, 보라 점선=비동기, 주황=배포·프로비저닝, 파랑=사용자 트래픽, 청록 점선=관측, 초록=Git/GitOps, 빨강 점선=실패. 색을 리터럴로 쓰지 말 것 (다크 모드). 모든 도형에 class 또는 fill 지정. `<svg viewBox=...>` 에 width/height 속성 없이, `<div class="fig scroll">` (넓으면 `scroll-l`) 안에. 마커 id 는 페이지 안에서 겹치지 않게 그림마다 접두사. 글자가 상자 밖으로 나가지 않게 좌표를 계산하고 (한글 13.5px ≈ 글자당 13~14px 폭), 선이 글자를 가로지르지 않게. `<title>` 로 접근성 이름.
   - mermaid (`<pre class="mermaid">`): 시퀀스, 순서도(flowchart), 상태도(stateDiagram-v2), 클래스도 등. 라벨은 큰따옴표로 감싼다 `A["라벨 (괄호 가능)"]`. 줄바꿈은 `<br/>`. 라벨 안에 `"`, `;`, `#`, `{}` 쓰지 말 것. sequenceDiagram 의 메시지 텍스트에 `;` 금지. 한 그림은 20개 노드 안쪽으로.
6. 매 기술/절마다 들어갈 것: 우리 PoC 의 어느 폴더·파일이 이걸 하는지(`code-head` + 실제 코드 발췌, 발췌 위에 경로), 한 줄씩 해설, 의사코드(`pre.pseudo`), 순서도, `callout poc`(우리 PoC 에서는), `callout break`(깨지면 이렇게 보인다: 증상, 볼 곳, 고치는 법), `callout why`(왜 이걸 골랐나, 대안과 버린 이유), 필요하면 `callout warn`.
7. 장 맨 앞 `이 장의 지도`: 이 장이 전체 아키텍처의 어디인지 작은 SVG 하나 + 이 장의 절 목록과 각각 한 줄. 장 맨 끝 `정리`: 핵심 개념 체크리스트(`ul.checklist`), 이 장의 핵심 결정 표(선택/대안/버린 이유), 본선에서 떠올릴 패턴(이 개념을 다른 주제에 어떻게 옮기나), 스스로 답해 볼 질문 8~12개.
8. 코드 발췌 안의 `<`, `>`, `&` 는 반드시 `&lt;` `&gt;` `&amp;` 로. Helm 템플릿의 `{{ }}` 는 그대로 써도 된다.
9. 사실 확인: 레포 파일을 직접 읽고 쓴다 (`poc/<단계>/README.md`, 실제 YAML·스크립트·코드). 레포 정답본은 이제 원래 자리(예 `poc/03-tenant-isolation/charts/tenant/`)에 있다. 전체 맥락은 `poc/ANALYSIS.md`, `poc/RUN-ALL.md` 를 먼저 읽는다. 공식 문서는 WebFetch/WebSearch 로 확인해도 된다. 확실하지 않은 동작은 "【확인 필요】" 로 표시.

## 전체 아키텍처 (모든 장이 같은 이름을 쓴다)
- kind 클러스터 `faas` (컨텍스트 `kind-faas`), CNI = Cilium + Hubble, 노드: control-plane 1 + 워커 3 (`pool=system` taint 없음 / `pool=build` taint `pool=build:NoSchedule` / `pool=exec` taint `pool=exec:NoSchedule`). 맥 8081 → control-plane 노드 NodePort 31080 → Kourier.
- 맥: localhost:8080 Argo CD UI(port-forward), 8081 Kourier 입구, 8090 컨트롤 플레인 API(port-forward), 5001 kind-registry(registry:2, 클러스터 안 이름 `kind-registry:5000`).
- namespace: argocd, argo-rollouts, monitoring(Prometheus `prometheus-server:80`), knative-serving, kourier-system, faas-system(컨트롤 플레인), faas-build(05 빌드 Job), fn-build(04 빌드 Job), fn-runtime(04 함수 hello-runc/hello-gvisor/hello-gvisor-warm), fn-demo(01 hello-fn, bye-fn), fn-canary(02 podinfo Rollout), tenant-a, tenant-b(03 울타리 + hello-fn, 05 함수 tenant-a/hello).
- Argo CD Application: root(App of Apps → hello-fn, bye-fn), podinfo, ApplicationSet tenants → tenant-a/tenant-b, tenant-a-hello, tenant-b-hello, faas-functions, platform-05.
- 두 갈래: 플랫폼은 GitOps(Argo CD), 사용자 함수는 컨트롤 플레인이 쿠버네티스 API 로 직접(kaniko Job → digest → Knative Service server-side apply).
- 06 은 대역 클러스터 `chaos` (워커 system/build/exec/exec), 07 은 AWS EC2 위 k3s (코드만, 실제 apply 안 함).
- run-all.sh 순서: platform(04 rebuild-cluster: 클러스터+Cilium+Argo CD+root+registry+Knative+Kourier+gVisor+빌드 v1+faas-functions) → rollouts(02) → tenants(03) → control-plane(05) → check, 별도 chaos(06).

## 하지 말 것
- 자기 장 파일 외의 파일을 만들거나 고치지 않는다 (`guide.css`, `guide.js`, 다른 장, 레포 코드 전부 금지). 커밋·push 금지. `/mnt/project-files` 쓰지 않는다.
- AWS·클러스터 명령 실행 금지 (읽기만).

## 끝내기 전 검사 (직접 돌린다)
```bash
python3 - docs/guide/chNN-xxx.html <<'EOF'   # 경로를 자기 파일로
import sys, html.parser, re
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
class P(html.parser.HTMLParser):
    def __init__(s2): super().__init__(); s2.stack=[]; s2.err=[]
    VOID={'meta','link','br','img','hr','input','path','rect','circle','line','ellipse','polygon','polyline','stop','use'}
    def handle_starttag(s2,t,a):
        if t not in s2.VOID: s2.stack.append(t)
    def handle_startendtag(s2,t,a): pass
    def handle_endtag(s2,t):
        if t in s2.VOID: return
        if s2.stack and s2.stack[-1]==t: s2.stack.pop()
        else: s2.err.append((t, s2.getpos(), s2.stack[-3:]))
x=P(); x.feed(s); print('unclosed', x.stack[-5:], 'mismatch', x.err[:10])
ids=re.findall(r'id="([^"]+)"', s); d={i for i in ids if ids.count(i)>1}; print('dup ids', d)
print('svg', s.count('<svg'), 'mermaid', s.count('class="mermaid"'), 'tier', s.count('class="tier"'), 'bytes', len(s.encode()))
print('literal colors in svg', re.findall(r'(?:fill|stroke)="#[0-9a-fA-F]{3,6}"', s)[:5])
EOF
```
- 결과: unclosed/mismatch/dup ids 비어 있음, 리터럴 색 없음.
- 마지막 보고: 파일 경로, 절 목록, SVG 개수, mermaid 개수, 【확인 필요】 표시한 곳, 레포에서 발견한 이상한 점(코드와 README 가 다른 곳 등).
