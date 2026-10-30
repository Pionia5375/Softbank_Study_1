로드맵 위치: 본선 직전 주(D-8) / Kyverno 개념 + 본선 아키텍처(k8s 버전) 안의 역할 / 본선 연결점 = 장면 2(보안·거버넌스 한 화면)와 장면 3(에이전트 샌드박스 게이트)의 엔진

# 13. Kyverno — 무엇이고, 우리 아키텍처에서 어디에 서 있나

> 작성 2026-10-30. 그림: 아키텍처 v0.1-k8s (`notes/architecture/finals-architecture-v0.1-k8s.html`).
> 표기: 【사실】(출처) / 【추정】 / 【미확인】. 버전별 필드 이름은 설치 전에 공식 문서로 다시 확인할 것.

## 1. 0부터: 문제가 뭐였나

k8s에서는 모든 것이 YAML로 들어온다. 사람이 `kubectl apply`를 하든, Argo CD가 동기화를 하든, 결국 API 서버에 "이 Pod를 만들어 줘"라는 요청이 간다.

k8s 기본 기능만으로는 이 요청이 **문법에 맞는지**만 본다. "root로 도는 컨테이너", "아무 레지스트리 이미지", "리소스 제한 없는 Pod"도 문법만 맞으면 그대로 들어간다. 팀이 커지거나 환경이 여러 개가 되면, 누가 어디에 뭘 넣었는지 사람이 일일이 볼 수 없다.

그래서 "들어오기 직전에 규칙으로 검사하는 문지기"가 필요하다. 이걸 **정책 엔진(policy engine)** 이라고 부르고, Kyverno가 그중 하나다.

## 2. Kyverno가 끼어드는 자리

```
kubectl / Argo CD ──요청──▶ API 서버 ──(1) 인증·인가(RBAC)
                                   ──(2) Mutating admission webhook  ◀── Kyverno: 고쳐 넣기
                                   ──(3) 스키마 검사
                                   ──(4) Validating admission webhook ◀── Kyverno: 통과/거부
                                   ──(5) etcd 저장
```

- admission webhook = API 서버가 "저장하기 전에 이 외부 서비스한테 물어보라"고 설정해 둔 훅. Kyverno는 클러스터 안에 Pod로 떠서 이 훅을 받는다.
- RBAC는 "**누가** 이 요청을 할 수 있나", Kyverno는 "**이 내용**이 들어와도 되나"를 본다. 둘은 겹치지 않는다.

## 3. Kyverno 규칙 4종 【사실: Kyverno 공식 문서 개념, 버전별 필드명 차이 있음】

| 종류 | 하는 일 | 예 |
|---|---|---|
| validate | 검사해서 통과/거부 | root 실행 금지, 이미지는 우리 레지스트리만 |
| mutate | 들어오는 YAML을 고쳐 넣기 | 라벨 `env=aws` 자동 추가, 기본 리소스 제한 채우기 |
| generate | 다른 리소스를 자동으로 만들기 | 새 Namespace가 생기면 NetworkPolicy·ResourceQuota 자동 생성 |
| verifyImages | 이미지 서명 검증 | cosign으로 서명된 이미지만 허용 |

동작 모드 2가지:
- **Enforce**: 위반이면 요청 거부. 사용자는 에러 메시지를 받는다.
- **Audit**: 들여보내고 기록만 남긴다.

기록은 어디에? 이미 들어와 있는 리소스도 Kyverno가 주기적으로 다시 검사(background scan)해서 **PolicyReport**라는 k8s 리소스에 "어떤 정책 / 어떤 리소스 / pass·fail / 심각도"를 남긴다. `kubectl get policyreport -A`로 볼 수 있다.

### 3.1 정책 하나 예시

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy                 # 클러스터 전체에 적용 (Namespace 하나면 Policy)
metadata:
  name: sec-001-registry-only       # 정책 ID = 매트릭스의 행/열 키로 씀
  annotations:
    policies.kyverno.io/category: 위반       # 매트릭스 4항목(권한·암호화·감사·위반) 중 어디
    policies.kyverno.io/severity: high
