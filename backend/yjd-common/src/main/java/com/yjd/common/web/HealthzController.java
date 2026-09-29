package com.yjd.common.web;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 存活探针端点：进程级存活，不含依赖健康检查（Redis fail-close 等语义不在此暴露）。
 */
@RestController
public class HealthzController {

    @GetMapping("/healthz")
    public Map<String, String> healthz() {
        return Map.of("status", "ok");
    }
}
