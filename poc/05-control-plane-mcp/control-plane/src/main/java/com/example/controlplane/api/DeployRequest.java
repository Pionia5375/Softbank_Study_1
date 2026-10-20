package com.example.controlplane.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * POST /api/v1/tenants/{tenant}/functions 본문.
 *
 * @param name 함수 이름. 쿠버네티스 리소스 이름이 되므로 DNS 라벨 규칙(소문자·숫자·하이픈, 문자로 시작)을 따른다.
 *             30자 제한: Job 이름 "build-" + name + "-" + 해시 10자 가 63자를 넘지 않게.
 * @param code handler.py 내용. def handle(body: bytes) 가 있어야 한다.
 */
public record DeployRequest(
        @NotBlank
        @Pattern(regexp = "[a-z]([-a-z0-9]{0,28}[a-z0-9])?", message = "소문자로 시작, 소문자·숫자·하이픈, 30자 이하")
        String name,
        @NotBlank
        String code) {
}
