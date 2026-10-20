package com.example.controlplane;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * application.yml 의 faas.* 값. 클러스터마다 다른 값(레지스트리 주소, namespace 이름)을 코드 밖으로 뺀다.
 *
 * @param buildNamespace 빌드 Job 이 뜨는 namespace. 테넌트 namespace 가 아니라 따로 둔다 (README 결정 2)
 * @param registryPush   빌드 Job(클러스터 안)이 이미지를 올릴 주소
 * @param registryPull   노드(kubelet)가 이미지를 받을 주소. kind 에서는 push 와 이름이 다르다 (README 1.4)
 * @param tenantLabel    "이 namespace 는 테넌트다" 표시 라벨 키. 3단계 tenant 차트가 tenant=<namespace 이름> 을 붙인다.
 *                       라벨 값이 namespace 이름과 같은 곳에만 배포한다
 * @param buildTimeout   빌드를 기다리는 최대 시간. 넘으면 실패 처리
 * @param maxCodeBytes   함수 코드 최대 크기. ConfigMap 한 개 한도(1MiB)보다 작게
 */
@ConfigurationProperties(prefix = "faas")
public record FaasProperties(
        String buildNamespace,
        String registryPush,
        String registryPull,
        String tenantLabel,
        Duration buildTimeout,
        int maxCodeBytes) {
}
