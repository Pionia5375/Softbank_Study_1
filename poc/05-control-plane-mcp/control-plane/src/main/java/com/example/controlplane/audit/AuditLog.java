package com.example.controlplane.audit;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 감사 로그: "누가, 언제, 어느 테넌트에, 무엇을, 결과는" 을 JSON 한 줄로 남긴다.
 * 로거 이름이 AUDIT 이라 `kubectl logs ... | grep '"audit"'` 로 따로 뽑을 수 있다.
 * PoC 라 표준 출력에만 쓴다. 운영이면 Loki 같은 곳으로 보내고 지울 수 없게 보관한다 (README 결정 표).
 */
@Component
public class AuditLog {

    private static final Logger log = LoggerFactory.getLogger("AUDIT");

    public void record(String actor, String action, String tenant, String target, String result, String detail) {
        Map<String, String> e = new LinkedHashMap<>();
        e.put("audit", "control-plane");
        e.put("ts", Instant.now().toString());
        e.put("actor", actor);
        e.put("action", action);
        e.put("tenant", tenant);
        e.put("target", target);
        e.put("result", result);
        e.put("detail", detail == null ? "" : detail);
        log.info(toJson(e));
    }

    private static String toJson(Map<String, String> m) {
        return m.entrySet().stream()
                .map(x -> "\"" + x.getKey() + "\":\"" + escape(x.getValue()) + "\"")
                .collect(Collectors.joining(",", "{", "}"));
    }

    private static String escape(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n");
    }
}
