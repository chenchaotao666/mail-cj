# mail-cj API 参考文档

mail-cj 是基于仓颉（Cangjie）语言实现的邮件发送库（当前只支持SMTP），API 设计对标 Jakarta Mail（原 JavaMail），通过 openHiTLS 提供原生 TLS/SSL 支持。

---

## 目录

- [快速开始](#快速开始)
- [模块结构](#模块结构)
- [Session 配置属性](#session-配置属性)
- [核心用法示例](#核心用法示例)
  - [纯文本邮件](#1-纯文本邮件smtps-465)
  - [HTML 邮件](#2-html-邮件)
  - [带附件邮件](#3-带附件邮件)
  - [内嵌图片邮件](#4-内嵌图片邮件)
  - [多收件人](#5-多收件人to--cc--bcc)
  - [STARTTLS 连接](#6-starttls-连接端口-587)
  - [Reply-To 与回复](#7-reply-to-与回复)
  - [DSN 投递通知](#8-dsn-投递状态通知)
  - [XOAUTH2 认证](#9-xoauth2-认证)
  - [事件监听](#10-事件监听)
- [API 参考](#api-参考)
  - [mail.core](#mailcore)
  - [mail.internet](#mailinternet)
  - [mail.tls](#mailtls)
  - [mail.smtp](#mailsmtp)
  - [mail.activation](#mailactivation)
- [异常体系](#异常体系)
- [与 Jakarta Mail 对照](#与-jakarta-mail-对照)

---

## 快速开始

### 1. 导入包

```cangjie
import mail.core.*       // Session、Message、Transport、Address、RecipientType
import mail.internet.*   // MimeMessage、MimeMultipart、MimeBodyPart、InternetAddress
import mail.tls.*        // TlsSMTPTransport（SMTPS/STARTTLS）
```

### 2. 创建 Session

```cangjie
let props = HashMap<String, String>()
props["mail.smtps.host"] = "smtp.example.com"
props["mail.smtps.port"] = "465"
props["mail.smtps.auth"] = "true"
props["mail.smtps.ssl.checkserveridentity"] = "false"

let session = Session.getInstance(props)
session.setDebug(true)  // 输出 SMTP 交互日志
```

### 3. 构造并发送邮件

```cangjie
let msg = MimeMessage(session)
msg.setFrom(InternetAddress("sender@example.com", "发件人"))
msg.setRecipients(RecipientType.TO, InternetAddress.parse("recipient@example.com"))
msg.setSubject("Hello from mail-cj", "UTF-8")
msg.setText("这是邮件正文。", "UTF-8")

let transport = TlsSMTPTransport(session, true)  // true = SMTPS（直连 SSL）
try {
    transport.connect("smtp.example.com", 465, "user@example.com", "password")
    transport.sendMessage(msg, msg.getAllRecipients())
} finally {
    transport.close()
}
```

---

## 模块结构

| 模块 | 包名 | 说明 |
|------|------|------|
| 核心抽象 | `mail.core` | Session、Message、Transport、Address、事件、异常 |
| MIME 实现 | `mail.internet` | MimeMessage、MimeMultipart、MimeBodyPart、InternetAddress |
| TLS 传输 | `mail.tls` | TlsSocket、TlsConfig、TlsSMTPTransport |
| SMTP 传输 | `mail.smtp` | SMTPTransport（明文/代理模式） |
| 数据处理 | `mail.activation` | DataHandler、FileDataSource、ByteArrayDataSource |
| 工具 | `mail.util` | Base64Util、CryptoUtil、认证机制 |

---

## Session 配置属性

Session 通过 `HashMap<String, String>` 传入配置。前缀 `mail.smtps.*` 用于 SMTPS（465 端口直连 SSL），`mail.smtp.*` 用于明文或 STARTTLS（587 端口）。

### SMTPS 属性（`mail.smtps.*`）

| 属性键 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `mail.smtps.host` | String | — | SMTP 服务器主机名 |
| `mail.smtps.port` | Int | 465 | SMTP 端口 |
| `mail.smtps.auth` | Bool | false | 是否需要身份认证 |
| `mail.smtps.ssl.checkserveridentity` | Bool | true | 验证服务器证书主机名 |
| `mail.smtps.ssl.trust` | String | — | 信任的主机名（`*` 信任全部） |
| `mail.smtps.ssl.caCert` | String | — | CA 证书文件路径 |
| `mail.smtps.auth.mechanisms` | String | 服务器通告 | 指定认证机制，如 `"LOGIN PLAIN"` |
| `mail.smtps.auth.xoauth2.token` | String | — | XOAUTH2 Bearer Token |
| `mail.smtps.auth.ntlm.domain` | String | — | NTLM 域名 |
| `mail.smtps.auth.login.disable` | Bool | false | 禁用 LOGIN 机制 |
| `mail.smtps.auth.plain.disable` | Bool | false | 禁用 PLAIN 机制 |
| `mail.smtps.auth.ntlm.disable` | Bool | false | 禁用 NTLM 机制 |
| `mail.smtps.auth.xoauth2.disable` | Bool | false | 禁用 XOAUTH2 机制 |
| `mail.smtps.auth.digest-md5.disable` | Bool | false | 禁用 DIGEST-MD5 机制 |
| `mail.smtps.connectiontimeout` | Int | 无限制 | TCP 连接超时（毫秒） |
| `mail.smtps.timeout` | Int | 无限制 | Socket 读取超时（毫秒） |
| `mail.smtps.writetimeout` | Int | 无限制 | Socket 写入超时（毫秒） |
| `mail.smtps.localhost` | String | 本机名 | EHLO 发送的本地主机名 |
| `mail.smtps.sendpartial` | Bool | false | 部分收件人失败时继续发送 |
| `mail.smtps.quitwait` | Bool | true | 等待服务器的 QUIT 响应 |
| `mail.smtps.allow8bitmime` | Bool | false | 声明 BODY=8BITMIME |
| `mail.smtps.smtputf8` | Bool | false | 启用 SMTPUTF8（RFC 6531） |
| `mail.smtps.chunksize` | Int | — | BDAT 分块大小（字节） |

### SMTP/STARTTLS 属性（`mail.smtp.*`）

| 属性键 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `mail.smtp.host` | String | — | SMTP 服务器主机名 |
| `mail.smtp.port` | Int | 25 | SMTP 端口（STARTTLS 通常 587） |
| `mail.smtp.auth` | Bool | false | 是否需要身份认证 |
| `mail.smtp.starttls.enable` | Bool | false | 启用 STARTTLS 升级 |
| `mail.smtp.starttls.required` | Bool | false | 强制要求 STARTTLS |
| 其余属性 | — | — | 与 `mail.smtps.*` 相同，前缀替换为 `mail.smtp.` |

---

## 核心用法示例

### 1. 纯文本邮件（SMTPS 465）

```cangjie
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
msg.setSubject("测试邮件", "UTF-8")
msg.setText("这是纯文本正文。", "UTF-8")

let t = TlsSMTPTransport(session, true)
try {
    t.connect("smtp.qq.com", 465, "sender@qq.com", "授权码")
    t.sendMessage(msg, msg.getAllRecipients())
} finally {
    t.close()
}
```

### 2. HTML 邮件

```cangjie
msg.setHtmlContent("""
<html>
<body>
  <h1 style="color:#2c7be5;">Hello</h1>
  <p>这是一封 <strong>HTML</strong> 邮件。</p>
</body>
</html>
""", "UTF-8")
```

### 3. 带附件邮件

```cangjie
// 手动构造 multipart/mixed
let textPart = MimeBodyPart()
textPart.setText("请查收附件。", "UTF-8")

let attachPart = MimeBodyPart()
attachPart.attachFile("/path/to/report.pdf")
attachPart.setFileName(MimeUtility.encodeText("报告.pdf", charset: "UTF-8", encoding: Some("B")))

let mp = MimeMultipart(MULTIPART_MIXED)
mp.addBodyPart(textPart)
mp.addBodyPart(attachPart)
msg.setContent(mp)

// 或使用便捷方法一次性完成
msg.setTextWithAttachments("请查收附件。", ["/path/to/report.pdf"])
```

### 4. 内嵌图片邮件

```cangjie
// HTML part 引用 cid:logo_cid
let htmlPart = MimeBodyPart()
htmlPart.setHtmlContent("""<html><body>
  <p>内嵌图片：</p>
  <img src="cid:logo_cid" width="200">
</body></html>""")

// 图片 part
let imgPart = MimeBodyPart()
imgPart.attachFile("/path/to/logo.png")
imgPart.setContentID("<logo_cid>")
imgPart.setDisposition(PART_INLINE)

let mp = MimeMultipart(MULTIPART_RELATED)
mp.addBodyPart(htmlPart)
mp.addBodyPart(imgPart)
msg.setContent(mp)

// 或使用便捷方法
msg.setHtmlWithInlineImages(
    """<img src="cid:logo">""",
    [("logo", "/path/to/logo.png")]
)
```

### 5. 多收件人（TO / CC / BCC）

```cangjie
msg.setRecipients(RecipientType.TO,
    InternetAddress.parse("a@example.com, b@example.com"))
msg.setRecipients(RecipientType.CC,
    InternetAddress.parse("cc@example.com"))
msg.setRecipients(RecipientType.BCC,
    InternetAddress.parse("bcc@example.com"))

// 发送给所有收件人（TO + CC + BCC）
t.sendMessage(msg, msg.getAllRecipients())
```

### 6. STARTTLS 连接（端口 587）

```cangjie
let props = HashMap<String, String>()
props["mail.smtp.host"]              = "smtp.example.com"
props["mail.smtp.port"]              = "587"
props["mail.smtp.auth"]              = "true"
props["mail.smtp.starttls.enable"]   = "true"
props["mail.smtp.starttls.required"] = "true"

let session = Session.getInstance(props)
// useSSL = false：明文连接后升级为 TLS
let t = TlsSMTPTransport(session, false)
t.connect("smtp.example.com", 587, "user", "password")
```

### 7. Reply-To 与回复

```cangjie
// 设置 Reply-To（收件人点"回复"时的目标地址）
msg.setReplyTo([InternetAddress("support@example.com", "客服")] as Array<Address>)

// 基于已有邮件生成回复（自动添加 Re: 前缀和 In-Reply-To 头）
original.saveChanges()
let reply = original.reply(false)     // false = 只回复发件人；true = 全体回复
reply.setFrom(InternetAddress("sender@example.com"))
reply.setRecipients(RecipientType.TO, InternetAddress.parse("recipient@example.com"))
reply.setText("这是回复内容。", "UTF-8")
```

### 8. DSN 投递状态通知

通过 `SMTPMessage` 设置信封级参数，要求服务器在投递成功/失败时发送通知报告。

```cangjie
import mail.internet.*

let msg = SMTPMessage(session)
msg.setFrom(InternetAddress("sender@example.com"))
msg.setRecipients(RecipientType.TO, InternetAddress.parse("recipient@example.com"))
msg.setSubject("DSN 测试", "UTF-8")
msg.setText("正文", "UTF-8")

// 信封 From（MAIL FROM），国内服务商要求与认证用户一致
msg.setEnvelopeFrom("sender@example.com")

// 投递失败或延迟时通知，只返回邮件头（节省带宽）
msg.setNotifyOptions(NOTIFY_FAILURE | NOTIFY_DELAY)
msg.setReturnOption(RETURN_HDRS)

// 声明支持 8bit 内容，服务器支持时无需 Base64 编码
msg.setAllow8bitMIME(true)
```

**DSN 常量说明：**

| 常量 | 值 | 含义 |
|------|-----|------|
| `NOTIFY_NEVER` | 0x00 | 从不通知 |
| `NOTIFY_SUCCESS` | 0x01 | 投递成功时通知 |
| `NOTIFY_FAILURE` | 0x02 | 投递失败时通知 |
| `NOTIFY_DELAY` | 0x04 | 投递延迟时通知 |
| `RETURN_FULL` | 1 | 通知中包含完整邮件 |
| `RETURN_HDRS` | 2 | 通知中只包含邮件头 |

### 9. XOAUTH2 认证

适用于 Gmail、Office 365 等支持 OAuth2 的服务商。

```cangjie
let props = HashMap<String, String>()
props["mail.smtps.host"]               = "smtp.gmail.com"
props["mail.smtps.port"]               = "465"
props["mail.smtps.auth"]               = "true"
props["mail.smtps.auth.mechanisms"]    = "XOAUTH2"
props["mail.smtps.auth.xoauth2.token"] = "<Bearer Token>"
props["mail.smtps.ssl.checkserveridentity"] = "false"

let session = Session.getInstance(props)
let t = TlsSMTPTransport(session, true)
// 将 token 作为 password 参数传入
t.connect("smtp.gmail.com", 465, "user@gmail.com", "<Bearer Token>")
```

> Bearer Token 需通过 OAuth2 授权流程获取，有效期通常为 1 小时。

### 10. 事件监听

```cangjie
class MyConnectionListener <: ConnectionListener {
    public init() {}
    public func opened(_: ConnectionEvent): Unit  { println("连接已建立") }
    public func closed(_: ConnectionEvent): Unit  { println("连接已关闭") }
    public func disconnected(_: ConnectionEvent): Unit { println("连接断开") }
}

class MyTransportListener <: TransportListener {
    public init() {}
    public func messageDelivered(e: TransportEvent): Unit {
        println("发送成功，收件人数：${e.validSentAddresses.size}")
    }
    public func messageNotDelivered(e: TransportEvent): Unit {
        println("全部失败，无效地址：${e.invalidAddresses.size}")
    }
    public func messagePartiallyDelivered(e: TransportEvent): Unit {
        println("部分成功：${e.validSentAddresses.size} 成功 / ${e.invalidAddresses.size} 失败")
    }
}

let t = TlsSMTPTransport(session, true)
t.addConnectionListener(MyConnectionListener())
t.addTransportListener(MyTransportListener())
t.connect(host, port, user, password)
t.sendMessage(msg, msg.getAllRecipients())
t.close()
```

---

## API 参考

### mail.core

#### `Session`

```cangjie
public class Session
```

| 方法 | 说明 |
|------|------|
| `Session.getInstance(props: HashMap<String, String>): Session` | 创建 Session（推荐） |
| `Session.getInstance(props, authenticator): Session` | 携带认证器创建 Session |
| `getProperty(name: String): ?String` | 读取属性，不存在返回 `None` |
| `getProperty(name: String, defaultValue: String): String` | 读取属性，不存在返回默认值 |
| `setProperty(name: String, value: String): Unit` | 动态设置属性 |
| `getDebug(): Bool` | 获取调试模式 |
| `setDebug(debug: Bool): Unit` | 开启/关闭 SMTP 交互日志 |
| `getTransport(): Transport` | 获取默认传输对象 |
| `getTransport(protocol: String): Transport` | 按协议获取传输对象 |

#### `RecipientType`

```cangjie
public enum RecipientType {
    | TO    // 主收件人
    | CC    // 抄送
    | BCC   // 密送
}
```

#### `Transport`（静态发送）

```cangjie
Transport.send(message: Message): Unit
Transport.send(message: Message, user: String, password: String): Unit
Transport.send(message: Message, addresses: Array<Address>): Unit
Transport.send(message: Message, addresses: Array<Address>, user: String, password: String): Unit
```

---

### mail.internet

#### `MimeMessage`

```cangjie
public open class MimeMessage <: Message
```

**构造方法：**

| 构造方法 | 说明 |
|----------|------|
| `MimeMessage(session: Session)` | 创建空白邮件 |
| `MimeMessage(source: MimeMessage)` | 从已有邮件复制 |
| `MimeMessage(session: Session, input: InputStream)` | 从 RFC 2822 格式流解析 |

**发件人 / 收件人：**

| 方法 | 说明 |
|------|------|
| `setFrom(address: Address)` | 设置 From 头 |
| `setSender(address: Address)` | 设置 Sender 头（代发场景） |
| `setRecipients(type: RecipientType, addresses: Array<Address>)` | 设置收件人 |
| `addRecipients(type: RecipientType, addresses: Array<Address>)` | 追加收件人 |
| `getAllRecipients(): Array<Address>` | 获取全部收件人（TO+CC+BCC） |
| `setReplyTo(addresses: Array<Address>)` | 设置 Reply-To 头 |

**内容设置：**

| 方法 | 说明 |
|------|------|
| `setText(text: String, charset: String)` | 设置纯文本正文 |
| `setHtmlContent(html: String, charset: String)` | 设置 HTML 正文 |
| `setContent(multipart: MimeMultipart)` | 设置 Multipart 内容 |

**便捷组合方法：**

| 方法 | 说明 |
|------|------|
| `addAttachment(filePath: String)` | 添加附件 |
| `addAttachments(filePaths: Array<String>)` | 批量添加附件 |
| `setTextWithAttachments(text, attachments)` | 纯文本 + 附件 |
| `setHtmlWithAttachments(html, attachments)` | HTML + 附件 |
| `setHtmlWithInlineImages(html, images)` | HTML + 内嵌图片，`images` 为 `(cid, filePath)` 数组 |
| `setHtmlWithImagesAndAttachments(html, images, attachments)` | HTML + 图片 + 附件 |

**邮件头操作：**

| 方法 | 说明 |
|------|------|
| `setHeader(name: String, value: String)` | 设置或替换指定头 |
| `addHeader(name: String, value: String)` | 追加指定头 |
| `removeHeader(name: String)` | 删除指定头 |
| `getHeader(name: String): ?String` | 获取头值 |
| `getAllHeaders(): ArrayList<Header>` | 获取全部头 |

**序列化：**

| 方法 | 说明 |
|------|------|
| `saveChanges()` | 根据消息属性重建标准头（发送前自动调用） |
| `writeTo(output: OutputStream)` | 将邮件序列化为 RFC 2822 格式 |
| `getMessageString(): String` | 获取邮件完整字符串 |
| `reply(replyToAll: Bool): MimeMessage` | 生成回复邮件（自动填充 Re:/In-Reply-To） |

---

#### `MimeMultipart`

```cangjie
public class MimeMultipart
```

**常用子类型常量：**

| 常量 | 值 | 适用场景 |
|------|-----|---------|
| `MULTIPART_MIXED` | `"mixed"` | 正文 + 附件 |
| `MULTIPART_ALTERNATIVE` | `"alternative"` | 文本/HTML 备选 |
| `MULTIPART_RELATED` | `"related"` | HTML + 内嵌图片 |

**主要方法：**

| 方法 | 说明 |
|------|------|
| `MimeMultipart(subType: String)` | 创建指定子类型的 multipart |
| `addBodyPart(part: MimeBodyPart)` | 追加 part |
| `addBodyPart(part: MimeBodyPart, index: Int64)` | 在指定位置插入 part |
| `getBodyPart(index: Int64): MimeBodyPart` | 按索引获取 part |
| `getCount(): Int64` | 获取 part 数量 |
| `getContentType(): String` | 获取含 boundary 的 Content-Type |

**便捷工厂函数：**

```cangjie
createMixedMultipart(textContent: String, attachments: Array<String>): MimeMultipart
createRelatedMultipart(htmlContent: String, images: Array<(String, String)>): MimeMultipart
createAlternativeMultipart(textContent: String, htmlContent: String): MimeMultipart
```

---

#### `MimeBodyPart`

```cangjie
public class MimeBodyPart
```

**内容设置：**

| 方法 | 说明 |
|------|------|
| `setText(text, charset)` | 设置纯文本内容 |
| `setHtmlContent(html: String)` | 设置 HTML 内容 |
| `attachFile(path: String)` | 从文件路径加载内容并设为附件 |
| `setDataHandler(handler: DataHandler)` | 从 DataHandler 设置内容（内存数据源） |

**元数据：**

| 方法 | 说明 |
|------|------|
| `setFileName(name: String)` | 设置附件文件名（建议 RFC 2047 编码中文） |
| `setDisposition(disp: String)` | 设置 Content-Disposition（`inline` / `attachment`） |
| `setContentID(cid: String)` | 设置 Content-ID（内嵌图片引用，格式 `<id>`） |
| `setContentType(type: String)` | 设置 Content-Type |
| `setTransferEncoding(enc: String)` | 设置 Content-Transfer-Encoding |

**便捷工厂函数：**

```cangjie
createTextBodyPart(text: String): MimeBodyPart
createHtmlBodyPart(html: String): MimeBodyPart
createAttachmentBodyPart(filePath: String): MimeBodyPart
createInlineImageBodyPart(filePath: String, contentId: String): MimeBodyPart
createAttachmentBodyPartFromDataSource(dataSource: DataSource): MimeBodyPart
```

---

#### `InternetAddress`

```cangjie
public class InternetAddress <: Address
```

| 方法 | 说明 |
|------|------|
| `InternetAddress(address: String)` | 仅邮箱地址 |
| `InternetAddress(address: String, personal: String)` | 邮箱地址 + 显示名 |
| `InternetAddress.parse(addressList: String): Array<Address>` | 解析逗号分隔的地址列表 |
| `getAddress(): String` | 获取邮箱地址 |
| `getPersonal(): ?String` | 获取显示名 |
| `validate()` | 验证地址格式（格式错误抛 `AddressException`） |
| `toString(): String` | 返回 `"显示名 <address>"` 格式 |

---

#### `SMTPMessage`

```cangjie
public class SMTPMessage <: MimeMessage
```

继承 `MimeMessage` 的全部方法，额外提供信封级控制：

| 方法 | 说明 |
|------|------|
| `setEnvelopeFrom(address: String)` | 设置 MAIL FROM 信封地址（退信地址） |
| `getEnvelopeFrom(): ?String` | 获取信封地址 |
| `setNotifyOptions(options: Int32)` | 设置 DSN 通知选项（`NOTIFY_*` 常量按位或） |
| `setReturnOption(option: Int32)` | 设置 DSN 返回内容（`RETURN_FULL` / `RETURN_HDRS`） |
| `setAllow8bitMIME(allow: Bool)` | 声明 BODY=8BITMIME |
| `setSmtpUtf8(enable: Bool)` | 启用 SMTPUTF8（RFC 6531，支持非 ASCII 邮箱） |
| `setSendPartial(partial: Bool)` | 部分收件人失败时继续发送 |
| `setMailExtension(ext: String)` | 向 MAIL FROM 添加自定义扩展参数 |

---

#### `MimeUtility`

```cangjie
public class MimeUtility
```

| 方法 | 说明 |
|------|------|
| `encodeWord(word, charset, encoding): String` | RFC 2047 编码单词（默认 UTF-8/Base64） |
| `decodeWord(word: String): String` | RFC 2047 解码 |
| `encodeText(text, charset, encoding): String` | 编码含特殊字符的文本（用于文件名等） |
| `decodeText(text: String): String` | 解码文本 |
| `fold(headerLine: String, used: Int64): String` | 折行（用于长头处理） |
| `unfold(s: String): String` | 反折行 |

---

### mail.tls

#### `TlsSMTPTransport`

```cangjie
public class TlsSMTPTransport <: Transport
```

mail-cj 主要使用的传输类，内置 openHiTLS 支持。

| 方法 | 说明 |
|------|------|
| `TlsSMTPTransport(session: Session, useSSL: Bool)` | `useSSL=true` 为 SMTPS 直连；`false` 为明文+STARTTLS |
| `connect(host: String, port: Int64, user: String, password: String)` | 建立连接并认证 |
| `sendMessage(message: Message, addresses: Array<Address>)` | 发送邮件 |
| `close()` | 断开连接 |
| `isConnected(): Bool` | 检查连接状态（长连接保活） |
| `noop(): Bool` | 发送 NOOP 心跳（失败表示连接已断开） |
| `reset(): Bool` | 重置 SMTP 状态 |
| `setVerifyCert(verify: Bool)` | 运行时切换证书验证 |
| `setCACertPath(path: String)` | 设置 CA 证书路径 |
| `supportsExtension(ext: String): Bool` | 查询服务器是否支持指定扩展（如 `"PIPELINING"`） |
| `getExtensionParameter(ext: String): ?String` | 获取扩展参数值 |
| `getLastServerResponse(): String` | 获取最后一次服务器响应 |
| `getLastReturnCode(): Int64` | 获取最后一次响应码 |
| `addTransportListener(l: TransportListener)` | 注册发送事件监听器 |
| `addConnectionListener(l: ConnectionListener)` | 注册连接事件监听器 |

---

#### `TlsConfig`

```cangjie
public class TlsConfig
```

底层 openHiTLS 配置封装，一般不需要直接使用（`TlsSMTPTransport` 内部管理）。

```cangjie
// 使用工厂函数创建
let config = createClientConfig()                        // 不验证证书
let config = createSecureClientConfig("/path/to/ca.crt") // 验证 CA

// 链式配置
config
    .setVersion(TlsVersion.TLS_1_3)
    .setVerifyMode(TlsVerifyMode.VERIFY_PEER)
    .setCACertPath("/path/to/ca.crt")
    .initialize()
```

---

### mail.smtp

#### `SMTPTransport`

用于明文 SMTP 或通过外部代理（如 stunnel）连接，使用方式与 `TlsSMTPTransport` 相同。

```cangjie
import mail.smtp.*
initSMTPModule()  // 注册 smtp 协议到 Session

let t = SMTPTransport(session, false)
t.connect(host, port, user, password)
```

---

### mail.activation

#### `DataHandler`

```cangjie
public class DataHandler
  DataHandler(dataSource: DataSource)         // 从数据源构造
  DataHandler(content: String, mimeType: String) // 从字符串内容构造
```

#### `FileDataSource`

```cangjie
let ds = FileDataSource("/path/to/file.pdf")
ds.setContentType("application/pdf")  // 覆盖自动探测的类型
let handler = DataHandler(ds)
bodyPart.setDataHandler(handler)
```

#### `ByteArrayDataSource`

```cangjie
// 从内存字节数组创建数据源（适用于动态生成的内容）
let data: Array<Byte> = generatePdfBytes()
let ds = ByteArrayDataSource(data, "application/pdf")
bodyPart.setDataHandler(DataHandler(ds))
```

#### `FileTypeMap`

```cangjie
let ftm = FileTypeMap.getDefaultFileTypeMap()
let contentType = ftm.getContentType("report.pdf")  // "application/pdf"
```

---

## 异常体系

```
Exception
└── MessagingException                  // 所有邮件相关异常的基类
    ├── AddressException                // 地址解析/格式错误
    ├── AuthenticationFailedException   // 认证失败（用户名/密码/token 错误）
    ├── ParseException                  // 内容解析错误
    ├── NoSuchProviderException         // 找不到指定协议的 Transport
    ├── MailConnectException            // TCP 连接失败（含主机、端口、超时信息）
    └── SendFailedException             // 发送失败（含已发/未发/无效地址列表）
        ├── SMTPSendFailedException     // SMTP 协议级发送错误（含 SMTP 响应码）
        ├── SMTPSenderFailedException   // MAIL FROM 被拒绝
        ├── SMTPAddressFailedException  // 某个收件人地址被拒绝
        └── SMTPAddressSucceededException // 某个收件人发送成功（用于部分发送场景）

TlsException                           // TLS/SSL 相关错误
├── TlsHandshakeException               // TLS 握手失败
└── TlsCertificateException             // 证书验证失败
```

**典型错误处理：**

```cangjie
try {
    t.connect(host, port, user, password)
    t.sendMessage(msg, msg.getAllRecipients())
} catch (e: AuthenticationFailedException) {
    println("认证失败：${e.message}")
} catch (e: SMTPSendFailedException) {
    println("SMTP 错误 ${e.getReturnCode()}：${e.message}")
    println("无效地址：${e.getInvalidAddresses().size} 个")
} catch (e: MailConnectException) {
    println("连接 ${e.getHost()}:${e.getPort()} 超时：${e.message}")
} catch (e: MessagingException) {
    println("发送失败：${e.message}")
} finally {
    t.close()
}
```

---

## 与 Jakarta Mail 对照

| Jakarta Mail | mail-cj | 说明 |
|---|---|---|
| `Session.getInstance(props)` | `Session.getInstance(props)` | 同名 |
| `new MimeMessage(session)` | `MimeMessage(session)` | 同名 |
| `new MimeMultipart("mixed")` | `MimeMultipart(MULTIPART_MIXED)` | 常量替代字符串 |
| `new MimeBodyPart()` | `MimeBodyPart()` | 同名 |
| `new InternetAddress(addr, name)` | `InternetAddress(addr, name)` | 同名 |
| `new SMTPMessage(session)` | `SMTPMessage(session)` | 同名 |
| `SMTPMessage.NOTIFY_FAILURE` | `NOTIFY_FAILURE` | 顶层常量 |
| `SMTPMessage.RETURN_HDRS` | `RETURN_HDRS` | 顶层常量 |
| `MimePart.INLINE` | `PART_INLINE` | 顶层常量 |
| `MimeUtility.encodeText(...)` | `MimeUtility.encodeText(...)` | 同名，参数为具名参数 |
| `transport.connect(host, user, pwd)` | `transport.connect(host, port, user, pwd)` | 需显式传端口 |
| `Session.getTransport("smtps")` | `TlsSMTPTransport(session, true)` | 直接构造 |
| `Transport.addTransportListener` | `transport.addTransportListener` | 同名 |
| `msg.reply(false)` | `msg.reply(false)` | 同名 |
