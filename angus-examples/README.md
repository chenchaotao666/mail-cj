# angus-mail 发送示例

angus-mail（Jakarta Mail）邮件发送场景覆盖示例，与 [mail-cj](../README.md) 一一对标。

## 场景列表

| 编号 | 场景 | 入口类 | 对标 mail-cj |
|------|------|--------|-------------|
| `--01` | 纯文本邮件（SMTPS 465） | `SendSimple` | `sendSimple()` |
| `--02` | HTML 邮件 | `SendHtml` | `sendHtml()` |
| `--03` | 带附件邮件（multipart/mixed） | `SendWithAttachment` | `sendWithAttachment()` |
| `--04` | HTML + 内嵌图片（multipart/related） | `SendWithInlineImage` | `sendWithInlineImage()` |
| `--05` | 复杂邮件（HTML + 图片 + 附件） | `SendComplex` | `sendComplex()` |
| `--06` | 多收件人（TO / CC / BCC） | `SendCcBcc` | `sendCcBcc()` |
| `--07` | STARTTLS 连接（端口 587） | `SendWithStartTLS` | `sendWithStartTLS()` |
| `--08` | Reply-To 与 reply() 回复 | `SendReply` | `sendReply()` |
| `--09` | 群发（单连接 + 复制构造） | `SendBulk` | `sendBulk()` |
| `--10` | 自定义邮件头 + Sender 代发 | `SendWithCustomHeaders` | `sendWithCustomHeaders()` |
| `--11` | multipart/alternative 文本/HTML 兼容 | `SendAlternative` | `sendAlternative()` |
| `--12` | 从 InputStream 加载模板并转发 | `SendFromInputStream` | `sendFromInputStream()` |
| `--13` | SMTPMessage 信封 From + DSN 通知 | `SendWithSMTPMessage` | `sendWithSMTPMessage()` |
| `--14` | TransportListener + ConnectionListener | `SendWithTransportListener` | `sendWithTransportListener()` |
| `--15` | 长连接保活（NOOP 心跳） | `SendWithConnectionPool` | `sendWithConnectionPool()` |
| `--16` | XOAUTH2 OAuth2 认证 | `SendWithXOAuth2` | `sendWithXOAuth2()` |

## 快速开始

```bash
# 1. 配置 SMTP 参数
cp .env.example .env
vi .env   # 填写 SMTP_HOST / SMTP_USER / SMTP_PASSWORD / MAIL_TO

# 2. 构建
mvn package -q

# 3. 运行（以纯文本邮件为例）
java -jar target/angus-mail-examples-1.0.0.jar --01

# 查看全部场景
java -jar target/angus-mail-examples-1.0.0.jar
```

也可以直接运行单个类：

```bash
mvn exec:java -Dexec.mainClass=examples.SendHtml
```

## 依赖

- Java 17+
- Maven 3.8+
- angus-mail 2.0.3（`org.eclipse.angus:angus-mail`）

## .env 配置项

| 键 | 说明 | 示例 |
|----|------|------|
| `SMTP_HOST` | SMTP 服务器地址 | `smtp.gmail.com` |
| `SMTP_PORT` | 端口（465=SSL，587=STARTTLS） | `465` |
| `SMTP_USER` | 登录用户名 | `you@gmail.com` |
| `SMTP_PASSWORD` | 登录密码或应用专用密码 | `xxxx xxxx xxxx xxxx` |
| `MAIL_FROM` | 发件人地址 | `you@gmail.com` |
| `MAIL_FROM_NAME` | 发件人显示名称 | `Your Name` |
| `MAIL_TO` | 收件人地址 | `recipient@example.com` |
| `MAIL_CC` | 抄送（逗号分隔，可选） | `cc@example.com` |
| `MAIL_BCC` | 密送（逗号分隔，可选） | `bcc@example.com` |
| `OAUTH2_TOKEN` | OAuth2 Bearer Token（场景 16） | `ya29.xxxx` |
| `DEBUG` | 开启 SMTP 调试输出 | `false` |
