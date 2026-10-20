package com.example.controlplane.api;

/**
 * GET 상태 응답.
 *
 * @param phase NOT_FOUND / BUILDING / BUILD_FAILED / DEPLOYING / READY / FAILED
 * @param image 지금 서비스 중인 이미지 (digest 포함)
 * @param url   Knative 가 붙여 준 주소 (예: http://hello.tenant-a.example.com)
 */
public record FunctionStatus(
        String tenant,
        String name,
        String phase,
        String buildId,
        String image,
        String url,
        String latestReadyRevision,
        String message) {

    public static FunctionStatus notFound(String tenant, String name) {
        return new FunctionStatus(tenant, name, "NOT_FOUND", null, null, null, null, null);
    }
}
