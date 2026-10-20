package com.example.controlplane.api;

/** 202 Accepted 응답. 빌드는 오래 걸리니 "접수했다 + 상태는 여기서 봐라"만 바로 돌려준다. */
public record DeployAccepted(String tenant, String name, String buildId, String phase, String statusUrl) {
}
