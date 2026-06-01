# mail-cj 发送侧现有差距（vs. angus-mail）

> 分析范围：仅邮件发送（SMTP），不含接收（IMAP/POP3）  
> 初次分析：2026-05-30  
> 最后更新：2026-06-01（P0 / P1 / P2 / PIPELINING / DSN / SMTPUTF8 已全部实现）

---

## 差距统计

| 类别 | 剩余差距数 | 影响评估 |
|------|-----------|---------|
| 连接与代理 | 5 项 | 低：主流场景不依赖 URLName / SOCKS |
| MIME 内容处理 | 9 项 | 低：发送侧不需要解析现有邮件流 |
| SMTP 协议扩展 | 1 项 | 极低：ORCPT= 仅用于转发场景的 DSN 定位 |
| 认证与配置 | 4 项 | 低：`authzid`、SOCKS 等小众场景 |
| API 细节 | 4 项 | 低：调试流重定向、Group 地址等边缘场景 |

> **当前无高优先级差距**。所有影响主流业务场景的功能均已实现。

---

## 一、连接与代理

| 差距 | angus-mail | 说明 |
|------|-----------|------|
| `getTransport(URLName)` / `connect(URLName)` | ✅ | 通过 `smtp://user:pass@host:port` 风格 URL 描述连接；mail-cj 不支持 URLName 概念 |
| `getTransport(Provider)` | ✅ | 传入 Provider 实例获取指定 Transport；mail-cj 只有类型字符串方式 |
| `connect(Socket)` | ✅ | 传入已建立的 Socket（如来自 SOCKS 代理或 stunnel）；mail-cj 有 `connectWithFd(fd)` 可部分替代，但需要 FFI |
| SOCKS 代理（`mail.smtp.socks.host` / `.port`）| ✅ | 内置 SOCKS4/5 代理支持；mail-cj 无代理层，需外部 tunnel |
| 自定义 Socket 工厂（`MailSSLSocketFactory`）| ✅ | 允许注入自定义 TLS/Socket 工厂；mail-cj 固定用 HiTLS |

---

## 二、MIME 内容处理

### 2.1 消息 / BodyPart 读取流

| 差距 | angus-mail | 说明 |
|------|-----------|------|
| `MimeMessage.getInputStream()` | ✅ | 返回消息体的原始 InputStream；发送侧若需二次处理内容则缺少此入口 |
| `MimeBodyPart.getInputStream()` | ✅ | 返回 BodyPart 内容 InputStream；mail-cj 只提供 `getContent(): ?String` |
| `MimeMultipart(DataSource)` | ✅ | 从 DataSource 流式解析已有 multipart；发送侧通常不需要 |
| `InternetHeaders(InputStream)` | ✅ | 直接从流解析头部；mail-cj 只能通过 `MimeMessage(Session, InputStream)` 间接解析 |

### 2.2 MimeUtility 编码流

| 差距 | angus-mail | 说明 |
|------|-----------|------|
| `getEncoding(DataHandler)` | ✅ | 根据内容自动选最优 CTE（7bit / 8bit / base64 / quoted-printable）；mail-cj 目前固定 base64 或 8bit |
| `decode(InputStream, encoding)` | ✅ | 解码任意 CTE 流；mail-cj 仅在 InputStream 构造函数内部支持 |
| `encode(OutputStream, encoding)` | ✅ | 编码写出流；mail-cj 仅在 writeTo 时隐式处理 |
| `mimeCharset(javaCharset)` | ✅ | Java 字符集名 → MIME 字符集名（如 `UTF8` → `UTF-8`） |
| `javaCharset(mimeCharset)` | ✅ | MIME 字符集名 → 运行时字符集名 |

> **影响**：上述 5 项 MimeUtility 缺口导致 mail-cj 无法对正文做智能 CTE 选择（始终 base64），对纯 ASCII 或 Latin-1 内容略有体积浪费；对发送侧核心功能无阻断性影响。

### 2.3 其他 MIME API

| 差距 | angus-mail | 说明 |
|------|-----------|------|
| `MimeMessage.setContent(Object, mimeType)` | ✅ | 设置任意内容对象（如 `byte[]`、自定义 DataHandler）；mail-cj 只支持 String 和 MimeMultipart |
| `InternetAddress.isGroup()` / `getGroup(strict)` | ✅ | RFC 2822 Group 地址（`groupName: addr1, addr2;`）解析；mail-cj 不支持 Group 展开 |

---

## 三、SMTP 协议扩展

| 差距 | RFC | 说明 | 影响 |
|------|-----|------|------|
| **RCPT TO `ORCPT=` 参数** | 1891 | 指定原始收件人地址（转发/重定向场景下的 DSN 溯源）；mail-cj 已支持 `NOTIFY=`，但未实现 `ORCPT=` | 极低：仅邮件转发链路追踪场景需要 |

---

## 四、认证与配置

| 差距 | angus-mail | 说明 |
|------|-----------|------|
| `authorizationID`（SASL authzid） | ✅ | 代理认证场景（以 A 身份认证，但代理 B 发送）；mail-cj `AuthContext` 无 authzid 字段 |
| `SMTPMessage.setSubmitter(authzid)` | ✅ | RFC 2554 `AUTH=` MAIL FROM 参数，标记原始提交者身份；mail-cj 已有 `setMailExtension` 可手动附加但不自动化 |
| `mail.smtp.auth` 显式开关 | ✅ | `true`/`false` 强制控制是否认证；mail-cj 隐式逻辑：有 user+password 就认证，无法强制禁用 |
| `mail.smtp.sasl.enable` / SASL 框架 | ✅ | 启用 Java SASL 框架，支持系统级 SASL 插件；mail-cj 的 `AuthMechanismSelector` 已覆盖主流机制 |

---

## 五、API 细节

| 差距 | angus-mail | 说明 |
|------|-----------|------|
| `Session.setDebugOut(PrintStream)` | ✅ | 调试输出可重定向到任意流；mail-cj 固定输出到 stdout（`println`） |
| `Session.getProperties()` 返回类型 | ✅ Returns `Properties` | mail-cj 返回 `HashMap<String, String>`，语义等价但类型不一致 |
| 邮件组地址展开（`expandGroups()`） | ✅ | 发送前将 RFC 2822 Group 地址展开为独立收件人；依赖 `isGroup()` 支持 |
| `sendMessage` 结束后显式清理内部引用 | ✅ `finally` 块 | mail-cj `sendMessage` 无 finally 清理，极端情况下内存持有略长；不影响正确性 |
