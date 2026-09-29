package com.yjd.monolith;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * 单体模式聚合启动器。T1 占位：随 T7 起逐域装配 yjd-*-service 模块（不引微服务启动器）。
 */
@SpringBootApplication
public class MonolithApplication {

    public static void main(String[] args) {
        SpringApplication.run(MonolithApplication.class, args);
    }
}
