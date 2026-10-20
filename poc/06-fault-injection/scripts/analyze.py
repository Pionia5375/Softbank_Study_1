#!/usr/bin/env python3
"""프로브 로그 분석 (Claude 작성).

probe.sh 가 받은 로그(줄마다 "시각 응답코드 걸린초")를 장애 주입 시각 t0 기준으로 잘라
  - 주입 전(baseline): 요청 수, p50/p95, 에러율
  - 주입 후: 에러 수, 첫 에러~마지막 에러 구간(=사용자가 본 장애 시간), t0 → 마지막 에러(=복구까지)
  - 주입 후 window 초 동안의 p95
를 계산해 화면에 쓰고, --csv 파일에 한 줄 추가한다. 외부 라이브러리 없이 표준 라이브러리만 쓴다.

사용 예:
  analyze.py --log results/s1-hard-1.probe.log --t0 1760970000.1 --csv results/s1-node-down.csv \
             --extra "scenario=s1,mode=hard,run=1,t_notready_s=41.2"
"""
import argparse, csv, datetime, os, sys


def parse_ts(s):
    # 2026-10-20T15:30:01.123456789Z → 유닉스 초 (나노초는 마이크로초까지만)
    s = s.rstrip("Z")
    if "." in s:
        head, frac = s.split(".", 1)
        s = head + "." + frac[:6]
        fmt = "%Y-%m-%dT%H:%M:%S.%f"
    else:
        fmt = "%Y-%m-%dT%H:%M:%S"
    return datetime.datetime.strptime(s, fmt).replace(tzinfo=datetime.timezone.utc).timestamp()


def pct(vals, p):
    if not vals:
        return None
    v = sorted(vals)
    k = max(0, min(len(v) - 1, int(round(p / 100.0 * len(v) + 0.5)) - 1))
    return v[k]


def ms(x):
    return "" if x is None else "%.1f" % (x * 1000)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True)
    ap.add_argument("--t0", type=float, required=True, help="장애 주입 시각 (유닉스 초)")
    ap.add_argument("--window", type=float, default=60, help="주입 후 p95 를 볼 구간(초)")
    ap.add_argument("--csv", required=True)
    ap.add_argument("--extra", default="", help="CSV 에 같이 쓸 key=value,key=value")
    a = ap.parse_args()

    rows = []
    for line in open(a.log):
        parts = line.split()
        if len(parts) != 3:
            continue
        try:
            rows.append((parse_ts(parts[0]), parts[1], float(parts[2])))
        except ValueError:
            continue
    if not rows:
        sys.exit("프로브 로그가 비었다: " + a.log)

    before = [r for r in rows if r[0] < a.t0]
    after = [r for r in rows if r[0] >= a.t0]
    ok = lambda r: r[1].startswith("2")
    errs = [r for r in after if not ok(r)]
    win = [r for r in after if r[0] < a.t0 + a.window]

    res = {
        "baseline_n": len(before),
        "baseline_p50_ms": ms(pct([r[2] for r in before if ok(r)], 50)),
        "baseline_p95_ms": ms(pct([r[2] for r in before if ok(r)], 95)),
        "baseline_err_pct": "%.1f" % (100.0 * sum(1 for r in before if not ok(r)) / max(1, len(before))),
        "after_n": len(after),
        "errors": len(errs),
        "err_pct_window": "%.1f" % (100.0 * sum(1 for r in win if not ok(r)) / max(1, len(win))),
        "p95_window_ms": ms(pct([r[2] for r in win if ok(r)], 95)),
        "first_err_s": "%.1f" % (errs[0][0] - a.t0) if errs else "",
        "last_err_s": "%.1f" % (errs[-1][0] - a.t0) if errs else "0",
        "outage_s": "%.1f" % (errs[-1][0] - errs[0][0]) if errs else "0",
    }

    print("  주입 전  : 요청 %(baseline_n)s개, p50 %(baseline_p50_ms)sms, p95 %(baseline_p95_ms)sms, 에러 %(baseline_err_pct)s%%" % res)
    print("  주입 후  : 요청 %(after_n)s개 중 에러 %(errors)s개" % res)
    if errs:
        print("  에러 구간: 주입 후 %(first_err_s)ss ~ %(last_err_s)ss (사용자가 본 장애 %(outage_s)ss)" % res)
    print("  주입 후 %ss: 에러 %s%%, p95 %sms" % (int(a.window), res["err_pct_window"], res["p95_window_ms"]))

    extra = {}
    for kv in filter(None, a.extra.split(",")):
        k, _, v = kv.partition("=")
        extra[k.strip()] = v.strip()
    row = dict(date=datetime.date.today().isoformat(), **extra)
    row.update(res)
    new = not os.path.exists(a.csv)
    with open(a.csv, "a", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(row.keys()))
        if new:
            w.writeheader()
        w.writerow(row)
    print("  → " + a.csv)


if __name__ == "__main__":
    main()
