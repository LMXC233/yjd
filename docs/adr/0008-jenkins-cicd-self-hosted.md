# CI/CD 采用自建 Jenkins（WSL）+ 生产机 registry:2（SSH 隧道）

push 到 GitHub main 后由 WSL 内自建 Jenkins 轮询触发（Poll SCM，≤2 分钟；WSL 无公网入口，webhook 为换轨项）→ `mvn verify`（Testcontainers 真实依赖）→ 镜像构建（tag=git 短 SHA）→ **部署 A**：微服务栈 compose 部署到 WSL 本地（镜像同机，零传输）→ **部署 B**：单体镜像经 SSH 隧道 push 到生产机 registry:2 容器（仅绑定 `127.0.0.1:5000`，零公网暴露、无证书密码管理面），生产侧 `ssh compose pull` 走本机 loopback 秒级部署；回滚=切旧 tag 本地 pull。凭据（GitHub 拉取、生产 SSH 私钥）全部进 Jenkins credentials，仓库零密钥。

被拒候选：**GitHub Actions + GHCR**（托管服务违背 ADR-0002 自主可控，且系未经显式拍板的打包默认——此失误催生了 README"具名选型显式拍板"协作纪律）；**docker save+scp 直传**（无版本化回滚，推拉耦合）；**WSL 自建 Harbor**（需公网入口，复杂度留给 v2 多机场景）；**registry 公网暴露 TLS+htpasswd**（多一套证书/密码攻击面，隧道形态严格优于它）。换轨条件：v2 多机/K8s 时 registry 升级 Harbor 并加公网 TLS，流水线结构不变。
