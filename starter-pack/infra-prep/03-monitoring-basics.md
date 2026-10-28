로드맵 위치: 본선 D-10 / 모니터링 기본: 골든 시그널 4개 · SLO 1개 · 알림 1개를 실제로 울려 보기 / 본선 연결점: "그 성능 주장은 무엇으로 쟀나" 에 숫자로 답하고, 장애 데모에서 알림이 실제로 뜨는 장면 (완성도·데모 30, 클라우드 활용 30)

# 03. 모니터링 기본

전제: 드릴 클러스터(`kind-prep`)가 떠 있고 `scripts/ports.sh` 로 Grafana(3000)·Prometheus(9090)가 열려 있다.

읽는 순서: 1절(골든 시그널) → 2절(지표가 어떻게 흐르나) → 3절(SLO) → 4절(알림 울리기, 손으로) → 5절(Slack 으로 보내기, 본선용) → 6절(1일차 할 말).

---

## 1. 골든 시그널 4개 (0부터)

"서비스가 건강한가" 를 볼 때 수십 개 지표 중 **딱 4개만 먼저 본다** 는 규칙. Google SRE 책에서 나왔다. 【사실: https://sre.google/sre-book/monitoring-distributed-systems/#xref_monitoring_golden-signals 】

| 신호 | 질문 | podinfo 에서 (PromQL) | 대시보드 패널 |
|---|---|---|---|
| **지연 (Latency)** | 요청 하나가 얼마나 걸리나. 평균 말고 **p95/p99** (느린 5% 가 사용자 경험) | `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="podinfo"}[2m])))` | 1 |
| **트래픽 (Traffic)** | 초당 요청 몇 개가 오나 | `sum by (pod) (rate(http_requests_total{namespace="podinfo"}[2m]))` | 2 |
| **에러 (Errors)** | 그중 몇 % 가 실패하나 (5xx) | `sum(rate(http_requests_total{namespace="podinfo",status=~"5.."}[2m])) / sum(rate(http_requests_total{namespace="podinfo"}[2m]))` | 3 |
| **포화 (Saturation)** | 자원이 얼마나 꽉 찼나. CPU ÷ requests, 메모리 ÷ limit, 큐 길이 | `rate(container_cpu_usage_seconds_total{namespace="podinfo",container="podinfo"}[2m]) / kube_pod_container_resource_requests{...resource="cpu"}` | 4 |

왜 이 넷인가: 앞의 셋(지연·트래픽·에러)은 **사용자가 느끼는 것**, 포화는 **곧 사용자가 느끼게 될 것** 의 선행 신호다. 다른 묶음도 있다: RED(Rate·Errors·Duration = 요청 관점, 앞의 셋과 같음), USE(Utilization·Saturation·Errors = 자원 관점). 골든 시그널은 둘을 합친 것이라고 보면 된다.

Grafana → Dashboards → "podinfo · 골든 시그널 4개" 가 이 넷이다. 지금은 트래픽이 거의 0(프로브와 Prometheus 긁기만)이라 그래프가 심심하다. 4절에서 채운다.

## 2. 지표가 어떻게 흐르나

```
podinfo 파드  ──(/metrics 에 텍스트로 노출)──┐
                                             │ 15초마다 HTTP GET (pull)
ServiceMonitor ──► Prometheus Operator ──► Prometheus 설정 ──► Prometheus 가 긁어서 TSDB 에 저장
                                                                    │
                                              PromQL 질의 ◄─────────┤
                                        Grafana 패널 / 알림 규칙 평가(15초마다) ──► FIRING ──► (Alertmanager ──► Slack)
```

