# solution: 4단계 정답본

- 원래 자리(`poc/04-faas-runtime/` 아래)와 **폴더 구조가 같다**. 같은 경로 파일끼리 비교:
  `diff -r poc/04-faas-runtime/build poc/04-faas-runtime/solution/build`
- 쓰는 때: 한 파일에 30분 넘게 막혔을 때, 또는 다 채운 뒤 비교할 때.
- 막혀서 쓸 땐 그 파일만 원래 자리에 복사한다. 예: `cp poc/04-faas-runtime/solution/build/kaniko-job.yaml poc/04-faas-runtime/build/`
- 스크립트(`scripts/`)와 Argo CD Application 은 **원래 자리**를 읽는다. solution 파일을 그대로 apply 해도 동작은 같지만, Argo CD 는 `functions/ksvc/` 를 본다.
- 결정 값(build requests 500m/512Mi·limits 2/2Gi, max-scale 5, target 10, overhead 50m/64Mi, backoffLimit 0)은 "하나의 답"일 뿐. 다르게 골랐으면 이유와 측정값으로 설명하면 된다.

검증 (2026-10-20, Claude 컨테이너: kind v0.33.0, kindest/node v1.37.0, kindnet, CPU 4)
- 됨: kind-config (disableDefaultCNI 만 false 로) → 노드 4개, taint 2개 / setup.sh 전체 / config-features-patch / RuntimeClass apply / kaniko-job 으로 build.sh 성공(build 노드) / hello-runc ksvc 0↔N, exec 노드 / coldstart.sh·latency.sh·build-noise.sh 실행
- 【미검증】 gVisor Pod 실행 (컨테이너 환경 제약, README 9절 보충), Argo CD Application (Argo CD 이미지가 그 환경에서 안 받아짐 → YAML 만 1단계와 대조), Cilium 위에서의 동작
- 검증용으로만 바꾼 것 (Jeong 맥에선 필요 없음): 노드가 인터넷이 없어 이미지를 미리 넣음, Kourier 의 IPv6 주소 `::` → `0.0.0.0` (그 커널에 IPv6 없음), Kaniko `--registry-mirror`
