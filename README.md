# 悦家到（yjd）

互联网+家政 O2O 双边平台：家庭客户在线下单，个人服务者与家政公司在线履约。标准品（日常保洁/小时工/深度保洁）与非标品（月嫂/育儿嫂/住家保姆/养老护理）两族品类均在规划内，业务功能按需求逐个实现。四端：用户端/阿姨端/中介端/运营端。

## 开发者画像与硬约束（会话定档，必须遵守）

以下约束不体现在任何 ADR 中，但是**所有技术决策的前提**，任何后续会话/agent 不得违背或擅自放宽：

- **个人全栈 solo 开发**：后端 **Java 21 LTS**（Spring Boot 3.5.x + Spring Cloud 2025.0.x + Spring Cloud Alibaba 2023.0.3.3，虚拟线程可用；具体小版本实现时以官方版本矩阵查证为准），前端 Vue3；仅网页前端，无小程序/App（有意偏离行业主流入口，换轨点：获客受阻时小程序优先补）；无时间压力
- **项目双重目标**：做真实可演示的项目 + 刻意练习分布式系统能力。"架构重"是特性不是缺陷——复杂度的相当部分是为学习目标支付的，业务量级本身并不需要
- **自主可控**：拒绝云托管服务（RDS/MSE 等），MySQL/Redis/RocketMQ/Nacos 等中间件全量自建（ADR-0002）
- **CI/CD（ADR-0008）**：自建 Jenkins（WSL）流水线——push 后轮询触发（≤2 分钟）→ `mvn verify` → 镜像构建（tag=git SHA）→ 微服务栈部署 WSL 本地；单体镜像经 SSH 隧道 push 到生产机 registry:2（仅绑 127.0.0.1:5000，零公网暴露），生产 ssh compose pull 秒级部署/回滚；凭据全部进 Jenkins credentials
- **具名选型显式拍板（协作纪律）**：任何进入 ADR/spec/ticket 的具名工具、版本号、托管服务必须作为独立决策项经开发者确认，禁止在打包推荐中夹带未点名的选型；与 ADR-0002 冲突的托管/SaaS 默认选择自动触发提问而非默认；spec/ticket 发布前列出文中全部具名工具清单供开发者否决
- **需求驱动纪律**："一样一样来"——业务功能逐个提需求 → 小型设计轮（摆候选+推荐）→ 拍板 → 实现；**不提前实现未提出的需求，不替开发者扩大范围**
- **环境**：
  - 生产：1 台 2C2G/3M 云 VM，只跑单体演示版（ADR-0004），不承载真实流量
  - 开发+压测：8G 内存 WSL，跑完整微服务模式；压测客户端须放宿主机（同机压测数字失真）；**JDK 需从 11 升级至 Temurin 21**（Spring Boot 3 下限 17，随 Java 21 定稿升级）
  - v2：学习 K8s 后多节点重部署，正式启用 99.95% 可用性 + RPO<1min（v1 分层 SLA 见 ADR-0003）
- **量级口径**：全国档（日 4-5 万单、读峰值 2-3k QPS、写常态 30/大促 500 QPS）是**设计与压测验收口径**，不是生产流量预期
- **协作语言**：中文

## 文档地图

| 位置 | 内容 |
|---|---|
| `docs/adr/` | 架构决策记录（每份含被拒候选与换轨条件） |
| `CONTEXT.md` | 领域术语表（canonical terms，所有产出遵守词汇表） |
| `AGENTS.md` + `docs/agents/` | agent 协作配置：issue 跟踪=GitHub Issues、triage 默认五标签、domain docs 布局 |

ADR 一览：0001 微服务+Spring Cloud Alibaba ｜ 0002 中间件全量自建 ｜ 0003 v1 Compose+分层 SLA ｜ 0004 双构建模式（微服务/单体演示） ｜ 0005 Monorepo 三模块结构 ｜ 0006 需求驱动生长（分片+雪花 ID 挂起） ｜ 0007 运营端凭证=纯 Redis 会话（JWT 挂起） ｜ 0008 CI/CD=自建 Jenkins+生产 registry（SSH 隧道）

## 当前状态（2026-09-29 快照）

架构设计完成并收束；登录设计经 logic prototype 验证后**语义完全定稿**；产品代码未开始（仓库尚无 commit）。

**唯一激活的需求：运营登录**（设计完全定稿：ADR-0007 + 原型验证后的语义定稿，待明示开工）：

