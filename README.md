# Cangjie Mail

基于仓颉(Cangjie)编程语言的邮件发送库，提供类似 Jakarta Mail 的 API 设计，支持 TLS 加密和证书验证。

## 特性

- **完整的 MIME 支持**：纯文本、HTML、附件、内嵌图片
- **TLS/SSL 加密**：基于 openHiTLS 实现安全传输
- **证书验证**：支持系统 CA 证书和自定义 CA 证书
- **多种认证方式**：LOGIN、PLAIN 认证
- **API 兼容性**：与 Jakarta Mail/Angus Mail 高度兼容
- **类型安全**：充分利用仓颉的类型系统

## 目录

- [环境要求](#环境要求)
- [安装](#安装)
  - [安装仓颉编译器](#安装仓颉编译器)
  - [安装 openHiTLS](#安装-openhitls)
- [快速开始](#快速开始)
- [API 文档](#api-文档)
- [使用示例](#使用示例)
- [证书配置](#证书配置)
- [项目结构](#项目结构)

## 环境要求

- 仓颉编译器 1.0.4+
- openHiTLS 库
- Linux x86_64 (目前支持的平台)

## 安装

### 安装仓颉编译器

请参考[仓颉官方文档](https://developer.huawei.com/consumer/cn/cangjie/)安装仓颉编译器。

确保 `cjpm` 命令可用：

```bash
cjpm --version
# 输出: Cangjie Package Manager: 1.0.4
```

### 安装 openHiTLS

openHiTLS 是华为开源的 TLS 协议栈实现，用于提供 TLS 加密支持。

#### 方式一：从源码编译

```bash
# 克隆 openHiTLS 仓库
git clone https://gitee.com/openHiTLS/openHiTLS.git
cd openHiTLS

# 编译（需要 CMake 3.16+）
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/.local
make -j$(nproc)
make install

# 验证安装
ls ~/.local/lib/hitls/
# 应该看到: libhitls_tls.so, libhitls_crypto.so 等文件
```

#### 方式二：使用预编译包

如果有预编译的 openHiTLS 包，解压到 `~/.local` 目录：

```bash
tar -xzf openhitls-linux-x64.tar.gz -C ~/.local/
```

#### 配置环境变量

```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
export LD_LIBRARY_PATH=$HOME/.local/lib/hitls:$LD_LIBRARY_PATH
```

### 构建项目

```bash
# 克隆项目
git clone <repository-url>
cd cangjie-mail

# 构建库
cjpm build

# 构建演示程序
cd demo
cjpm build
```

### 运行演示

演示程序使用 `.env` 文件管理配置，避免在代码中硬编码敏感信息。

```bash
cd demo

# 1. 复制配置模板
cp .env.example .env

# 2. 编辑 .env 填写您的 SMTP 配置
# SMTP_HOST=smtp.qq.com
# SMTP_PORT=465
# SMTP_USER=your-email@qq.com
# SMTP_PASSWORD=your-auth-code
# MAIL_FROM=your-email@qq.com
# MAIL_TO=recipient@example.com

# 3. 运行演示
cjpm run                              # 默认演示
cjpm run --run-args="--help"          # 查看帮助
cjpm run --run-args="--config"        # 查看配置
cjpm run --run-args="--demo"          # 运行演示（不发送邮件）
cjpm run --run-args="--send-simple"   # 发送简单邮件
cjpm run --run-args="--send-html"     # 发送 HTML 邮件
cjpm run --run-args="--send-attach"   # 发送带附件邮件
cjpm run --run-args="--send-complex"  # 发送复杂邮件
```

`.env` 配置文件说明：

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `SMTP_HOST` | SMTP 服务器地址 | `smtp.qq.com` |
| `SMTP_PORT` | SMTP 端口（SMTPS 通常是 465） | `465` |
| `SMTP_USER` | SMTP 用户名（通常是邮箱地址） | `user@qq.com` |
| `SMTP_PASSWORD` | SMTP 授权码（非邮箱密码） | `xxxxxxxx` |
| `MAIL_FROM` | 发件人地址 | `user@qq.com` |
| `MAIL_TO` | 收件人地址 | `recipient@example.com` |
| `MAIL_FROM_NAME` | 发件人显示名（可选） | `Cangjie Mail` |
| `VERIFY_CERT` | 是否验证证书（可选） | `true` / `false` |
| `CA_CERT_PATH` | 自定义 CA 证书路径（可选） | `/path/to/ca.crt` |
| `DEBUG` | 是否开启调试（可选） | `true` / `false` |

## 快速开始

### 发送简单邮件

```cangjie
import std.collection.*
import mail.core.*
import mail.internet.*
import mail.tls.*

main(): Int64 {
    // 配置 SMTP 服务器
    let props = HashMap<String, String>()
    props["mail.smtps.host"] = "smtp.qq.com"
    props["mail.smtps.port"] = "465"
    props["mail.smtps.auth"] = "true"

    let session = Session.getInstance(props)
    session.setDebug(true)  // 启用调试输出

    // 创建邮件
    let message = MimeMessage(session)
    message.setFrom(InternetAddress("sender@qq.com", "发件人"))
    message.setRecipients(RecipientType.TO, InternetAddress.parse("receiver@example.com"))
    message.setSubject("测试邮件")
    message.setText("这是一封测试邮件。")

    // 发送邮件
    let transport = TlsSMTPTransport(session, true)
    try {
        transport.connect("smtp.qq.com", 465, "sender@qq.com", "your-auth-code")
        transport.sendMessage(message, message.getAllRecipients())
        println("邮件发送成功！")
    } finally {
        transport.close()
    }

    0
}
```

## API 文档

### 核心类

#### Session - 会话管理

```cangjie
// 创建会话
let session = Session.getInstance(props)

// 获取默认会话（单例模式）
let session = Session.getDefaultInstance(props)

// 设置调试模式
session.setDebug(true)

// 获取属性
let host = session.getProperty("mail.smtps.host")
```

#### MimeMessage - 邮件消息

```cangjie
// 创建消息
let message = MimeMessage(session)

// 设置发件人
message.setFrom(InternetAddress("sender@example.com"))
message.setFrom(InternetAddress("sender@example.com", "显示名称"))

// 设置收件人
message.setRecipients(RecipientType.TO, InternetAddress.parse("to@example.com"))
message.setRecipients(RecipientType.CC, InternetAddress.parse("cc@example.com"))
message.setRecipients(RecipientType.BCC, InternetAddress.parse("bcc@example.com"))

// 设置主题
message.setSubject("邮件主题")

// 设置内容
message.setText("纯文本内容")
message.setHtmlContent("<h1>HTML 内容</h1>")

// 添加附件
message.addAttachment("/path/to/file.pdf")
message.addAttachments(["/path/to/file1.pdf", "/path/to/file2.doc"])

// 设置带附件的文本
message.setTextWithAttachments("正文内容", ["/path/to/attachment.pdf"])

// 设置带附件的 HTML
message.setHtmlWithAttachments("<h1>HTML</h1>", ["/path/to/attachment.pdf"])

// 设置带内嵌图片的 HTML
message.setHtmlWithInlineImages(
    "<img src='cid:logo'>",
    [("logo", "/path/to/logo.png")]
)

// 设置复杂邮件（HTML + 内嵌图片 + 附件）
message.setHtmlWithImagesAndAttachments(
    "<img src='cid:logo'>",
    [("logo", "/path/to/logo.png")],
    ["/path/to/attachment.pdf"]
)
```

#### InternetAddress - 邮件地址

```cangjie
// 创建地址
let addr = InternetAddress("user@example.com")
let addr = InternetAddress("user@example.com", "显示名称")

// 解析地址列表
let addresses = InternetAddress.parse("a@example.com, b@example.com")

// 验证地址
addr.validate()  // 无效时抛出 AddressException

// 获取信息
let email = addr.getAddress()      // "user@example.com"
let name = addr.getPersonal()      // Some("显示名称") 或 None
```

#### TlsSMTPTransport - TLS SMTP 传输

```cangjie
// 创建传输（true = 使用 SSL/TLS）
let transport = TlsSMTPTransport(session, true)

// 连接服务器
transport.connect(host, port, username, password)

// 启用证书验证
transport.setVerifyCert(true)

// 设置自定义 CA 证书
transport.setCACertPath("/path/to/ca-cert.pem")

// 发送邮件
transport.sendMessage(message, message.getAllRecipients())

// 关闭连接
transport.close()
```

#### MimeMultipart - 多部分容器

```cangjie
// 创建 multipart
let mp = MimeMultipart()                        // mixed（默认）
let mp = MimeMultipart(MULTIPART_MIXED)         // 附件
let mp = MimeMultipart(MULTIPART_ALTERNATIVE)   // 文本/HTML 选择
let mp = MimeMultipart(MULTIPART_RELATED)       // 内嵌资源

// 添加部分
mp.addBodyPart(bodyPart)

// 获取部分数量
let count = mp.getCount()

// 设置到消息
message.setContent(mp)
```

#### MimeBodyPart - 消息体部分

```cangjie
// 创建部分
let part = MimeBodyPart()

// 设置文本内容
part.setText("文本内容")
part.setHtmlContent("<h1>HTML</h1>")

// 附加文件
part.attachFile("/path/to/file.pdf")

// 设置内嵌图片的 Content-ID
part.setContentID("image-id")

// 设置 disposition
part.setDisposition(PART_INLINE)      // 内嵌
part.setDisposition(PART_ATTACHMENT)  // 附件
```

### 便捷函数

```cangjie
// 创建文本 BodyPart
let textPart = createTextBodyPart("文本内容")

// 创建 HTML BodyPart
let htmlPart = createHtmlBodyPart("<h1>HTML</h1>")

// 创建附件 BodyPart
let attachPart = createAttachmentBodyPart("/path/to/file.pdf")

// 创建内嵌图片 BodyPart
let imagePart = createInlineImageBodyPart("/path/to/image.png", "image-id")

// 创建带附件的 Multipart
let mp = createMixedMultipart("文本内容", ["/path/to/file1.pdf", "/path/to/file2.doc"])

// 创建带内嵌图片的 Multipart
let mp = createRelatedMultipart("<img src='cid:logo'>", [("logo", "/path/to/logo.png")])

// 创建文本/HTML 选择的 Multipart
let mp = createAlternativeMultipart("纯文本", "<h1>HTML</h1>")
```

### 数据源

```cangjie
// 文件数据源
let fds = FileDataSource("/path/to/file.pdf")

// 内存数据源
let bds = ByteArrayDataSource(data, "application/pdf")
let bds = ByteArrayDataSource("文本内容", "text/plain")

// 便捷创建函数
let textDs = createTextDataSource("文本内容", name: "text.txt")
let htmlDs = createHtmlDataSource("<h1>HTML</h1>", name: "content.html")
let jsonDs = createJsonDataSource("{}", name: "data.json")
let imageDs = createImageDataSource(imageBytes, "png", "image.png")
```

## 使用示例

### 发送 HTML 邮件

```cangjie
let message = MimeMessage(session)
message.setFrom(InternetAddress("sender@qq.com"))
message.setRecipients(RecipientType.TO, InternetAddress.parse("receiver@example.com"))
message.setSubject("HTML 邮件")
message.setHtmlContent("""
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .header { background-color: #4CAF50; color: white; padding: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>欢迎使用 Cangjie Mail</h1>
    </div>
    <p>这是一封 HTML 格式的邮件。</p>
</body>
</html>
""")
```

### 发送带附件的邮件

```cangjie
let message = MimeMessage(session)
message.setFrom(InternetAddress("sender@qq.com"))
message.setRecipients(RecipientType.TO, InternetAddress.parse("receiver@example.com"))
message.setSubject("带附件的邮件")
message.setTextWithAttachments(
    "请查看附件中的文档。",
    ["assets/report.pdf", "assets/data.xlsx"]
)
```

### 发送带内嵌图片的邮件

```cangjie
let message = MimeMessage(session)
message.setFrom(InternetAddress("sender@qq.com"))
message.setRecipients(RecipientType.TO, InternetAddress.parse("receiver@example.com"))
message.setSubject("带内嵌图片的邮件")
message.setHtmlWithInlineImages(
    """
    <h1>产品介绍</h1>
    <img src="cid:product-image" alt="产品图片">
    <p>这是我们的新产品。</p>
    """,
    [("product-image", "assets/product.png")]
)
```

### 发送复杂邮件（HTML + 图片 + 附件）

```cangjie
let message = MimeMessage(session)
message.setFrom(InternetAddress("sender@qq.com"))
message.setRecipients(RecipientType.TO, InternetAddress.parse("receiver@example.com"))
message.setSubject("完整功能演示")
message.setHtmlWithImagesAndAttachments(
    """
    <div style="text-align: center;">
        <img src="cid:logo" alt="Logo">
        <h1>公司报告</h1>
    </div>
    <p>请查看附件中的详细报告。</p>
    """,
    [("logo", "assets/logo.png")],
    ["assets/report.pdf", "assets/data.xlsx"]
)
```

### 手动构建 Multipart 邮件

```cangjie
let message = MimeMessage(session)
message.setFrom(InternetAddress("sender@qq.com"))
message.setRecipients(RecipientType.TO, InternetAddress.parse("receiver@example.com"))
message.setSubject("手动构建的邮件")

// 创建 multipart/mixed 容器
let multipart = MimeMultipart(MULTIPART_MIXED)

// 添加文本部分
let textPart = MimeBodyPart()
textPart.setText("这是邮件正文。")
multipart.addBodyPart(textPart)

// 添加 HTML 部分
let htmlPart = MimeBodyPart()
htmlPart.setHtmlContent("<h1>HTML 内容</h1>")
multipart.addBodyPart(htmlPart)

// 添加附件
let attachPart = MimeBodyPart()
attachPart.attachFile("assets/document.pdf")
multipart.addBodyPart(attachPart)

// 设置到消息
message.setContent(multipart)
```

## 证书配置

### TLS 验证模式

Cangjie Mail 支持三种 TLS 验证模式：

| 模式 | 说明 | 安全性 |
|------|------|--------|
| `VERIFY_NONE` | 不验证服务器证书 | 低（仅开发环境） |
| `VERIFY_PEER` | 验证服务器证书 | 高（推荐生产环境） |
| `VERIFY_REQUIRED` | 必须有证书 | 高 |

### 启用证书验证

#### 方式一：通过 Session 属性

```cangjie
let props = HashMap<String, String>()
props["mail.smtps.host"] = "smtp.qq.com"
props["mail.smtps.port"] = "465"
props["mail.smtps.auth"] = "true"
// 启用证书验证
props["mail.smtps.ssl.checkserveridentity"] = "true"
// 可选：指定 CA 证书路径
props["mail.smtps.ssl.caCert"] = "/etc/ssl/certs/ca-certificates.crt"

let session = Session.getInstance(props)
```

#### 方式二：通过 Transport 方法

```cangjie
let transport = TlsSMTPTransport(session, true)

// 启用证书验证（自动使用系统 CA 证书）
transport.setVerifyCert(true)

// 或指定自定义 CA 证书
transport.setCACertPath("/path/to/ca-cert.pem")
```

### 系统 CA 证书路径

Cangjie Mail 会自动查找以下路径的系统 CA 证书：

| 系统 | 路径 |
|------|------|
| Debian/Ubuntu | `/etc/ssl/certs/ca-certificates.crt` |
| RHEL/CentOS | `/etc/pki/tls/certs/ca-bundle.crt` |
| OpenSUSE | `/etc/ssl/ca-bundle.pem` |
| Fedora | `/etc/pki/tls/cacert.pem` |
| macOS/FreeBSD | `/etc/ssl/cert.pem` |

### 使用自签名证书

对于使用自签名证书的内部 SMTP 服务器：

```cangjie
// 方式一：将自签名 CA 添加到系统信任库
// sudo cp my-ca.crt /usr/local/share/ca-certificates/
// sudo update-ca-certificates

// 方式二：指定自定义 CA 证书路径
transport.setCACertPath("/path/to/my-ca.crt")
```

## 项目结构

```
cangjie-mail/
├── cjpm.toml                 # 项目配置
├── README.md                 # 本文档
├── src/                      # 源代码
│   ├── main.cj              # 包声明
│   ├── core/                # 核心框架
│   │   ├── session.cj       # 会话管理
│   │   ├── transport.cj     # 传输抽象
│   │   ├── message.cj       # 消息抽象
│   │   ├── address.cj       # 地址抽象
│   │   └── exceptions.cj    # 异常定义
│   ├── internet/            # Internet 邮件规范
│   │   ├── mime_message.cj      # MIME 消息
│   │   ├── internet_address.cj  # RFC 822 地址
│   │   ├── mime_multipart.cj    # 多部分容器
│   │   ├── mime_body_part.cj    # 消息体部分
│   │   └── internet_headers.cj  # 邮件头
│   ├── smtp/                # SMTP 协议
│   │   ├── smtp_transport.cj    # SMTP 传输
│   │   └── smtp_exceptions.cj   # SMTP 异常
│   ├── tls/                 # TLS 支持
│   │   ├── tls_config.cj        # TLS 配置
│   │   ├── tls_socket.cj        # TLS Socket
│   │   ├── tls_smtp_transport.cj # TLS SMTP
│   │   └── hitls_ffi.cj         # openHiTLS FFI
│   ├── activation/          # 数据激活框架
│   │   ├── data_source.cj       # 数据源接口
│   │   ├── data_handler.cj      # 数据处理器
│   │   ├── file_data_source.cj  # 文件数据源
│   │   └── byte_array_data_source.cj # 内存数据源
│   └── util/                # 工具
│       └── base64_util.cj   # Base64 编解码
└── demo/                    # 演示程序
    ├── cjpm.toml
    ├── src/
    │   └── main.cj          # 演示代码
    └── assets/              # 测试资源
        ├── test.txt         # 测试附件
        └── test.png         # 测试图片
```

## 常见问题

### Q: TLS 握手失败

**A:** 检查以下几点：
1. openHiTLS 库是否正确安装
2. `LD_LIBRARY_PATH` 是否包含 openHiTLS 库路径
3. 如果启用了证书验证，确保 CA 证书路径正确

### Q: 认证失败

**A:**
1. QQ 邮箱需要使用授权码而非登录密码
2. 确保 SMTP 服务已在邮箱设置中开启

### Q: 附件发送失败

**A:**
1. 检查文件路径是否正确
2. 确保文件存在且有读取权限

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 相关链接

- [仓颉编程语言](https://developer.huawei.com/consumer/cn/cangjie/)
- [openHiTLS](https://gitee.com/openHiTLS/openHiTLS)
- [Jakarta Mail](https://eclipse-ee4j.github.io/mail/)
