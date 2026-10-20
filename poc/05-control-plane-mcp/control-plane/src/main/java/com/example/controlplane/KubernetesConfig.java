package com.example.controlplane;

import io.fabric8.kubernetes.client.KubernetesClient;
import io.fabric8.kubernetes.client.KubernetesClientBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class KubernetesConfig {

    // 클라이언트는 설정을 이 순서로 찾는다:
    //   1) 파드 안이면 /var/run/secrets/kubernetes.io/serviceaccount 의 토큰 (= ServiceAccount 권한)
    //   2) 맥에서 돌리면 ~/.kube/config 의 현재 컨텍스트 (= kind-faas 관리자 권한)
    // 그래서 같은 jar 가 맥(개발)과 클러스터 안(운영) 둘 다에서 돈다. 권한만 다르다.
    @Bean(destroyMethod = "close")
    public KubernetesClient kubernetesClient() {
        return new KubernetesClientBuilder().build();
    }
}