알아 둘 단어 4개:
- **카운터(counter)**: 늘기만 하는 수 (`http_requests_total`). 그 자체는 의미 없고 `rate(x[2m])` = "최근 2분 동안 초당 평균 증가량" 으로 본다. 15초 간격이면 2분 창에 점 8개.
- **게이지(gauge)**: 오르내리는 수 (`container_memory_working_set_bytes`). 그대로 본다.
- **히스토그램(histogram)**: "0.005초 이하 n개, 0.01초 이하 n개, …" 칸별 누적 개수 (`_bucket`, 칸 경계가 `le` 라벨). `histogram_quantile(0.95, …)` 이 칸을 보고 p95 를 **근사** 한다. 칸이 성기면 부정확하다(podinfo 는 Go 기본 칸 0.005~10초 【사실: prometheus.DefBuckets】).
- **라벨(label)**: 같은 지표 이름을 `{namespace, pod, status}` 로 쪼갠다. `sum by (pod)` = pod 별로 더하기.

`kubectl -n podinfo port-forward svc/podinfo 19898:9898` 후 `curl localhost:19898/metrics | grep http_` 로 원본 텍스트를 한 번 눈으로 본다 (1분).

## 3. SLO 1개

단어 셋:
- **SLI** (indicator): 재는 값. 여기선 "5xx 가 아닌 응답의 비율" = `podinfo:http_success_ratio:rate2m` (기록 규칙으로 만들어 둠).
- **SLO** (objective): 목표. **"30일 동안 요청의 99% 가 성공한다."**
- **에러 예산** (error budget): 100% − SLO = **1%**. 30일 = 43,200분이니, 완전 장애로 치면 **432분(7.2시간)** 까지는 SLO 를 안 깨고 쓸 수 있는 "실패 허용량".

왜 100% 가 아니라 99% 인가: 100% 는 배포를 못 하게 만든다(모든 배포가 위험). 예산이 있으면 "예산 남았으니 카나리 배포 가자 / 예산 다 썼으니 이번 주는 안정화만" 같은 **결정의 근거** 가 된다. 심사에서 "왜 그 숫자냐" 가 나오면: "데모 서비스고 의존성(DB 등)이 없어서 99% 로 시작, 실제 측정값 보고 99.5 로 올릴지 결정" 이라고 답한다.

**번 레이트(burn rate)**: 지금 속도로 가면 예산을 얼마나 빨리 다 쓰나. `실제 에러율 ÷ (1 − SLO)`.
- 에러율 1% = 번 레이트 1 → 딱 30일에 소진 (정상 최대치)
- 에러율 5% = 번 레이트 5 → 30일 ÷ 5 = **6일** 만에 소진
- 에러율 50% = 번 레이트 50 → 14.4시간 만에 소진

4절의 알림 문턱 5% 는 번 레이트 5 다. "1분이면 예산의 0.0116%" 라 당장 SLO 가 깨지진 않지만, 방치하면 6일 안에 깨지는 속도니 **사람이 볼 가치가 있다**.

【대안】 지연 SLO: "95% 의 요청이 300ms 안에" → SLI 가 `_bucket{le="0.3"}` ÷ `_count`. 셀프 연습에서 다룬다.

## 4. 알림 1개 (손으로 울려 보기, 40분)

### 4.1 규칙 읽기

`gitops/monitoring/podinfo-rules.yaml`:
```yaml
- alert: PodinfoHighErrorRate
  expr: podinfo:http_success_ratio:rate2m < 0.95   # 성공률 95% 미만 = 에러 5% 초과
  for: 1m                                          # 1분 내내 참이어야 FIRING. 그 전엔 PENDING
  labels: { severity: warning, team: platform }    # 라우팅용 (Alertmanager 가 severity 로 Slack 채널을 고른다)
  annotations: { summary, description, runbook }   # 사람이 읽을 글. runbook = 받은 사람이 처음 할 일
```
- `expr` 이 **기록 규칙 이름** 인 이유: 대시보드 패널 3 과 알림이 **같은 숫자** 를 본다. 따로 쓰면 "대시보드는 괜찮은데 알림은 울림" 같은 혼란이 생긴다.
- `for: 1m` 이 없으면 한 번 튄 값에 울린다. 길면(10m) 진짜 장애를 늦게 안다. 1분은 데모용으로 짧게 잡은 값.
- 분자에 `or vector(0)`: 5xx 가 하나도 없으면 분자가 "빈 결과" 라 나눗셈 전체가 비어 버린다 → 0 을 채워 성공률 1 이 나오게.

