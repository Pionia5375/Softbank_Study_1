package com.example.controlplane.api;

import com.example.controlplane.FaasProperties;
import com.example.controlplane.deploy.FunctionDeployer;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * 컨트롤 플레인 API 입구.
 *   POST /api/v1/tenants/{tenant}/functions        함수 배포 (Jeong 작성)
 *   GET  /api/v1/tenants/{tenant}/functions/{name} 상태 조회 (완성)
 */
@RestController
@RequestMapping("/api/v1/tenants/{tenant}/functions")
public class FunctionController {

    // 테넌트 이름 = namespace 이름. DNS 라벨 규칙 (소문자·숫자·하이픈, 63자 이하)
    static final String TENANT_PATTERN = "[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?";

    private final FunctionDeployer deployer;
    private final FaasProperties props;

    public FunctionController(FunctionDeployer deployer, FaasProperties props) {
        this.deployer = deployer;
        this.props = props;
    }

    /**
     * 함수 배포. 202 Accepted + Location 헤더(상태 조회 주소)를 돌려준다.
     * 빌드는 수십 초 걸리니 요청을 붙잡고 기다리지 않는다.
     */
    @PostMapping
    public ResponseEntity<DeployAccepted> deploy(
            @PathVariable @Pattern(regexp = TENANT_PATTERN) String tenant,
            @Valid @RequestBody DeployRequest request,
            @RequestHeader(value = "X-Actor", defaultValue = "anonymous") String actor) {
        // 1) 코드 크기 한도. ConfigMap 은 1MiB 가 한계라 그보다 작게 막는다 → 413
        if (request.code().getBytes(StandardCharsets.UTF_8).length > props.maxCodeBytes()) {
            throw new ResponseStatusException(HttpStatus.CONTENT_TOO_LARGE, "code 는 " + props.maxCodeBytes() + " 바이트 이하");
        }
        // 2) 테넌트 확인. 테넌트 라벨이 없는 namespace(kube-system 등)는 없는 것으로 친다 → 404
        if (!deployer.tenantExists(tenant)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "테넌트가 없다: " + tenant);
        }
        // 3) 빌드 시작 (Job 생성까지만 하고 바로 돌아온다)
        DeployAccepted accepted = deployer.startDeploy(tenant, request, actor);
        // 4) 202 + Location
        return ResponseEntity.accepted().location(URI.create(accepted.statusUrl())).body(accepted);
    }

    /** 상태 조회. 클라이언트는 READY 나 *_FAILED 가 나올 때까지 이걸 반복해서 부른다 */
    @GetMapping("/{name}")
    public ResponseEntity<FunctionStatus> status(
            @PathVariable @Pattern(regexp = TENANT_PATTERN) String tenant,
            @PathVariable String name) {
        FunctionStatus s = deployer.status(tenant, name);
        return "NOT_FOUND".equals(s.phase()) ? ResponseEntity.status(HttpStatus.NOT_FOUND).body(s) : ResponseEntity.ok(s);
    }
}
