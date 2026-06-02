# mail-cj 发送示例

mail-cj（仓颉邮件库）邮件发送场景覆盖示例，与 [angus-examples](../angus-examples/README.md)（Jakarta Mail）一一对标。

## 场景列表

| 编号 | 场景 | 入口函数 | 对标 angus-examples |
|------|------|----------|---------------------|
| `--01` | 纯文本邮件（SMTPS 465） | `sendSimple()` | `SendSimple` |
| `--02` | HTML 邮件 | `sendHtml()` | `SendHtml` |
| `--03` | 带附件邮件（multipart/mixed） | `sendWithAttachment()` | `SendWithAttachment` |
| `--04` | HTML + 内嵌图片（multipart/related） | `sendWithInlineImage()` | `SendWithInlineImage` |
| `--05` | 复杂邮件（HTML + 图片 + 附件） | `sendComplex()` | `SendComplex` |
| `--06` | 多收件人（TO / CC / BCC） | `sendCcBcc()` | `SendCcBcc` |
| `--07` | STARTTLS 连接（端口 587） | `sendWithStartTLS()` | `SendWithStartTLS` |
| `--08` | Reply-To 与 reply() 回复 | `sendReply()` | `SendReply` |
| `--09` | 群发（单连接 + 复制构造） | `sendBulk()` | `SendBulk` |
| `--10` | 自定义邮件头 + Sender 代发 | `sendWithCustomHeaders()` | `SendWithCustomHeaders` |
| `--11` | multipart/alternative 文本/HTML 兼容 | `sendAlternative()` | `SendAlternative` |
| `--12` | 从 InputStream 加载模板并转发 | `sendFromInputStream()` | `SendFromInputStream` |
| `--13` | SMTPMessage 信封 From + DSN 通知 | `sendWithSMTPMessage()` | `SendWithSMTPMessage` |
| `--14` | TransportListener + ConnectionListener | `sendWithTransportListener()` | `SendWithTransportListener` |
| `--15` | 长连接保活（isConnected 心跳） | `sendWithConnectionPool()` | `SendWithConnectionPool` |
| `--16` | XOAUTH2 OAuth2 认证 | `sendWithXOAuth2()` | `SendWithXOAuth2` |

## 快速开始

```bash
# 1. 配置 SMTP 参数
cp .env.example .env
vi .env   # 填写 SMTP_HOST / SMTP_USER / SMTP_PASSWORD / MAIL_TO

# 2. 构建（自动检测 HiTLS 路径）
./build.sh

# 3. 运行（以纯文本邮件为例）
cjpm run --run-args="--01"

# 查看全部场景
cjpm run
```

## 编译说明

**推荐方式（自动检测 HiTLS 路径）：**
```bash
./build.sh
```

**或直接编译（需提前配置 `cjpm.toml` 中的 HiTLS 路径）：**
```bash
cjpm build
```

配置模板：
```bash
cp cjpm.toml.example cjpm.toml
# 编辑 cjpm.toml，修改 HiTLS 路径为实际安装路径
```

## 场景编号

```
--01   纯文本邮件（SMTPS 465）
--02   HTML 邮件
--03   带附件邮件（multipart/mixed）
--04   HTML + 内嵌图片（multipart/related）
--05   复杂邮件（HTML + 图片 + 附件）
--06   多收件人（TO / CC / BCC）
--07   STARTTLS 连接（端口 587）
--08   Reply-To 与 reply() 回复
--09   群发（单连接复制构造）
--10   自定义邮件头 + Sender 代发
--11   multipart/alternative 文本/HTML 兼容
--12   从 InputStream 加载模板并转发
--13   SMTPMessage 信封 From + DSN 通知
--14   TransportListener + ConnectionListener
--15   长连接保活（isConnected 心跳）
--16   XOAUTH2 OAuth2 认证
```

## .env 配置项

| 键 | 说明 | 示例 |
|----|------|------|
| `SMTP_HOST` | SMTP 服务器地址 | `smtp.gmail.com` |
| `SMTP_PORT` | 端口（465=SSL，587=STARTTLS） | `465` |
| `SMTP_USER` | 登录用户名 | `you@gmail.com` |
| `SMTP_PASSWORD` | 登录密码或应用专用密码 | `xxxx xxxx xxxx xxxx` |
| `MAIL_FROM` | 发件人地址（默认同 SMTP_USER） | `you@gmail.com` |
| `MAIL_FROM_NAME` | 发件人显示名称 | `Your Name` |
| `MAIL_TO` | 收件人地址 | `recipient@example.com` |
| `MAIL_CC` | 抄送（逗号分隔，可选） | `cc@example.com` |
| `MAIL_BCC` | 密送（逗号分隔，可选） | `bcc@example.com` |
| `OAUTH2_TOKEN` | OAuth2 Bearer Token（场景 16） | `ya29.xxxx` |
| `ATTACHMENT_PATH` | 附件路径（场景 3/5） | `assets/test.txt` |
| `DEBUG` | 开启 SMTP 调试输出 | `false` |

## 与 angus-examples 的 API 对应关系

| Jakarta Mail | mail-cj |
|---|---|
| `Session.getInstance(props)` | `Session.getInstance(props)` |
| `new MimeMessage(session)` | `MimeMessage(session)` |
| `new MimeMessage(source)` | `MimeMessage(source)` 复制构造 |
| `new MimeMessage(session, inputStream)` | `MimeMessage(session, inputStream)` |
| `session.getTransport("smtps")` | `TlsSMTPTransport(session, true)` |
| `session.getTransport("smtp")` （STARTTLS）| `TlsSMTPTransport(session, false)` |
| `t.connect(host, user, pass)` | `t.connect(host, port, user, pass)` |
| `new MimeMultipart("mixed")` | `MimeMultipart(MULTIPART_MIXED)` |
| `new MimeMultipart("related")` | `MimeMultipart(MULTIPART_RELATED)` |
| `new MimeMultipart("alternative")` | `MimeMultipart(MULTIPART_ALTERNATIVE)` |
| `new SMTPMessage(session)` | `SMTPMessage(session)` |
| `transport.addTransportListener(l)` | `transport.addTransportListener(l)` |
| `transport.addConnectionListener(l)` | `transport.addConnectionListener(l)` |
| `transport.isConnected()` | `transport.isConnected()` |
| `msg.reply(replyToAll)` | `msg.reply(replyToAll)` |
| `msg.setSender(addr)` | `msg.setSender(addr)` |
| `msg.setHeader(name, value)` | `msg.setHeader(name, value)` |

## 依赖

- 仓颉编译器 1.0.4+
- openHiTLS（TLS 支持）：推荐安装到 `~/.local/lib/hitls`，参考 https://gitee.com/opengauss/openHiTLS
