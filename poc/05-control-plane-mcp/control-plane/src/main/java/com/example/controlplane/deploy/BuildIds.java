package com.example.controlplane.deploy;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * 빌드 ID = 함수 이름 + 코드 해시 앞 10자. 예: hello-3f2a9c01be
 * 같은 테넌트·같은 이름·같은 코드면 항상 같은 ID → 같은 Job 이름 → 두 번 눌러도 빌드는 한 번 (멱등성).
 */
public final class BuildIds {

    private BuildIds() {
    }

    public static String of(String tenant, String name, String code) {
        try {
            MessageDigest sha = MessageDigest.getInstance("SHA-256");
            byte[] hash = sha.digest((tenant + "\n" + name + "\n" + code).getBytes(StandardCharsets.UTF_8));
            return name + "-" + HexFormat.of().formatHex(hash).substring(0, 10);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
