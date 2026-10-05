package com.example.hello;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    // 헬스체크용. 기동 완료 시간 측정(measure.sh)과 HEALTHCHECK 가 이 경로를 본다.
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }

    // 어느 컨테이너가 응답했는지 보이도록 hostname 을 같이 돌려준다 (K8s 다중 Pod 단계에서 유용).
    @GetMapping("/hello")
    public Map<String, String> hello() throws UnknownHostException {
        return Map.of(
                "message", "hello",
                "host", InetAddress.getLocalHost().getHostName());
    }
}
