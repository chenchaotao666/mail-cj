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

**编译安装（安装到 `~/.local`）：**

```bash
git clone https://gitcode.com/openhitls/openhitls.git
cd openhitls
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$HOME/.local ..
make -j$(nproc)
make install
```

安装完成后库文件位于 `~/.local/lib/`，头文件位于 `~/.local/include/`。

### 2. 克隆并构建

```bash
git clone git@github.com:chenchaotao666/mail-cj.git
cd mail-cj
./build.sh   # 自动检测 HiTLS 路径并构建库
```

脚本会自动将检测到的路径写入 `cjpm.toml`，无需手动编辑。

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

`examples/` 目录包含 16 个发送场景，与 `angus-examples/`（Jakarta Mail 实现）一一对标，详见 [examples/README.md](examples/README.md)。

## 测试

```bash
cjpm test
# TOTAL: 222, PASSED: 222
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
- [Angus Mail](https://eclipse-ee4j.github.io/angus-mail/)

## 许可证

MIT License