- 仅运营端登录；账号由 Flyway 种子创建（手机号 `13800000000` + BCrypt 初始密码），无自助注册；认证 = 手机号+密码（BCrypt 因子 10）
- 凭证（ADR-0007）：**纯 Redis 会话，不用 JWT、无 refresh**——token = 256bit 随机串（Bearer 传递）；`auth:session:{token}`（hash：accountId/roles/loginAt/UA·IP 摘要）TTL **滑动 4 小时、不设绝对上限**（运营者主动选择）；**每次校验通过即续满 4h（含 GET /me）**；UA·IP 摘要仅记录，不参与校验
- **单会话语义**：同一账号全局仅一个活跃会话，新登录自动踢旧会话（旧 token 下一请求即 401）；运营手动踢人归后期员工管理需求；登出 = DEL session，立即生效
- **封号**：DB 层禁用（status）+ 扫反向索引 `auth:sessions:{accountId}` 批量 DEL——Redis 无 token 可验、MySQL 无法登录，双路封死；**会话校验路径不查 DB**（纯 Redis，校验快路径只依赖 Redis）
- **失败计数与锁定**：按 **phone 维度滑动窗口**（只统计最近 10 分钟内的失败）；≥5 次上锁 30 分钟；登录成功计数清零；锁到期自动解除并从零重新计数；锁定期内继续尝试**不重置计时、不计数**
- **分层提示（防枚举与体验的解法）**：第 1~4 次失败与禁用账号 → 统一 `401 AUTH_INVALID`「手机号或密码错误」；触发锁的当下及整个锁定期 → `401 ACCOUNT_LOCKED + retryAfter`（秒）。关键前提：计数按手机号维度且**不查 DB**——不存在的手机号同样计数、同样上锁、同样收到 ACCOUNT_LOCKED → 锁定提示对存在/不存在的手机号表现完全一致，零枚举价值
- **登录处理顺序**：fail-close 检查 → 查锁（phone 维度）→ 账号存在且状态 → BCrypt 验密 → 失败（含查无此账号）INCR 计数，≥5 上锁；禁用账号返回统一 AUTH_INVALID 且不计数。换轨条件：自动化撞库（锁了换 IP 继续打）出现时再上验证码/IP 维度限流
- API：`/api/v1/auth` 下 login / logout / me（读网关透传 `X-User-Id`/`X-User-Roles`）；会话校验 filter 在 yjd-common，gateway 与 monolith 各自挂载（单体模式无网关，monolith 自己校验）
- 表（auth_db，自增主键）：`account(id, phone UNIQUE, password_hash, status, ...)`；`account_role(id, account_id, role, ...)`，role ∈ CUSTOMER/PROVIDER_INDIVIDUAL/AGENCY/OPERATOR
- 原型：`prototypes/auth-login-prototype.html`（v2 会话版，单文件双击即开；`AuthModel` 为可搬运纯逻辑模块，语义即本清单，实现时折进 yjd-auth-service）
- 增量：Maven 7 模块（parent / yjd-common / yjd-gateway / yjd-auth-api / yjd-auth-service[无主类] / yjd-auth-boot / yjd-monolith）+ `frontend/apps/admin-web`（axios 401 拦截清态跳登录）+ 双模式 Compose（WSL：MySQL+Redis+Nacos+gateway+auth；prod：monolith+MySQL+Redis，无 Nacos；RocketMQ 暂不进栈）+ Jenkins@WSL 流水线（ADR-0008：轮询触发→verify→build→WSL 部署；单体经 SSH 隧道 push 生产 registry:2 后 ssh compose pull）；审计日志埋 login/logout/踢人；密码不进日志
- 构建顺序（步步带验收）：Maven 骨架 → common+会话组件单测 → auth 域（curl 登录通）→ gateway（会话校验/限流/TraceId）→ monolith 直连同流程（**双模式等价性首验**）→ admin-web → 两套 compose → Jenkins 流水线

**挂起池**（开发者提出需求才激活，勿主动推进）：JWT/双 token 凭证（等用户端登录或 SSO 集成需求，届时重开设计轮）、验证码/IP 维度限流（激活条件：自动化撞库出现）、员工管理与手动踢人/HRM、下单与分布式事务（参考方案已备：RocketMQ 事务消息+幂等+对账）、派单调度（标品指派/抢单、非标品撮合面试）、缓存与读路径、三证资质审核、非标品撮合流程、8 服务拆分蓝图（仅参考）、ShardingSphere 分片+雪花 ID（等大表结构稳定）、短信/微信登录通道（等企业资质）、客户/阿姨/中介登录与注册、第二批服务（review/message/search）、Dubbo3 换轨评估、K8s（v2）、小程序端
