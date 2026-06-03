# mail-cj

[![GitHub](https://img.shields.io/badge/GitHub-chenchaotao666%2Fmail--cj-blue)](https://github.com/chenchaotao666/mail-cj)

基于仓颉（Cangjie）编程语言实现的邮件发送库（当前支持 SMTP），API 设计对标 Jakarta Mail，通过 openHiTLS 提供原生 TLS/SSL 支持。

## 特性

- **完整 MIME 支持**：纯文本、HTML、附件、内嵌图片、multipart/alternative
- **TLS/SSL 加密**：基于 openHiTLS，支持 SMTPS（465）和 STARTTLS（587）
- **多认证机制**：LOGIN、PLAIN、XOAUTH2、NTLM、DIGEST-MD5
- **SMTP 扩展**：DSN 投递通知、PIPELINING、8BITMIME、SMTPUTF8
- **事件监听**：TransportListener、ConnectionListener
- **Jakarta Mail 兼容**：API 设计高度对标，迁移成本低

## 环境要求

- 仓颉编译器 1.0.4+
- openHiTLS（[安装指南](https://gitee.com/openHiTLS/openHiTLS)）
- Linux x86_64

## 安装

### 1. 安装 openHiTLS

参考 [openHiTLS 官方文档](https://gitee.com/openHiTLS/openHiTLS) 编译安装，默认安装到 `~/.local`。

### 2. 配置运行时库路径

添加到 `~/.bashrc` 或 `~/.zshrc` 永久生效：

```bash
export LD_LIBRARY_PATH=$HOME/.local/lib/hitls:$LD_LIBRARY_PATH
```

> 这一步让系统在**运行时**能找到 `.so` 动态库文件。

### 3. 克隆并构建

```bash
git clone git@github.com:chenchaotao666/mail-cj.git
cd mail-cj
./build.sh   # 自动检测 HiTLS 路径并构建库
```

脚本会自动将检测到的路径写入 `cjpm.toml`，无需手动编辑。

> **手动构建说明：** `cjpm build` 在**编译时**需要 `cjpm.toml` 的 `[ffi.c]` 指定链接库路径，与运行时的 `LD_LIBRARY_PATH` 是两个独立配置，两者缺一不可。如需手动配置，将 `examples/cjpm.toml.example` 复制为 `cjpm.toml` 并将 `/path/to/your/hitls/lib` 改为实际绝对路径（不支持 `~`）。

## 快速开始

```cangjie
import std.collection.*
import mail.core.*
import mail.internet.*
import mail.tls.*

let props = HashMap<String, String>()
props["mail.smtps.host"] = "smtp.qq.com"
props["mail.smtps.port"] = "465"
props["mail.smtps.auth"] = "true"
props["mail.smtps.ssl.checkserveridentity"] = "false"

let session = Session.getInstance(props)

let msg = MimeMessage(session)
msg.setFrom(InternetAddress("sender@qq.com", "发件人"))
msg.setRecipients(RecipientType.TO, InternetAddress.parse("recipient@example.com"))
msg.setSubject("Hello from mail-cj", "UTF-8")
msg.setText("这是邮件正文。", "UTF-8")

let t = TlsSMTPTransport(session, true)
try {
    t.connect("smtp.qq.com", 465, "sender@qq.com", "授权码")
    t.sendMessage(msg, msg.getAllRecipients())
} finally {
    t.close()
}
```

> **API 完整文档** → [`docs/feature_api.md`](docs/feature_api.md)

## 示例程序

`examples/` 目录包含 16 个场景，与 `angus-examples/`（Jakarta Mail 实现）一一对标。

```bash
cd examples
cp .env.example .env
# 编辑 .env 填写 SMTP 配置

cjpm run --run-args="--01"   # 纯文本邮件
cjpm run --run-args="--02"   # HTML 邮件
cjpm run --run-args="--03"   # 带附件邮件
cjpm run --run-args="--04"   # HTML + 内嵌图片
cjpm run --run-args="--05"   # 复杂邮件（HTML + 图片 + 附件）
cjpm run --run-args="--06"   # 多收件人（TO / CC / BCC）
cjpm run --run-args="--07"   # STARTTLS（587 端口）
cjpm run --run-args="--08"   # Reply-To 与 reply() 回复
cjpm run --run-args="--09"   # 群发（单连接）
cjpm run --run-args="--10"   # 自定义邮件头 + Sender 代发
cjpm run --run-args="--11"   # multipart/alternative 文本/HTML 兼容
cjpm run --run-args="--12"   # 从 InputStream 加载模板
cjpm run --run-args="--13"   # SMTPMessage 信封 From + DSN 通知
cjpm run --run-args="--14"   # TransportListener + ConnectionListener
cjpm run --run-args="--15"   # 长连接保活（心跳 NOOP）
cjpm run --run-args="--16"   # XOAUTH2 OAuth2 认证
```

`.env` 必填配置项：

| 变量 | 说明 | 示例 |
|------|------|------|
| `SMTP_HOST` | SMTP 服务器 | `smtp.qq.com` |
| `SMTP_PORT` | SMTP 端口 | `465` |
| `SMTP_USER` | 账户名（邮箱地址） | `user@qq.com` |
| `SMTP_PASSWORD` | 授权码（非登录密码） | `xxxxxxxx` |
| `MAIL_FROM` | 发件人地址 | `user@qq.com` |
| `MAIL_TO` | 收件人地址 | `recipient@example.com` |

## 测试

```bash
cjpm test
# TOTAL: 38, PASSED: 38
```

## 项目结构

```
mail-cj/
├── src/
│   ├── core/           # Session、Message、Transport、Address、事件、异常
│   ├── internet/       # MimeMessage、MimeMultipart、MimeBodyPart、InternetAddress
│   ├── smtp/           # SMTPTransport、SMTP 异常
│   ├── tls/            # TlsSocket、TlsConfig、TlsSMTPTransport、openHiTLS FFI
│   ├── activation/     # DataHandler、FileDataSource、ByteArrayDataSource
│   ├── util/           # Base64Util、CryptoUtil、认证机制
│   └── test/           # 单元测试
├── examples/           # 16 个发送场景示例（仓颉）
├── angus-examples/     # 对标的 Jakarta Mail 实现（Java）
└── docs/
    ├── feature_api.md  # API 参考文档
    └── angus_gap_analysis.md       # 与angus能力对比文档
```

## 相关链接

- [仓颉编程语言](https://developer.huawei.com/consumer/cn/cangjie/)
- [openHiTLS](https://gitee.com/openHiTLS/openHiTLS)
- [Jakarta Mail](https://eclipse-ee4j.github.io/mail/)

## 许可证

MIT License
