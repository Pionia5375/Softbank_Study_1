package com.example.controlplane.deploy;

import io.fabric8.kubernetes.client.KubernetesClient;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

/**
 * resources/templates/*.yaml (Jeong 이 쓴 매니페스트) 를 읽어서 ${KEY} 를 값으로 바꾸고 자바 객체로 만든다.
 *
 * 왜 자바 코드로 Job 을 조립하지 않고 YAML 템플릿을 쓰나:
 *   - 매니페스트는 kubectl apply 로 따로 시험해 볼 수 있다 (자바 없이)
 *   - 리뷰하는 사람이 자바를 몰라도 무엇이 클러스터에 들어가는지 바로 읽는다
 * 넣는 값은 이름·namespace·이미지 주소뿐이고 전부 정규식 검사를 통과한 값이다.
 * 사용자 코드는 절대 템플릿 문자열에 넣지 않는다 (YAML 주입 방지). 코드는 ConfigMap 객체로 따로 넣는다.
 */
@Component
public class ManifestRenderer {

    private static final Pattern PLACEHOLDER = Pattern.compile("\\$\\{([A-Z_]+)}");

    private final KubernetesClient k8s;

    public ManifestRenderer(KubernetesClient k8s) {
        this.k8s = k8s;
    }

    public <T> T render(String templateName, Map<String, String> vars, Class<T> type) {
        String yaml = fill(read(templateName), vars, templateName);
        return k8s.getKubernetesSerialization().unmarshal(yaml, type);
    }

    static String fill(String template, Map<String, String> vars, String templateName) {
        // 주석(#) 줄은 빼고, 아직 안 채운 빈칸이 있으면 바로 알려 준다
        template.lines()
                .filter(line -> !line.strip().startsWith("#") && line.contains("___"))
                .findFirst()
                .ifPresent(line -> {
                    throw new IllegalStateException(templateName + " 에 아직 채우지 않은 빈칸이 있다: " + line.strip());
                });
        Matcher m = PLACEHOLDER.matcher(template);
        StringBuilder out = new StringBuilder();
        while (m.find()) {
            String value = vars.get(m.group(1));
            if (value == null) {
                throw new IllegalStateException(templateName + " 의 ${" + m.group(1) + "} 에 넣을 값이 없다. 쓸 수 있는 키: " + vars.keySet());
            }
            m.appendReplacement(out, Matcher.quoteReplacement(value));
        }
        m.appendTail(out);
        return out.toString();
    }

    String read(String templateName) {
        try (InputStream in = new ClassPathResource("templates/" + templateName).getInputStream()) {
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new IllegalStateException("템플릿을 못 읽었다: " + templateName, e);
        }
    }

    public String readRuntimeFile(String path) {
        try (InputStream in = new ClassPathResource("runtime/" + path).getInputStream()) {
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new IllegalStateException("런타임 파일을 못 읽었다: " + path, e);
        }
    }
}
