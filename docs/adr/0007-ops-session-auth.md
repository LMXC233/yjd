# 运营端凭证采用服务端会话（opaque token + Redis），不用 JWT

运营端（高权限、低频、单验证方）的核心要求是"撤销立即生效"：纯无状态 JWT 做不到；JWT+会话白名单虽可达成，但引入密钥管理、JWT exp 与 session TTL 双时钟同步、access+refresh 双 token 三重复杂度，而在"网关/单体透传身份头、fail-close"的既定架构下无对价收益。

我们决定：运营端凭证 = 256bit 随机串（Bearer 传递），`auth:session:{token}`（hash：accountId/roles/loginAt/UA·IP 摘要）TTL 滑动 4 小时，**不设绝对上限**——运营者明确选择不为活跃会话设强制重登，安全兜底由"登出/踢人经 DEL 下一请求即 401"承担。反向索引 `auth:sessions:{accountId}`（SET）支持踢单设备与封号全踢（扫索引批量 DEL）。Redis 故障时 fail-close（全部 401，安全优先）。被拒候选：纯无状态 JWT（不可撤销）、JWT+会话白名单（三重复杂度无兑现点）、token_version/epoch（有反向索引可枚举会话，用不上）、双 token/refresh（为"不可续期的 access"而生，纯会话的滑动续期天然覆盖）。JWT 挂起，至用户端登录或 SSO 集成需求出现时重开设计轮。

**细化定稿（2026-09-29，logic prototype 验证后逐条拍板；完整语义快照见 README「运营登录」节）**：单会话语义——同一账号全局仅一个活跃会话，新登录自动踢旧会话；每次校验通过即续满 4h（含 GET /me）；UA·IP 摘要仅记录不参与校验。封号 = DB 禁用 + 扫索引全删，会话校验路径不查 DB。失败计数按 phone 维度滑动窗口（10 分钟 5 次锁 30 分钟；锁内不重置计时；成功清零、到期从零计）。错误提示分层：1~4 次失败与禁用账号统一 `AUTH_INVALID`（防枚举主战场）；锁定态返回 `ACCOUNT_LOCKED + retryAfter`——因计数不查 DB，不存在的手机号同样计数上锁，锁定提示对账号存在与否表现一致，零枚举价值。换轨条件：自动化撞库出现时再上验证码/IP 维度限流。