### 4.2 울리기

터미널 A (상태 보기):
```bash
# Prometheus 의 알림 상태를 5초마다. 처음엔 inactive
watch -n 5 'curl -s localhost:9090/api/v1/alerts | python3 -c "import sys,json; [print(a[\"labels\"][\"alertname\"], a[\"state\"], a.get(\"activeAt\",\"\")) for a in json.load(sys.stdin)[\"data\"][\"alerts\"]]"'
# 또는 브라우저 http://localhost:9090/alerts 새로고침
```

터미널 B (에러 넣기), 시작 시각을 적는다:
```bash
date
# hey = 한 줄 부하 도구. -z 3m 3분 동안, -q 5 초당 5개, /status/500 = podinfo 가 일부러 500 을 돌려주는 경로
hey -z 3m -q 5 http://localhost:9898/status/500
# hey 가 없으면:
# for i in $(seq 1 900); do curl -s -o /dev/null localhost:9898/status/500; sleep 0.2; done
```

무슨 일이 나나 (시간순):
1. 0~30초: Prometheus 가 다음 긁기(15초 간격)에서 500 카운터 증가를 본다
2. ~30초: `rate([2m])` 이 올라가 성공률이 0.95 밑으로 → 알림 **PENDING** (노란색)
3. +1분 (`for`): **FIRING** (빨간색). `activeAt` 에 시각이 찍힌다
4. 에러 멈춘 뒤: 2분 창에서 500 이 빠져나가며 성공률 회복 → **inactive**. 약 2~3분

적을 것 (`results/drill.md` 알림 표): 에러 시작 → PENDING, → FIRING 까지 초, 멈춘 뒤 해제까지 초. 그동안 Grafana 패널 3(에러) 이 빨간 선(5%)을 넘는 것, 패널 2(트래픽) 가 5 req/s 로 올라가는 것을 본다.

**확인 질문 1개**: `for: 1m` 인데 FIRING 까지 1분보다 더 걸린다. 어디서 시간이 더 드나? (답: 긁기 간격 15초 + `rate` 창 2분이 채워지는 동안의 지연 + 평가 간격 15초. 알림 지연 = 긁기 + 창 + for + 평가.)

**출력 붙여 보내기**: FIRING 상태의 `curl -s localhost:9090/api/v1/alerts` 한 줄 (또는 Alerts 화면 캡처) + 걸린 초.

### 4.3 깨뜨려 보기 (10분, 하나)

- `podinfo-rules.yaml` 의 `for: 1m` → `for: 0s` 로 바꿔 push → 반영 후 같은 실험. 얼마나 빨라지나. 그리고 `hey -z 10s` 처럼 **짧게** 넣었을 때 울리나 (울린다 = 거짓 양성이 늘어난다는 뜻).
- 분자의 `or vector(0)` 를 지우고 push → 트래픽이 아예 없을 때 Prometheus UI 에서 `podinfo:http_success_ratio:rate2m` 이 "Empty query result" 가 되는 것을 본다. 알림이 "절대 안 울리는" 상태 = 가장 위험한 모니터링.

## 5. Slack 으로 보내기 (본선 1일차에 붙일 것, 지금은 읽기만)

Prometheus 는 "울리는 것" 까지만 하고, **보내는 것** 은 Alertmanager 다. 드릴은 껐다(`alertmanager.enabled: false`). 본선에서는:

