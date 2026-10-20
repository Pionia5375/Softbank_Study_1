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

    // TODO(human): 함수 배포 엔드포인트를 여기에 쓴다. 30분 넘게 막히면 solution/ 의 같은 파일을 본다.
    //
    // 받는 것
    //   - 경로의 {tenant}             → @PathVariable. 아래 status() 처럼 @Pattern(regexp = TENANT_PATTERN) 을 붙인다
    //   - 본문 JSON {name, code}      → @RequestBody DeployRequest. @Valid 를 붙여야 DeployRequest 의 @Pattern·@NotBlank 검사가 돈다
    //   - 헤더 X-Actor (누가 배포했나) → @RequestHeader(value = "X-Actor", defaultValue = "anonymous"). 감사 로그에 들어간다
    //
    // 할 일 (순서대로)
    //   1) 코드 크기 검사: request.code() 의 UTF-8 바이트 수가 props.maxCodeBytes() 보다 크면
    //      throw new ResponseStatusException(HttpStatus.CONTENT_TOO_LARGE, "...")      → 413
    //   2) 테넌트 검사: deployer.tenantExists(tenant) 가 false 면 HttpStatus.NOT_FOUND  → 404
    //      (kube-system 처럼 테넌트 라벨이 없는 namespace 도 여기서 막힌다)
    //   3) deployer.startDeploy(tenant, request, actor) → DeployAccepted 를 받는다 (Job 만 만들고 바로 돌아온다)
    //   4) 202 Accepted + Location 헤더(= accepted.statusUrl()) + 본문 accepted 로 응답
    //      힌트: ResponseEntity.accepted().location(URI.create(...)).body(...)
    //
    // 왜 200 이 아니라 202 인가: 빌드는 수십 초 걸린다. "받았다, 결과는 Location 에서 확인해라" 가 202 의 뜻이다
    // 다 쓰면: cd poc/05-control-plane-mcp/control-plane && ./mvnw test  → Tests run: 8, Failures: 0

    /** 상태 조회. 클라이언트는 READY 나 *_FAILED 가 나올 때까지 이걸 반복해서 부른다 */
    @GetMapping("/{name}")
    public ResponseEntity<FunctionStatus> status(
            @PathVariable @Pattern(regexp = TENANT_PATTERN) String tenant,
            @PathVariable String name) {
        FunctionStatus s = deployer.status(tenant, name);
        return "NOT_FOUND".equals(s.phase()) ? ResponseEntity.status(HttpStatus.NOT_FOUND).body(s) : ResponseEntity.ok(s);
    }
}
