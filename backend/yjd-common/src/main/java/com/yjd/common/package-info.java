/**
 * 跨服务共享库根包：统一响应 R&lt;T&gt;/异常码/会话校验 filter/TraceId 工具随 ticket 增量填充。
 * 刻意保持零 web 栈依赖：消费方含 WebFlux 网关，servlet starter 会污染其 classpath。
 */
package com.yjd.common;