```yaml
# monitoring/kps-values.yaml 에 추가 (Slack 앱에서 Incoming Webhook URL 을 하나 만든다)
alertmanager:
  enabled: true
  config:
    route:
      receiver: slack-alerts
      group_by: [alertname, namespace]
      group_wait: 10s          # 같은 그룹 알림을 10초 모았다가 한 번에
      repeat_interval: 1h      # 계속 울리면 1시간마다 다시
    receivers:
      - name: slack-alerts
        slack_configs:
          - api_url: https://hooks.slack.com/services/XXX/YYY/ZZZ   # 비밀. Git 에 넣지 말고 Secret + existingSecret 로
            channel: "#alerts"
            send_resolved: true
            title: '{{ .CommonLabels.alertname }} ({{ .Status }})'
            text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.runbook }}\n{{ end }}'
```
【사실: https://prometheus.io/docs/alerting/latest/configuration/#slack_config 】. 웹훅 URL 은 비밀이라 Git 에 넣으면 안 되고, 본선 레포가 public 이면 더더욱. `alertmanager.alertmanagerSpec.alertmanagerConfigSelector` + `AlertmanagerConfig` CRD 로 쪼개는 방법도 있다(더 GitOps 답지만 1일차엔 values 가 빠르다).

## 6. 1일차에 꺼낼 "모니터링 최소 세트" 제안

- kube-prometheus-stack 1개 (Grafana 포함), 앱마다 `/metrics` + ServiceMonitor
- 골든 시그널 대시보드 1장 (이 팩의 JSON 을 앱 이름만 바꿔서)
- SLO 1개(성공률 99%) + 알림 2~3개: 에러율(이 팩), 지연 p95, 파드 준비 수 < 원하는 수 (`poc/06` 의 `FnReplicasUnavailable`)
- Slack `#alerts` 채널 + Alertmanager
- 데모 시나리오에 **"일부러 장애 → 알림 뜸 → 롤백/복구 → 해제"** 장면 1개. 작년 본선 심사평이 "실제로 동작하는가" 였다【사실: notes/research/career/03】. 이 장면이 그 답이다.

말할 때: "알림은 적게, 대신 각각에 runbook 한 줄. 알림이 많으면 아무도 안 본다."

---

## 핵심 결정 3개 (+대안)

1. **SLI 는 성공률(5xx 아닌 비율) 하나로 시작.** 대안: 지연 SLO 먼저 / 가용성(프로브 기반). 이유: 가장 설명하기 쉽고, 장애 주입(`/status/500`)으로 즉시 검증된다. 지연은 셀프 연습으로.
2. **알림 문턱 5% + for 1m (번 레이트 5).** 대안: 1%(SLO 그대로) / 다중 창 번 레이트(Google SRE workbook: 1h 창 14.4배 & 5m 창 14.4배 등 【사실: https://sre.google/workbook/alerting-on-slos/ 】). 이유: 1% 는 잡음, 다중 창은 정확하지만 규칙 4개에 설명 10분. 데모엔 하나로 이해되는 규칙이 낫고, 다중 창은 "다음 단계" 로 말한다.
3. **기록 규칙으로 SLI 를 만들고 대시보드와 알림이 공유.** 대안: 각자 식을 쓴다. 이유: 숫자가 하나여야 "대시보드엔 괜찮은데 알림이 울려요" 가 없다. 비용: 15초마다 식 2개 더 계산(무시할 수준).

## 셀프 연습 1개

지연 알림 `PodinfoHighLatency` 를 `podinfo-rules.yaml` 에 추가한다: p95 > 0.5초가 1분 이상. 식은 기록 규칙 `podinfo:http_latency_p95_seconds:rate2m > 0.5`. push → `hey -z 2m -q 3 http://localhost:9898/delay/1` (1초 지연 경로)로 울려 본다. 울리면 `results/drill.md` 에 한 줄.

## 검증 명령과 기대 출력

```bash
curl -s localhost:9090/api/v1/rules | python3 -c "import sys,json; [print(r['name'], r.get('state','')) for g in json.load(sys.stdin)['data']['groups'] if g['name']=='podinfo.slo' for r in g['rules']]"
#   podinfo:http_success_ratio:rate2m
#   podinfo:http_latency_p95_seconds:rate2m
#   PodinfoHighErrorRate inactive        ← 에러 넣는 동안은 pending → firing

curl -s 'localhost:9090/api/v1/query?query=podinfo:http_success_ratio:rate2m' | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['result'][0]['value'][1])"
#   1  (평소)  /  0.0xx (hey 로 500 넣는 동안)
```
