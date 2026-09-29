package com.yjd.auth;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * auth 服务微服务模式启动器（thin boot，ADR-0005）。
 * 扫描范围放宽到 com.yjd 以装配 yjd-common / yjd-auth-service 中的组件。
 */
@SpringBootApplication(scanBasePackages = "com.yjd")
public class AuthBootApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuthBootApplication.class, args);
    }
}
