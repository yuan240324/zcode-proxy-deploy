# zcode-proxy-deploy

ZCode Proxy 的部署封装 —— 把智谱 **Z.AI / Bigmodel** 的编码套餐额度，在本机变成标准的 **OpenAI / Anthropic / Responses** 三种接口，供 Claude Code、Codex CLI、Cherry Studio、Cline 等工具使用。

> **本项目是部署封装，不是原作者。**
> 核心代码来自 [TriDefender/zcode-api](https://github.com/TriDefender/zcode-api)（MIT License）。
> 本仓库在源码基础上增加了：Windows 一键启动/停止脚本、安全基线配置模板、部署说明。
> 原项目 README 见 [`README-upstream.md`](README-upstream.md)。

---

## 与原项目的差异

本仓库基于上游 `master` 分支（v4.6.5），做了以下调整：

| 调整 | 原因 |
|---|---|
| **移除 Android 端**（`Android-APP/`、构建脚本、相关文档） | 含 178MB 二进制库（`libnode.so` 57MB 超出 GitHub 限制），且部署场景用不到 |
| **移除 `.github/workflows/`** | CI/Release 工作流针对上游发布流程，fork 后无意义 |
| **新增 `config.yaml.example`** | 已应用安全基线的脱敏配置模板 |
| **新增 PowerShell 脚本** | Windows 下的一键启动/停止/前台调试 |
| **新增 `README.md` / `使用说明.md`** | 中文部署文档 |

> 核心转发逻辑、验证码求解器、请求签名实现**完全保留上游原样**，未做任何改动。

---

## 它能做什么

- **一个地址三种协议**：`127.0.0.1:8080` 同时提供 OpenAI、Anthropic、Responses 接口
- **套餐额度复用**：把你已购买的 Coding Plan / 体验套餐额度接到任意 AI 编程工具
- **自动过验证码**：内置阿里云无痕验证求解器（纯进程内，无需浏览器）
- **请求签名**：复刻官方客户端的 Ed25519 签名协议

## 环境要求

| 组件 | 版本 | 说明 |
|---|---|---|
| [Bun](https://bun.sh) | 1.4+ | 运行时（必需） |
| Node.js | 18+ | 可选，部分验证码路径需要 |
| 系统 | Windows / macOS / Linux | 附带脚本以 Windows PowerShell 为主 |

## 快速开始

### 1. 安装 Bun

```powershell
# 官方脚本
powershell -c "irm bun.sh/install.ps1 | iex"
```

国内网络环境可直接从镜像下载解压（`bun-windows-x64.zip`）：

```
https://registry.npmmirror.com/-/binary/bun/
```

### 2. 安装依赖

```powershell
bun install
```

### 3. 准备配置

```powershell
Copy-Item config.yaml.example config.yaml
```

**必须修改 `config.yaml` 中这两项：**

```yaml
server:
  host: "127.0.0.1"                          # 不要用 0.0.0.0

auth:
  proxyApiKey: "<换成你自己的高强度随机密钥>"     # 不要用示例值
```

生成随机密钥：

```powershell
-join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })
```

### 4. 登录账号

```powershell
# bigmodel（国内智谱）
bun run src/index.ts auth login bigmodel

# zai（国际版）
bun run src/index.ts auth login zai
```

> **换账号提示**：浏览器会复用现有登录态，直接登录会登到同一个号上。
> 请用**无痕窗口**打开授权链接，或在浏览器里先退出登录。

### 5. 启动服务

```powershell
bun run src/index.ts serve
```

成功输出：

```
zcode-proxy listening on http://127.0.0.1:8080
  provider: bigmodel
  plan: start-plan
  models: 11 available
```

## 接入客户端

### Claude Code

```powershell
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8080"
$env:ANTHROPIC_AUTH_TOKEN = "<你的 proxyApiKey>"
claude
```

### OpenAI 兼容工具

| 配置项 | 值 |
|---|---|
| Base URL | `http://127.0.0.1:8080/v1` |
| API Key | `<你的 proxyApiKey>` |
| Model | `glm-5.3-flash` |

适用于 Cherry Studio、Cline、Kilo Code、LobeChat、Silly Tavern 等。

## 可用端点

| 端点 | 协议 |
|---|---|
| `POST /v1/chat/completions` | OpenAI Chat |
| `POST /v1/messages` | Anthropic Messages |
| `POST /v1/responses` | OpenAI Responses（Codex CLI） |
| `POST /async/v1/messages` | Anthropic 异步（闲时通道） |
| `GET /v1/models` | 模型列表 |
| `GET /health` | 健康检查 |
| `GET /quota` | 实时额度快照 |

## 模型说明

`/v1/models` 返回 11 个模型，但**实际可用取决于你账号的套餐**。

实测（体验套餐账号）可用的只有两个：

| 模型 ID | 上下文 | 说明 |
|---|---|---|
| `glm-5.3` | 1M | 复杂推理 |
| `glm-5.3-flash` | 1M | 快速任务，额度更多 |

其余模型（`glm-4.6`、`glm-5.2`、`glm-4.5-air` 等）会返回 502 `exceed quota limit`。

> **注意**：`config.yaml` 的 `defaultModel` 要设成你有额度的模型，
> 否则客户端不指定模型时会默认走 `glm-4.6` 并失败。

## Windows 脚本

| 脚本 | 用途 |
|---|---|
| `启动服务.ps1` | 后台静默启动（无窗口常驻），自动检查环境/登录/端口 |
| `停止服务.ps1` | 停止服务并清理残留进程 |
| `start.ps1` | 前台启动，可看实时请求日志（调试用） |

创建桌面快捷方式：

```powershell
$root = $PWD
$ws = New-Object -ComObject WScript.Shell
foreach ($n in '启动服务','停止服务') {
  $sc = $ws.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\ZCode-$n.lnk")
  $sc.TargetPath = 'powershell.exe'
  $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$root\$n.ps1`""
  $sc.WorkingDirectory = $root
  $sc.Save()
}
```

## 常用命令

```powershell
bun run src/index.ts auth status      # 查看登录状态
bun run src/index.ts quota            # 查看额度
bun run src/index.ts auth logout      # 退出登录
bun run src/index.ts claim list       # 查看可领套餐
bun run src/index.ts serve debug      # 带详细日志启动
```

## 安全基线

本项目配置模板已按以下基线加固，**建议保持**：

```yaml
server:
  host: "127.0.0.1"        # 仅本机可访问
auth:
  proxyApiKey: "<随机密钥>"  # 不使用示例值
claim:
  enabled: false           # 关闭自动领取套餐
  auto: false
```

### 已知风险

1. **账号风险**：官方用户协议规定套餐限受支持工具使用，非官方方式接入可被限制、暂停或封禁。
   - 付费 Coding Plan 用户目前报告风险较低
   - **start-plan（体验套餐）用户已有封号、封 IP 的实际案例**
2. **不要开中转站**，不要多号轮换（原作者明确建议"仅限自用"）
3. **不要**把 `host` 改为 `0.0.0.0`，会暴露到局域网/公网
4. **凭据加密密钥可推导**：默认密钥是 `SHA-256(homedir + platform + arch)`，
   无法防御同一用户权限下的其他进程。跨机迁移请设置 `ZCODE_PROXY_CREDENTIAL_SECRET`
5. **退出登录只删本地文件**，不撤销服务端授权。凭据泄露请到官网管理入口撤销

## 额度机制

- 体验套餐额度会**过期**，`/quota` 返回的 `expiresAt` 字段可查看
- 用完需到官网领取或充值
- `claim list` 可查当前是否有限时活动套餐

## License

核心代码版权归 [TriDefender/zcode-api](https://github.com/TriDefender/zcode-api) 所有，遵循 **MIT License**。
本仓库的部署脚本与文档同样以 MIT License 发布。

## 免责声明

仅供学习、研究和个人使用。使用者需自行承担账号风险与合规责任。
请勿用于违反服务条款、法律法规或平台规则的场景。
