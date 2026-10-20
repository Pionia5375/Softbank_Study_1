package com.example.controlplane.api;

import io.fabric8.kubernetes.client.KubernetesClientException;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 예외를 사람이 읽을 수 있는 JSON 으로 바꾼다 (Claude 작성, 완성본).
 * 템플릿 빈칸, RBAC 403 같은 원인이 curl 응답에 바로 보이게 하려는 것. 운영이면 내부 메시지는 숨긴다.
 */
@RestControllerAdvice
public class ApiErrors {

    private static final Logger log = LoggerFactory.getLogger(ApiErrors.class);

    // 템플릿 빈칸, digest 못 찾음 같은 "설정이 틀렸다"
    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, String>> misconfigured(IllegalStateException e) {
        log.warn("설정 오류", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of("error", e.getMessage()));
    }

    // 쿠버네티스 API 가 거절함. 403 이면 ServiceAccount 권한(rbac.yaml)을 볼 것
    @ExceptionHandler(KubernetesClientException.class)
    public ResponseEntity<Map<String, String>> kubernetes(KubernetesClientException e) {
        log.warn("쿠버네티스 API 오류 code={}", e.getCode(), e);
        HttpStatus status = e.getCode() == 403 ? HttpStatus.BAD_GATEWAY : HttpStatus.INTERNAL_SERVER_ERROR;
        return ResponseEntity.status(status).body(Map.of(
                "error", "kubernetes API " + e.getCode(),
                "detail", String.valueOf(e.getStatus() == null ? e.getMessage() : e.getStatus().getMessage())));
    }
}
