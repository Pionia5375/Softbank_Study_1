// k6 부하 스크립트: 1초에 RATE 번씩 일정하게 GET /hello 를 보내고, 끝나면 p50/p95/p99 와 에러율을 한 줄로 찍는다.
// 직접 돌리지 말고 scripts/k6-run.sh 로 돌린다 (클러스터 안 Pod 로 실행).
// k6 버전: grafana/k6:2.3.0 【사실: Docker Hub grafana/k6 태그, 2026-09-21】
// 문법 출처: https://grafana.com/docs/k6/latest/using-k6/scenarios/executors/constant-arrival-rate/
//            https://grafana.com/docs/k6/latest/results-output/end-of-test/custom-summary/
import http from 'k6/http';
import { check } from 'k6';

const TARGET = __ENV.TARGET || 'http://traefik.traefik.svc.cluster.local/hello';
// TODO(human): 1초에 몇 번 보낼지(RPS). 추천 기본값 200.
//   기준: 조건이 바뀌어도 "같은 양" 을 보내야 p95 를 비교할 수 있다. 그래서 VU 수가 아니라 도착률(arrival rate)로 고정한다.
//   200 에서 모든 조건의 p95 가 다 비슷하게 작으면(차이 1ms 안쪽) 400 → 800 으로 올려서, replicas 1 + CPU limit 조건이 먼저 버거워지는 지점을 찾는다.
//   k6-run.sh 의 3번째 인자로 덮어쓸 수도 있다 (scripts/k6-run.sh <이름표> <대상> <RPS>)
const RATE = parseInt(__ENV.RATE || '200', 10);
const WARMUP = __ENV.WARMUP || '20s';   // JVM 이 막 뜬 직후(JIT 컴파일 전)는 느리다. 이 구간은 결과에서 뺀다
const DURATION = __ENV.DURATION || '2m';

export const options = {
  scenarios: {
    // 1) 몸풀기: RATE 의 1/4 로 20초. 결과표에는 안 들어간다
    warmup: {
      executor: 'constant-arrival-rate',
      rate: Math.max(1, Math.floor(RATE / 4)),
      timeUnit: '1s',
      duration: WARMUP,
      preAllocatedVUs: 20,
      maxVUs: 100,
    },
    // 2) 본 측정: 1초에 RATE 번, DURATION 동안.
    //    응답이 느려져도 보내는 양은 그대로라서(느려지면 VU 를 더 꺼내 씀), 서버가 버거워지면 p95 가 바로 드러난다
    measure: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DURATION,
      startTime: WARMUP,
      preAllocatedVUs: 50,
      maxVUs: 400,   // 이걸로도 모자라면 dropped_iterations 가 생긴다 = "k6 가 목표 RPS 를 못 채움"
    },
  },
  // 요약에 보여 줄 통계. med = p50
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  // 임계값. 여기선 합격/불합격보다 "measure 구간만 따로 집계" 하게 만드는 용도가 크다
  //   ({scenario:measure} 처럼 태그로 걸러 낸 지표는 임계값을 걸어야 요약 데이터에 나온다)
  thresholds: {
    'http_req_duration{scenario:measure}': ['p(95)<1000'],
    'http_req_failed{scenario:measure}': ['rate<0.01'],
    'http_reqs{scenario:measure}': ['count>0'],
  },
};

export default function () {
  const res = http.get(TARGET, { timeout: '10s' });
  check(res, { 'status 200': (r) => r.status === 200 });
}

// 끝나면 결과를 사람이 읽기 쉬운 몇 줄 + 표에 붙여 넣을 한 줄(RESULT)로 찍는다
export function handleSummary(data) {
  const m = data.metrics;
  const d = m['http_req_duration{scenario:measure}'];
  const f = m['http_req_failed{scenario:measure}'];
  const n = m['http_reqs{scenario:measure}'];
  const dropped = m.dropped_iterations ? m.dropped_iterations.values.count : 0;
  const vusMax = m.vus_max ? m.vus_max.values.max : 0;
  const ms = (v) => (v === undefined ? 'NA' : v.toFixed(1));
  const durSec = parseDuration(DURATION);
  const count = n ? n.values.count : 0;
  const rps = (count / durSec).toFixed(1);
  const errPct = f ? (f.values.rate * 100).toFixed(2) : 'NA';

  const lines = [
    '',
    `target=${TARGET} rate=${RATE}/s duration=${DURATION} (warmup ${WARMUP} 제외)`,
    `requests=${count}  rps=${rps}  dropped=${dropped}  vus_max(할당된 VU)=${vusMax}`,
    `p50=${ms(d && d.values.med)}ms  p95=${ms(d && d.values['p(95)'])}ms  p99=${ms(d && d.values['p(99)'])}ms  max=${ms(d && d.values.max)}ms`,
    `error_rate=${errPct}%`,
    // 표에 붙여 넣기용: RPS | p50 | p95 | p99 | 에러율
    `RESULT | ${rps} | ${ms(d && d.values.med)} | ${ms(d && d.values['p(95)'])} | ${ms(d && d.values['p(99)'])} | ${errPct}% |`,
    '',
  ];
  return { stdout: lines.join('\n') };
}

// "2m", "90s", "1m30s" → 초
function parseDuration(s) {
  let total = 0;
  const re = /(\d+)(h|m|s)/g;
  let x;
  while ((x = re.exec(s)) !== null) {
    total += parseInt(x[1], 10) * { h: 3600, m: 60, s: 1 }[x[2]];
  }
  return total || 1;
}
