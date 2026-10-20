package com.example.controlplane;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

// 시작점. @ConfigurationPropertiesScan = FaasProperties 처럼 application.yml 값을 담는 레코드를 찾아서 채워 준다
@SpringBootApplication
@ConfigurationPropertiesScan
public class ControlPlaneApplication {
    public static void main(String[] args) {
        SpringApplication.run(ControlPlaneApplication.class, args);
    }
}