spec:
  validationFailureAction: Enforce  # 막기. Audit이면 기록만. (최신 버전은 rule별 failureAction 필드로 바뀌는 중【미확인: 설치 버전 기준 확인】)
  background: true                  # 이미 있는 리소스도 주기 검사 → PolicyReport
  rules:
    - name: only-our-registry
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        message: "이미지는 ghcr.io/우리조직/ 에서만 가져올 수 있어요"
        pattern:
          spec:
            containers:
              - image: "ghcr.io/우리조직/*"
```

- `match`: 무엇을 검사하나 (Pod). Rollout·Deployment가 만든 Pod도 결국 Pod라 여기 걸린다.
- `pattern`: 이 모양이어야 통과. `*`는 와일드카드.
- 규칙 언어가 **YAML 그 자체**라는 게 Kyverno의 가장 큰 특징이다(아래 대안 비교).

## 4. 우리 아키텍처에서 맡는 역할 5개

같은 정책 파일 묶음이 GitOps 레포 `policies/`에 있고, Argo CD가 EKS·GKE·k3s 세 클러스터에 똑같이 깐다. 그 한 묶음이 다섯 군데에서 쓰인다.

| # | 자리 | 하는 일 | 요구사항 | 데모 장면 |
|---|---|---|---|---|
| ① | 각 클러스터 입구 | 위험한 배포를 **들어오기 전에** 막음 (Enforce) | FR-SEC-03 | 2 |
| ② | 보안 매트릭스의 재료 | 세 클러스터의 PolicyReport를 보안 스캔 핸들러가 모아 공통 스키마로 → 환경 × 4항목 매트릭스 | FR-SEC-02·04, NFR-09 | 2 |
| ③ | CI (PR 단계) | GitOps 레포 PR에서 `kyverno` CLI로 같은 정책을 미리 돌려 봄 → 머지 전에 빨간불 | FR-AGT-03 | 3 |
| ④ | 에이전트 샌드박스 게이트 | 에이전트가 vCluster에서 만든 수정안도 같은 정책을 통과해야 PR 승인 단계로 | FR-AGT-03·06 | 3 |
| ⑤ | 이전 사전 점검 | A→B 이전 전에, A에서 돌던 매니페스트를 **B 클러스터 정책**으로 미리 평가 → "B에선 이게 막힌다" 경고 | FR-MIG-06, FR-SEC-06 | 1 |

덤: generate 규칙으로 새 Namespace(샌드박스 포함)가 생기면 NetworkPolicy 기본 차단 + ResourceQuota를 자동으로 붙인다 → 테넌트 분리를 사람이 빼먹지 않게.

### 4.1 Kyverno가 못 보는 것 (매트릭스에서 빈칸이 생기는 곳)

Kyverno는 **k8s 안의 리소스**만 본다. 매트릭스 4항목 중 일부는 클러스터 밖에 있다.

| 매트릭스 항목 | Kyverno로 되는 것 | 클러스터 밖이라 다른 소스가 필요한 것 |
|---|---|---|
| 권한 | ServiceAccount·RoleBinding 위험 설정 | AWS IAM 정책, GCP IAM (클라우드 API로 조회) |
| 암호화 | Secret 사용 방식, TLS Ingress 강제 | RDS·Cloud SQL 저장 암호화, KMS (클라우드 API) |
| 감사 | 감사 라벨·어노테이션 강제 | CloudTrail·Cloud Audit Logs 켜짐 여부 |
| 위반 | 이미지 출처, root, 리소스 제한 등 | GuardDuty·SCC finding |

→ 그래서 그림의 "보안 수집기"는 **Kyverno PolicyReport + 클라우드 보안 서비스 결과**를 같이 모은다. 이 구분을 설계 문서에 적어 두면 "Kyverno로 다 된다"는 과장을 피한다 【추정: 심사 클라우드 30 대응】.

## 5. 대안 비교

| 대안 | 규칙 언어 | 장점 | 단점 |
|---|---|---|---|
| **Kyverno** | YAML | 배우기 쉬움, mutate·generate·이미지 검증·PolicyReport 다 있음, CLI로 CI 재사용 | 복잡한 논리는 YAML이 장황해짐, 웹훅 Pod가 죽으면 배포가 막힐 수 있음(failurePolicy 설정 필요) |
| OPA Gatekeeper | Rego(전용 언어) | 표현력 최강, k8s 밖(API·Terraform)까지 같은 언어 | Rego 학습 비용, 5일 팀에 부담 |
| Pod Security Admission | 없음(레벨 3개 고정) | k8s 내장, 설치 0 | privileged/baseline/restricted 세 단계뿐, 커스텀 규칙 불가 |
| ValidatingAdmissionPolicy | CEL | k8s 내장(1.30 GA 【사실: k8s 릴리스 노트, 버전 재확인 권장】), 웹훅 없음 → 빠르고 장애점 적음 | 검사만 됨(고치기·생성·리포트 없음) |
| Kubewarden | WebAssembly 정책 | 아무 언어로 정책 작성 | 생태계 작음 |

**우리 선택(제안)**: Kyverno. 이유 = 팀이 YAML만 알면 바로 정책을 쓰고 읽을 수 있고, 매트릭스에 필요한 PolicyReport와 CI CLI가 한 도구에 다 있다. 버린 것: Gatekeeper(Rego 학습 시간), PSA 단독(커스텀 불가), VAP 단독(리포트 없음).

## 6. 프로덕션에서 조심할 점

- **웹훅이 죽으면?** `failurePolicy: Fail`이면 Kyverno가 죽는 순간 모든 배포가 막힌다. `Ignore`면 그 사이 정책이 무력화된다. → Kyverno를 replicas 3으로(HA) 두는 게 프로덕션 기본. 데모 1노드 k3s에선 1개로 두고 설계 문서에 적기.
- **kube-system 같은 시스템 Namespace는 제외**: 안 그러면 클러스터 부품 업그레이드가 자기 정책에 막힌다.
- **처음엔 Audit, 확인 후 Enforce**: 기존 앱이 다 막히는 사고를 피하는 표준 순서.
- **정책도 코드**: 정책 변경 = GitOps PR. 누가 언제 정책을 바꿨는지가 감사 로그가 된다(FR-BASE-07).

## 핵심 결정 3개 (+대안)
1. 정책 엔진 = Kyverno (대안: OPA Gatekeeper / PSA / ValidatingAdmissionPolicy).
2. 세 클러스터에 **같은 정책 묶음**을 GitOps로 배포, 정책 ID를 매트릭스 키로 (대안: 환경별 정책 따로 → "같은 기준" 증명 불가).
3. 매트릭스 = Kyverno PolicyReport + 클라우드 보안 서비스 결과 합치기 (대안: Kyverno만 → 권한·암호화 칸이 빔).

## 셀프 연습 1개
- 위 `sec-001-registry-only`를 Audit으로 바꾸고, `nginx:latest` Pod를 만든 뒤 `kubectl get policyreport -A`에서 fail 1건이 보이는지 확인. 그다음 Enforce로 바꿔 같은 Pod 생성이 거부되는 메시지를 확인. (로컬 kind에서, AWS 아님)

## 검증 명령과 기대 출력
```bash
# kind 클러스터에 Kyverno 설치 (Helm 차트 버전은 설치 시점 최신 안정판으로 고정할 것)
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
kubectl -n kyverno get pods                    # 기대: kyverno-admission-controller 등 Running
kubectl apply -f sec-001-registry-only.yaml
kubectl run bad --image=nginx:latest           # 기대(Enforce): ... denied the request ... 이미지는 ghcr.io/우리조직/ 에서만 ...
kubectl get policyreport -A                    # 기대(Audit): FAIL 열에 1
```
