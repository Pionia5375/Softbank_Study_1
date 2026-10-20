package com.example.controlplane;

import io.fabric8.kubernetes.client.KubernetesClient;
import io.fabric8.kubernetes.client.KubernetesClientBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class KubernetesConfig {

    // 클라이언트(fabric8 autoConfigure)는 설정을 이 순서로 찾는다:
    //   1) kubeconfig 파일: $KUBECONFIG 또는 ~/.kube/config 의 현재 컨텍스트 (맥에서 돌리면 = kind-faas 관리자 권한)
    //   2) 없으면 파드 안의 /var/run/secrets/kubernetes.io/serviceaccount 토큰 (= ServiceAccount 권한)
    //   3) 그다음 시스템 프로퍼티·환경 변수(kubernetes.master 등)
    // 클러스터 안 파드에는 kubeconfig 파일이 없으니 2) 로 간다. 그래서 같은 jar 가 맥(개발)과 클러스터 안(운영) 둘 다에서 돈다. 권한만 다르다.
    // 문서: https://github.com/fabric8io/kubernetes-client/blob/main/doc/CHEATSHEET.md#initializing-kubernetes-client
    @Bean(destroyMethod = "close")
    public KubernetesClient kubernetesClient() {
        return new KubernetesClientBuilder().build();
    }
}
