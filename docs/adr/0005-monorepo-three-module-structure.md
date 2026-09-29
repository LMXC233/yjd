# Monorepo 与三模块工程结构

采用单仓库（Monorepo）：backend/ 为 Maven 多模块，frontend/ 为 pnpm workspace（四端 apps + 共享 packages），deploy/ 存放双模式 Compose 编排。每个服务拆三个 Maven 模块：**xxx-api**（接口 + DTO + Feign 声明，唯一可被其他服务依赖的入口）、**xxx-service**（业务实现，内部按 controller/service/mapper/entity 分包，无主类）、**xxx-boot**（thin 启动器，独占主类与配置文件）。

三模块拆分是双构建模式（ADR-0004）的必要条件：单体启动器需要只引业务实现而不引微服务启动器——若 service 模块自带 @SpringBootApplication 与 application.yml，聚合时会出现多主类冲突与 classpath 配置打架。配套基线：Flyway 按服务管理各自 schema 的 migration；敏感配置走 .env（gitignore）+ 模板入库；trunk-based 分支；CI/CD 采用自建 Jenkins 流水线（ADR-0008）。被拒候选：多仓库（solo 下跨服务重构与历史追踪成本高）；两模块（api + 带启动器的实现，无法被单体装配）。
