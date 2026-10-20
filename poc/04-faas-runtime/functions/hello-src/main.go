// hello: 측정용 함수 (Claude 작성, 완성본).
// 하는 일
//   GET /                     → JSON 한 줄. 어느 Pod·어느 커널에서 돌았는지, 이 프로세스의 첫 요청(cold)인지
//   GET /?work=cpu&ms=20      → 20ms 동안 CPU 를 돌린다 (계산 위주 함수 흉내)
//   GET /?work=io&n=200       → 작은 파일을 200번 만들고 지운다 (시스템 콜 위주 함수 흉내. gVisor 가 느려지는 쪽)
// 외부 라이브러리 없음 → 빌드할 때 인터넷은 베이스 이미지 받을 때만 필요하다.
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"sync/atomic"
	"syscall"
	"time"
)

var (
	started = time.Now()
	served  atomic.Int64
)

// kernel 은 uname 의 release 값. runc 면 호스트(노드) 커널, gVisor 면 gVisor 가 흉내 내는 가짜 커널 번호가 나온다.
func kernel() string {
	var u syscall.Utsname
	if err := syscall.Uname(&u); err != nil {
		return "unknown"
	}
	b := make([]byte, 0, len(u.Release))
	for _, c := range u.Release {
		if c == 0 {
			break
		}
		b = append(b, byte(c))
	}
	return string(b)
}

func burnCPU(d time.Duration) {
	end := time.Now().Add(d)
	x := 0
	for time.Now().Before(end) {
		x++
	}
	_ = x
}

func syscallHeavy(req int64, n int) error {
	dir := os.TempDir()
	for i := 0; i < n; i++ {
		// 요청마다 다른 이름 (동시 요청끼리 같은 파일을 지우지 않게)
		p := filepath.Join(dir, fmt.Sprintf("fn-io-%d-%d", req, i))
		if err := os.WriteFile(p, []byte("x"), 0o600); err != nil {
			return err
		}
		if _, err := os.Stat(p); err != nil {
			return err
		}
		if err := os.Remove(p); err != nil {
			return err
		}
	}
	return nil
}

func handler(w http.ResponseWriter, r *http.Request) {
	t0 := time.Now()
	n := served.Add(1)
	q := r.URL.Query()
	switch q.Get("work") {
	case "cpu":
		ms, _ := strconv.Atoi(q.Get("ms"))
		burnCPU(time.Duration(ms) * time.Millisecond)
	case "io":
		cnt, _ := strconv.Atoi(q.Get("n"))
		if err := syscallHeavy(n, cnt); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	}
	host, _ := os.Hostname()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"fn":        os.Getenv("FN_NAME"),
		"pod":       host,
		"kernel":    kernel(),
		"cold":      n == 1,
		"uptime_ms": time.Since(started).Milliseconds(),
		"work_ms":   float64(time.Since(t0).Microseconds()) / 1000,
	})
}

func main() {
	port := os.Getenv("PORT") // Knative 가 넣어 주는 값 (기본 8080)
	if port == "" {
		port = "8080"
	}
	http.HandleFunc("/", handler)
	log.Printf("hello: listening on :%s (process start → listen %s)", port, time.Since(started))
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}
