# mail-cj SMTP 发送功能全量测试用例

> 对标目标：angus-mail（org.eclipse.angus:angus-mail）发送侧全部功能  
> 框架：仓颉 `@Test / @TestCase / @Expect / @Assert`  
> 覆盖范围：Session、地址解析、消息构造、MIME 结构、传输协议、认证、错误处理  
> 最后更新：2026-06-01

---

## 用例统计

| 模块编号 | 模块名称 | 用例数 | 覆盖点 |
|---------|---------|--------|--------|
| TC-SESSION  | Session 会话管理          | 10 | 属性读写、调试开关、Transport 工厂注册 |
| TC-ADDRESS  | 邮件地址处理              | 15 | InternetAddress 构造/解析/验证/RFC 2047 编码 |
| TC-MESSAGE  | MIME 邮件消息             | 38 | MimeMessage 构造、头部操作、内容设置、序列化、reply、InputStream 解析 |
| TC-MULTIPART| MIME 多部分容器           | 14 | MimeMultipart 结构操作、边界生成、part 增删、序列化 |
| TC-BODYPART | MIME 正文部分             | 14 | MimeBodyPart 文本/HTML/附件/内嵌图片内容设置 |
| TC-AUTH     | SMTP 认证机制             | 12 | LOGIN / PLAIN / XOAUTH2 / NTLM / DIGEST-MD5 协议流程 |
| TC-TRANSPORT| SMTP 传输行为             | 24 | 连接建立/关闭/超时、sendMessage、sendPartial、事件通知 |
| TC-SMTPMSG  | SMTPMessage 信封扩展      | 10 | 信封 From 分离、DSN 通知选项、SMTPUTF8、MAIL FROM 扩展参数 |
| TC-PROTOCOL | SMTP 协议命令正确性        | 18 | MAIL FROM / RCPT TO / DATA / BDAT / PIPELINING 命令格式与时序 |
| TC-ERROR    | 错误与异常处理             | 12 | 发件人/收件人/DATA 拒绝、认证失败、连接超时等异常路径 |
| TC-CRYPTO   | 加密工具（CryptoUtil）     | 8  | MD4 / MD5 标准向量、HMAC-MD5、hexEncode、UTF-16LE |
| TC-BASE64   | Base64 编解码工具          | 6  | 编码/解码往返、边界值、空数据、含空白字符解码 |
| TC-MIMEUTIL | MIME 编码工具（MimeUtility）| 8  | RFC 2047 encodeWord/decodeWord、头部折叠/展开 |
| **合计**    |                           | **189** | |

---

## 一、TC-SESSION — Session 会话管理

### TC-SESSION-001 基本属性 Session 创建
```
前置：无
步骤：
  props["mail.smtp.host"] = "smtp.example.com"
  props["mail.smtp.port"] = "587"
  val session = Session.getInstance(props)
  session.getProperty("mail.smtp.host")
期望：Some("smtp.example.com")
angus-mail：Session.getInstance(Properties)
优先级：P0
```

### TC-SESSION-002 getDefaultInstance 语义
```
步骤：
  val s1 = Session.getDefaultInstance(props)
  val s2 = Session.getDefaultInstance(props)
期望：两次调用返回同一逻辑实例（属性相同）
angus-mail：Session.getDefaultInstance(Properties)
优先级：P1
```

### TC-SESSION-003 属性不存在返回 None
```
步骤：session.getProperty("mail.smtp.nonexist")
期望：None
优先级：P0
```

### TC-SESSION-004 属性带默认值
```
步骤：session.getProperty("mail.smtp.nonexist", "default_val")
期望："default_val"
优先级：P0
```

### TC-SESSION-005 运行时 setProperty
```
步骤：
  session.setProperty("mail.smtp.port", "465")
  session.getProperty("mail.smtp.port")
期望：Some("465")
优先级：P0
```

### TC-SESSION-006 调试模式默认关闭
```
步骤：session.getDebug()
期望：false
优先级：P1
```

### TC-SESSION-007 调试模式开关
```
步骤：session.setDebug(true); session.getDebug()
期望：true
步骤2：session.setDebug(false); session.getDebug()
期望：false
优先级：P1
```

### TC-SESSION-008 getTransport("smtp") 返回 SMTPTransport
```
前置：Session.registerTransportFactory 已注册
步骤：session.getTransport()
期望：返回可调用 connect() 的 Transport 实例（不抛异常）
angus-mail：Session.getTransport()
优先级：P0
```

### TC-SESSION-009 getTransport 未知协议抛异常
```
步骤：session.getTransport("nonexistent")
期望：抛 MessagingException
angus-mail：Session.getTransport(String)
优先级：P1
```

### TC-SESSION-010 带 Authenticator 的 Session
```
步骤：
  val auth = PasswordAuthenticator("user", "pass")
  val session = Session.getInstance(props, Some(auth))
  session.getAuthenticator()
期望：Some(auth)
angus-mail：Session.getInstance(Properties, Authenticator)
优先级：P1
```

---

## 二、TC-ADDRESS — 邮件地址处理

### TC-ADDRESS-001 纯地址构造
```
步骤：InternetAddress("user@example.com")
期望：getAddress() == "user@example.com"、getPersonal() == None
angus-mail：new InternetAddress(String)
优先级：P0
```

### TC-ADDRESS-002 带 ASCII 显示名
```
步骤：InternetAddress("user@example.com", "John Smith")
期望：toString() == "John Smith <user@example.com>"
angus-mail：new InternetAddress(String, String)
优先级：P0
```

### TC-ADDRESS-003 含逗号的显示名自动加引号
```
步骤：InternetAddress("user@example.com", "Smith, John").toString()
期望：包含引号，如 "\"Smith, John\" <user@example.com>"
优先级：P1
```

### TC-ADDRESS-004 非 ASCII 显示名自动 RFC 2047 编码
```
步骤：InternetAddress("user@example.com", "张三").toString()
期望：以 "=?UTF-8?B?" 开头，可被 MimeUtility.decodeText 还原为"张三"
angus-mail：new InternetAddress(String, String) → toString() encodes non-ASCII
优先级：P1
```

### TC-ADDRESS-005 parse 单地址
```
步骤：InternetAddress.parse("user@example.com")
期望：size==1，addrs[0].getAddress()=="user@example.com"
优先级：P0
```

### TC-ADDRESS-006 parse 逗号分隔多地址
```
步骤：InternetAddress.parse("a@x.com, b@y.com, c@z.com")
期望：size==3
优先级：P0
```

### TC-ADDRESS-007 parse "Name" <email> 格式
```
步骤：InternetAddress.parse("\"Alice\" <alice@example.com>")
期望：getAddress()=="alice@example.com"
优先级：P0
```

### TC-ADDRESS-008 parse 含尖括号不含引号
```
步骤：InternetAddress.parse("Bob <bob@example.com>")
期望：getAddress()=="bob@example.com"
优先级：P0
```

### TC-ADDRESS-009 validate 有效地址不抛异常
```
步骤：InternetAddress("user@example.com").validate()
期望：正常返回，无异常
angus-mail：InternetAddress.validate()
优先级：P0
```

### TC-ADDRESS-010 validate 无 @ 抛 AddressException
```
步骤：InternetAddress("invalid").validate()
期望：抛 AddressException
优先级：P0
```

### TC-ADDRESS-011 validate 无域名抛 AddressException
```
步骤：InternetAddress("user@").validate()
期望：抛 AddressException
优先级：P1
```

### TC-ADDRESS-012 parse 空字符串返回空数组
```
步骤：InternetAddress.parse("")
期望：size==0
优先级：P1
```

### TC-ADDRESS-013 parse 地址前后空白被 trim
```
步骤：InternetAddress.parse("  user@example.com  ")
期望：size==1，getAddress()=="user@example.com"
优先级：P1
```

### TC-ADDRESS-014 getLocalAddress
```
步骤：
  props["mail.smtp.localhost"] = "myhost.example.com"
  props["mail.smtp.user"] = "myuser"
  InternetAddress.getLocalAddress(session)
期望：getAddress() 包含 "myuser"，host 包含 "myhost.example.com"
angus-mail：InternetAddress.getLocalAddress(Session)
优先级：P2
```

### TC-ADDRESS-015 SMTPUTF8 地址构造（包含 UTF-8 字符）
```
步骤：InternetAddress("用户@example.com")
期望：getAddress() == "用户@example.com"（不抛异常）
优先级：P2
```

---

## 三、TC-MESSAGE — MIME 邮件消息（MimeMessage）

### TC-MESSAGE-001 Session 构造后字段默认值
```
步骤：MimeMessage(session)
期望：getFrom()==[]、getSubject()==None、_saved==false
angus-mail：new MimeMessage(Session)
优先级：P0
```

### TC-MESSAGE-002 setFrom / getFrom
```
步骤：msg.setFrom(InternetAddress("a@b.com"))
      msg.getFrom()
期望：size==1，addrs[0].getAddress()=="a@b.com"
angus-mail：setFrom(Address)
优先级：P0
```

### TC-MESSAGE-003 addFrom 追加发件人
```
步骤：msg.addFrom([InternetAddress("b@c.com"), InternetAddress("d@e.com")])
期望：getFrom().size==2（已有 a@b.com 时为 3）
angus-mail：MimeMessage.addFrom(Address[])
优先级：P1
```

### TC-MESSAGE-004 setSender / getSender
```
步骤：msg.setSender(InternetAddress("proxy@example.com"))
      msg.saveChanges()
      msg.getMessageString().contains("Sender:")
期望：true，且 Sender 值为 proxy@example.com
angus-mail：setSender(Address) → Sender header
优先级：P2
```

### TC-MESSAGE-005 setRecipients TO / CC / BCC
```
步骤：
  msg.setRecipients(TO,  [a@b.com])
  msg.setRecipients(CC,  [c@d.com])
  msg.setRecipients(BCC, [e@f.com])
  msg.getRecipients(TO).size
  msg.getRecipients(CC).size
  msg.getRecipients(BCC).size
期望：各为 1
angus-mail：setRecipients(Message.RecipientType, Address[])
优先级：P0
```

### TC-MESSAGE-006 addRecipients 累加
```
步骤：两次 addRecipients(TO, [...])
期望：getRecipients(TO).size 累加
angus-mail：addRecipients(RecipientType, Address[])
优先级：P0
```

### TC-MESSAGE-007 getAllRecipients 合并 TO+CC+BCC
```
步骤：分别设 TO(1)、CC(1)、BCC(1)
      msg.getAllRecipients()
期望：size==3
angus-mail：getAllRecipients()
优先级：P0
```

### TC-MESSAGE-008 setSubject ASCII
```
步骤：msg.setSubject("Hello World"); msg.getSubject()
期望：Some("Hello World")
angus-mail：setSubject(String)
优先级：P0
```

### TC-MESSAGE-009 setSubject 含中文（存储原文，序列化时编码）
```
步骤：msg.setSubject("你好世界"); saveChanges()
      msg.getMessageString().contains("Subject:")
期望：true（Subject 行存在，值非空）
优先级：P1
```

### TC-MESSAGE-010 setSentDate / getSentDate
```
步骤：val dt = DateTime.now(); msg.setSentDate(dt); msg.getSentDate()
期望：Some(dt)
angus-mail：setSentDate(Date)
优先级：P1
```

### TC-MESSAGE-011 saveChanges 自动生成 Date
```
步骤：不调 setSentDate，调 saveChanges()
期望：getSentDate().isSome()==true（自动填充当前时间）
angus-mail：saveChanges() auto-fills Date
优先级：P1
```

### TC-MESSAGE-012 getReplyTo 默认返回 From
```
步骤：msg.setFrom(a@b.com); msg.getReplyTo()
期望：返回 From 地址（未显式设 Reply-To 时）
angus-mail：getReplyTo() falls back to From
优先级：P1
```

### TC-MESSAGE-013 setReplyTo 覆盖默认
```
步骤：msg.setReplyTo([reply@example.com])
      msg.getReplyTo()[0].getAddress()
期望："reply@example.com"
优先级：P1
```

### TC-MESSAGE-014 setText 纯文本
```
步骤：msg.setText("Hello"); msg.getContent()
期望：Some("Hello")，getContentType().startsWith("text/plain")
angus-mail：setText(String)
优先级：P0
```

### TC-MESSAGE-015 setText 指定字符集
```
步骤：msg.setText("你好", "UTF-8")
      msg.getContentType().contains("charset=UTF-8")
期望：true
angus-mail：setText(String, String)
优先级：P1
```

### TC-MESSAGE-016 setHtmlContent
```
步骤：msg.setHtmlContent("<b>Hi</b>")
      msg.getContentType().startsWith("text/html")
期望：true
优先级：P1
```

### TC-MESSAGE-017 setContent(MimeMultipart) 后 isMultipart
```
步骤：
  val mp = MimeMultipart("mixed")
  mp.addBodyPart(part)
  msg.setContent(mp)
  msg.isMultipart()
期望：true
angus-mail：setContent(Multipart)
优先级：P0
```

### TC-MESSAGE-018 setHeader / getHeader
```
步骤：msg.setHeader("X-Custom", "value1"); msg.getHeader("X-Custom")
期望：Some("value1")
angus-mail：setHeader(String, String)
优先级：P1
```

### TC-MESSAGE-019 addHeader 多值
```
步骤：msg.addHeader("X-H", "v1"); msg.addHeader("X-H", "v2")
      msg.getAllHeaders() 中 X-H 出现次数
期望：2
angus-mail：addHeader(String, String)
优先级：P1
```

### TC-MESSAGE-020 removeHeader
```
步骤：msg.setHeader("X-H", "v"); msg.removeHeader("X-H")
      msg.getHeader("X-H")
期望：None
angus-mail：removeHeader(String)
优先级：P1
```

### TC-MESSAGE-021 getAllHeaders 调用 saveChanges
```
步骤：不显式调 saveChanges()，直接调 getAllHeaders()
期望：包含 Date、From、To、Subject、Message-ID 等标准头（隐式 saveChanges）
angus-mail：getAllHeaders() calls saveChanges internally
优先级：P1
```

### TC-MESSAGE-022 getMatchingHeaders 大小写不敏感
```
步骤：设 Subject、From；getMatchingHeaders(["subject", "FROM"])
期望：结果包含 Subject 和 From（不区分大小写）
angus-mail：getMatchingHeaders(Enumeration)
优先级：P2
```

### TC-MESSAGE-023 getNonMatchingHeaders
```
步骤：getNonMatchingHeaders(["Subject"])
期望：结果不含 Subject，含其他头
angus-mail：getNonMatchingHeaders(Enumeration)
优先级：P2
```

### TC-MESSAGE-024 Message-ID 自动生成
```
步骤：val msg = MimeMessage(session); msg.getMessageID()
期望：Some，且值以 "<" 开头、">" 结尾、含 "@"
angus-mail：MimeMessage 在创建时自动生成 Message-ID
优先级：P1
```

### TC-MESSAGE-025 复制构造生成新 Message-ID
```
步骤：
  val orig = MimeMessage(session)
  val copy = MimeMessage(orig)
  orig.getMessageID() != copy.getMessageID()
期望：true（独立副本有不同 ID）
angus-mail：new MimeMessage(MimeMessage)
优先级：P2
```

### TC-MESSAGE-026 复制构造字段保留
```
步骤：orig.setSubject("Hello"); orig.setText("Body")
      val copy = MimeMessage(orig)
期望：copy.getSubject()==Some("Hello")，copy.getContent()==Some("Body")
优先级：P2
```

### TC-MESSAGE-027 getMessageString BCC 不出现在正文头
```
步骤：msg.setRecipients(BCC, [bcc@example.com])
      msg.saveChanges()
      msg.getMessageString(["Bcc"]).contains("bcc@example.com")
期望：false（BCC 被过滤）
angus-mail：writeTo(OutputStream) omits Bcc
优先级：P0（安全相关）
```

### TC-MESSAGE-028 writeTo(OutputStream) 可往返序列化
```
步骤：
  msg.setSubject("Test"); msg.setText("Body")
  msg.writeTo(output)
  val str = output.toString()
期望：含 "Subject: Test"、含 "Body"
angus-mail：writeTo(OutputStream)
优先级：P0
```

### TC-MESSAGE-029 writeTo(OutputStream, ignoreHeaders) 指定过滤
```
步骤：msg.setHeader("X-Secret", "hidden")
      msg.writeTo(output, ["X-Secret"])
期望：输出不含 "X-Secret"
angus-mail：writeTo(OutputStream, String[])
优先级：P1
```

### TC-MESSAGE-030 getSize 估算字节数
```
步骤：msg.setText("Hello World"); msg.saveChanges(); msg.getSize()
期望：> 0，合理的字节数
angus-mail：MimeMessage.getSize()
优先级：P2
```

### TC-MESSAGE-031 reply(false) 生成回复消息
```
步骤：
  orig.setSubject("Hello"); orig.setFrom(a@b.com); orig.setMessageID("<id123>")
  val reply = orig.reply(false)
  reply.getSubject()
  reply.getRecipients(TO)[0].getAddress()
  reply.getHeader("In-Reply-To")
期望：Subject=="Re: Hello"，To=="a@b.com"，In-Reply-To=="<id123>"
angus-mail：reply(boolean)
优先级：P2
```

### TC-MESSAGE-032 reply(true) 保留原 CC
```
步骤：orig.setRecipients(CC, [cc@example.com]); val reply = orig.reply(true)
期望：reply.getRecipients(CC) 包含 cc@example.com
angus-mail：reply(true) keeps original To/Cc in new Cc
优先级：P2
```

### TC-MESSAGE-033 InputStream 构造：解析 RFC 2822 头
```
步骤：
  val raw = "From: sender@example.com\r\nTo: to@example.com\r\n" +
            "Subject: Test\r\nMessage-ID: <abc@host>\r\n\r\nBody"
  val msg = MimeMessage(session, StringInputStream(raw))
  msg.getFrom()[0].getAddress()
  msg.getRecipients(TO)[0].getAddress()
  msg.getSubject()
  msg.getMessageID()
  msg.getContent()
期望：分别为 "sender@example.com"、"to@example.com"、Some("Test")、Some("<abc@host>")、Some("Body")
angus-mail：new MimeMessage(Session, InputStream)
优先级：P2
```

### TC-MESSAGE-034 InputStream 构造：折叠头（Folded Header）
```
步骤：raw 含折叠头：
  "Subject: Very Long\r\n Subject Continuation\r\n\r\nBody"
期望：getSubject() == Some("Very Long Subject Continuation")（折叠已展开）
优先级：P2
```

### TC-MESSAGE-035 InputStream 构造：multipart/mixed 解析
```
步骤：raw 含 boundary，两个 part（text/plain + text/html）
期望：isMultipart()==true，getMultipart().getCount()==2
优先级：P2
```

### TC-MESSAGE-036 InputStream 构造：base64 body 解码
```
步骤：raw 含 Content-Transfer-Encoding: base64，body 为 base64("Hello")
期望：getContent() == Some("Hello")
优先级：P2
```

### TC-MESSAGE-037 InputStream 构造：quoted-printable body 解码
```
步骤：raw 含 CTE: quoted-printable，body 含 =E4=B8=AD 等 QP 序列
期望：getContent() 为解码后的 UTF-8 字符串
优先级：P2
```

### TC-MESSAGE-038 addAttachment 触发 multipart/mixed 转换
```
步骤：
  msg.setText("Body text")
  msg.addAttachment("/path/to/file.pdf")
  msg.isMultipart()
  msg.getMultipart().getCount()
期望：isMultipart()==true，count==2（text part + attachment part）
优先级：P1
```

---

## 四、TC-MULTIPART — MIME 多部分容器（MimeMultipart）

### TC-MULTIPART-001 默认构造子类型为 mixed
```
步骤：MimeMultipart().getSubType()
期望："mixed"
angus-mail：new MimeMultipart()
优先级：P0
```

### TC-MULTIPART-002 指定子类型
```
步骤：MimeMultipart("alternative").getSubType()
期望："alternative"
angus-mail：new MimeMultipart(String)
优先级：P0
```

### TC-MULTIPART-003 addBodyPart / getCount
```
步骤：mp.addBodyPart(part1); mp.addBodyPart(part2)
期望：getCount()==2
优先级：P0
```

### TC-MULTIPART-004 addBodyPart 指定索引
```
步骤：mp.addBodyPart(part1); mp.addBodyPart(part2, 0)（插入最前）
期望：getBodyPart(0) == part2
angus-mail：addBodyPart(BodyPart, int)
优先级：P1
```

### TC-MULTIPART-005 removeBodyPart by index
```
步骤：mp.addBodyPart(p1); mp.addBodyPart(p2); mp.removeBodyPart(0)
期望：getCount()==1，getBodyPart(0) == p2
angus-mail：removeBodyPart(int)
优先级：P1
```

### TC-MULTIPART-006 removeBodyPart by MimeBodyPart（CID 匹配）
```
步骤：p.setContentID("img001"); mp.addBodyPart(p); mp.removeBodyPart(p)
期望：getCount()==0
angus-mail：removeBodyPart(BodyPart)
优先级：P2
```

### TC-MULTIPART-007 getBodyPart by index
```
步骤：mp.addBodyPart(p1); mp.addBodyPart(p2); mp.getBodyPart(1)
期望：返回 p2
angus-mail：getBodyPart(int)
优先级：P0
```

### TC-MULTIPART-008 getBodyPart by contentID
```
步骤：p.setContentID("<img001>"); mp.addBodyPart(p)
      mp.getBodyPart("img001")  // 裸 ID（无尖括号）
      mp.getBodyPart("<img001>") // 带尖括号
期望：两者均返回 Some(p)
angus-mail：getBodyPart(String)
优先级：P2
```

### TC-MULTIPART-009 getBoundary / setBoundary
```
步骤：mp.setBoundary("custom-boundary-123"); mp.getBoundary()
期望：Some("custom-boundary-123")
优先级：P1
```

### TC-MULTIPART-010 自动生成边界唯一性
```
步骤：两个 MimeMultipart() 对象的 getBoundary()
期望：两个边界值不同
优先级：P1
```

### TC-MULTIPART-011 getSubType / setSubType
```
步骤：mp.setSubType("related"); mp.getSubType()
期望："related"
优先级：P1
```

### TC-MULTIPART-012 getPreamble / setPreamble
```
步骤：mp.setPreamble("This is a MIME multipart message"); mp.getPreamble()
期望：Some("This is a MIME multipart message")
angus-mail：getPreamble() / setPreamble(String)
优先级：P2
```

### TC-MULTIPART-013 isComplete（有 part 则为 true）
```
步骤：空 mp → isComplete()；加一个 part 后 → isComplete()
期望：false → true
优先级：P2
```

### TC-MULTIPART-014 writeTo 输出含边界行
```
步骤：mp.addBodyPart(part); mp.writeTo(out); out.toString()
期望：含 "--" + boundary，含两个 "--" + boundary + "--" 结束符
优先级：P1
```

---

## 五、TC-BODYPART — MIME 正文部分（MimeBodyPart）

### TC-BODYPART-001 setText 纯文本
```
步骤：part.setText("Hello"); part.getContentType()
期望：startsWith("text/plain")
angus-mail：setText(String)
优先级：P0
```

### TC-BODYPART-002 setText 指定 charset 和 subtype
```
步骤：part.setText("Hello", "UTF-8", "html")
      part.getContentType()
期望：startsWith("text/html")，含 charset=UTF-8
angus-mail：setText(String, String, String)
优先级：P1
```

### TC-BODYPART-003 setHtmlContent
```
步骤：part.setHtmlContent("<b>Bold</b>"); part.getContentType()
期望：startsWith("text/html")
优先级：P1
```

### TC-BODYPART-004 attachFile 自动 MIME 类型检测
```
步骤：part.attachFile("report.pdf"); part.getContentType()
期望："application/pdf"
步骤2：part.attachFile("image.jpg"); part.getContentType()
期望："image/jpeg"
angus-mail：attachFile(String)
优先级：P1
```

### TC-BODYPART-005 attachFile 文件名中文 RFC 2047 编码
```
步骤：创建包含中文名的路径，attachFile("中文文件.pdf")
      part.getFileName()
期望：Some，值为 RFC 2047 编码字符串（=?UTF-8?B?...?=）
angus-mail：setFileName auto-encodes non-ASCII
优先级：P1
```

### TC-BODYPART-006 setFileName / getFileName
```
步骤：part.setFileName("attachment.txt"); part.getFileName()
期望：Some("attachment.txt")
优先级：P0
```

### TC-BODYPART-007 setDisposition INLINE / ATTACHMENT
```
步骤：part.setDisposition("inline"); part.getDisposition()
期望：Some("inline")
步骤2：part.setDisposition("attachment"); part.getDisposition()
期望：Some("attachment")
angus-mail：setDisposition(String)
优先级：P1
```

### TC-BODYPART-008 setContentID 格式规范化
```
步骤：part.setContentID("img001"); part.getContentID()
期望：Some("<img001>")（自动加尖括号）
步骤2：part.setContentID("<img002>"); part.getContentID()
期望：Some("<img002>")（保持原有格式）
angus-mail：setContentID(String)
优先级：P2
```

### TC-BODYPART-009 setDataHandler
```
步骤：
  val ds = ByteArrayDataSource("data".toArray(), "text/plain")
  val dh = DataHandler(ds)
  part.setDataHandler(dh)
  part.getContentType()
期望：startsWith("text/plain")
angus-mail：setDataHandler(DataHandler)
优先级：P1
```

### TC-BODYPART-010 getContent 返回文本字符串
```
步骤：part.setText("Hello"); part.getContent()
期望：Some("Hello")
angus-mail：getContent()
优先级：P1
```

### TC-BODYPART-011 getSize 有内容时 > 0
```
步骤：part.setText("Hello World"); part.getSize()
期望：> 0
angus-mail：getSize()
优先级：P2
```

### TC-BODYPART-012 isMimeType 精确匹配
```
步骤：part.setText("Hi"); part.isMimeType("text/plain")
期望：true
步骤2：part.isMimeType("text/*")
期望：true
步骤3：part.isMimeType("text/html")
期望：false
angus-mail：isMimeType(String)
优先级：P1
```

### TC-BODYPART-013 writeTo 输出含头和正文
```
步骤：part.setText("Body"); part.writeTo(out)
期望：输出含 Content-Type 头行和 "Body"
优先级：P1
```

### TC-BODYPART-014 createInlineImageBodyPart
```
步骤：createInlineImageBodyPart("logo.jpg", "logo_cid")
      part.getContentID()
      part.getDisposition()
期望：Some("<logo_cid>")，Some("inline")
优先级：P2
```

---

## 六、TC-AUTH — SMTP 认证机制

### TC-AUTH-001 AUTH LOGIN 协议流程
```
前置：模拟服务器返回 334（username:）、334（password:）、235
步骤：LoginMechanism().execute(ctx)
期望：ctx.sendCommand 依次调用 "AUTH LOGIN"、base64(user)、base64(password)
      最终返回 true
angus-mail：LOGIN SASL
优先级：P0
```

### TC-AUTH-002 AUTH LOGIN 失败抛异常
```
前置：服务器最终返回 535
期望：抛 AuthenticationFailedException
优先级：P0
```

### TC-AUTH-003 AUTH PLAIN 一步发送
```
步骤：PlainMechanism().execute(ctx)
期望：sendCommand 调用一次 "AUTH PLAIN " + base64("\0user\0password")
angus-mail：PLAIN SASL
优先级：P0
```

### TC-AUTH-004 AUTH XOAUTH2 Bearer Token
```
步骤：ctx.oauthToken = Some("access_token")
      XOAuth2Mechanism().execute(ctx)
期望：sendCommand 含 "AUTH XOAUTH2"，base64 值包含 "auth=Bearer access_token"
angus-mail：XOAUTH2 SASL
优先级：P1
```

### TC-AUTH-005 AUTH XOAUTH2 服务器 334 错误应答
```
前置：服务器先返回 334（错误 JSON），再返回 535
步骤：XOAuth2Mechanism().execute(ctx)
期望：发送空响应后抛 AuthenticationFailedException
优先级：P1
```

### TC-AUTH-006 AUTH NTLM Type1/2/3 三步握手
```
步骤：NtlmMechanism().execute(ctx) 模拟
期望：
  第一次 sendCommand 含 "AUTH NTLM"
  第二次 sendCommand 含 Type1 base64（"NTLMSSP\0"开头）
  第三次 sendCommand 含 Type3 base64（解析 Type2 后计算 NTLMv2 响应）
  最终返回 true
angus-mail：NTLM SASL
优先级：P1
```

### TC-AUTH-007 AUTH DIGEST-MD5 挑战-响应
```
步骤：
  服务器返回 334 <base64(realm="example.com",nonce="abc",algorithm=md5-sess,qop="auth")>
  DigestMd5Mechanism().execute(ctx)
期望：
  发送 "AUTH DIGEST-MD5"
  第二步发送 base64 响应，含 username、realm、nonce、cnonce、response（32字节十六进制）
  最终返回 true
angus-mail：DIGEST-MD5 SASL
优先级：P2
```

### TC-AUTH-008 默认认证优先级
```
步骤：服务器 EHLO 声明支持 LOGIN、PLAIN、NTLM、DIGEST-MD5、XOAUTH2
      AuthMechanismSelector 选择机制（无 configMechs）
期望：选择 XOAUTH2（有 token 时）或 NTLM > DIGEST-MD5 > LOGIN > PLAIN
angus-mail：SMTPTransport 的机制选择顺序
优先级：P1
```

### TC-AUTH-009 mail.smtp.auth.mechanisms 自定义优先级
```
步骤：configMechs = "PLAIN LOGIN"
      服务器支持 NTLM、LOGIN、PLAIN
      AuthMechanismSelector 选择结果
期望：选择 PLAIN（配置列表中第一个且服务器支持）
优先级：P1
```

### TC-AUTH-010 禁用特定机制
```
步骤：authDisabledMechanisms 含 "LOGIN"；服务器只声明 LOGIN
      AuthMechanismSelector.authenticate(...)
期望：抛 AuthenticationFailedException（无可用机制）
angus-mail：mail.smtp.auth.login.disable=true
优先级：P1
```

### TC-AUTH-011 服务器未声明 AUTH 时尝试全部
```
步骤：serverMechs 为空，configMechs = None
      ctx 有 user+password，无 oauthToken
期望：尝试 NTLM 或 DIGEST-MD5 或 LOGIN（不跳过）
优先级：P2
```

### TC-AUTH-012 无凭证时不调用 authenticate
```
步骤：connect(host, port, user="", password="") 且无 Authenticator
期望：不发送 AUTH 命令，EHLO 后直接发送 MAIL FROM
angus-mail：无 user/password 时跳过认证
优先级：P1
```

---

## 七、TC-TRANSPORT — SMTP 传输行为

### TC-TRANSPORT-001 connect 建立 TCP 连接并读取 220 问候语
```
前置：本地 mock SMTP 服务器监听
步骤：transport.connect(host, port, user, password)
      transport.isConnected()
期望：true
angus-mail：Transport.connect(String, int, String, String)
优先级：P0
```

### TC-TRANSPORT-002 connect 拒绝连接抛 MailConnectException
```
前置：目标端口无监听
期望：抛 MailConnectException（含 host、port 信息）
angus-mail：MailConnectException
优先级：P0
```

### TC-TRANSPORT-003 STARTTLS 升级（明文 → TLS）
```
前置：服务器 EHLO 声明 STARTTLS；mail.smtp.starttls.enable=true
步骤：connect 成功后 isConnected()==true
      验证后续通信走 TLS socket（不走原始 fd）
angus-mail：STARTTLS upgrade
优先级：P0
```

### TC-TRANSPORT-004 STARTTLS 必须但不支持时抛异常
```
前置：mail.smtp.starttls.required=true；服务器不声明 STARTTLS
期望：抛 MessagingException（含 "STARTTLS" 关键字）
优先级：P1
```

### TC-TRANSPORT-005 连接超时配置（mail.smtp.connectiontimeout）
```
步骤：配置 connectiontimeout=500；连接不可达地址（如 192.0.2.1:25）
期望：约 500ms 内抛 MailConnectException（不挂死）
angus-mail：mail.smtp.connectiontimeout
优先级：P0
```

### TC-TRANSPORT-006 isConnected 未连接时为 false
```
步骤：新建 SMTPTransport；transport.isConnected()
期望：false
优先级：P0
```

### TC-TRANSPORT-007 close 发送 QUIT
```
前置：已连接
步骤：transport.close()；transport.isConnected()
期望：false；服务器收到 QUIT 命令
angus-mail：Transport.close()
优先级：P0
```

### TC-TRANSPORT-008 quitWait=false 不等待 221 响应
```
步骤：props["mail.smtp.quitwait"]="false"；close()
期望：正常关闭，不等服务器 221 响应（性能场景）
angus-mail：mail.smtp.quitwait
优先级：P2
```

### TC-TRANSPORT-009 noop 未连接返回 false
```
步骤：new SMTPTransport().noop()
期望：false（不抛异常）
angus-mail：SMTPTransport.noop()
优先级：P2
```

### TC-TRANSPORT-010 noop 已连接返回 250 → true
```
前置：已连接，服务器正常
步骤：transport.noop()
期望：true
优先级：P2
```

### TC-TRANSPORT-011 sendMessage 单收件人成功路径
```
步骤：
  msg.setFrom(a); msg.setRecipients(TO,[b]); msg.setText("Hi")
  transport.sendMessage(msg, msg.getAllRecipients())
期望：服务器收到完整的 MAIL FROM、RCPT TO、DATA、邮件正文、250 OK
      NotifyTransportListener.DELIVERED 事件触发
angus-mail：Transport.sendMessage(Message, Address[])
优先级：P0
```

### TC-TRANSPORT-012 sendMessage 多收件人（TO + CC + BCC）
```
步骤：TO(2)+CC(1)+BCC(1)；sendMessage(msg, getAllRecipients())
期望：服务器收到 4 条 RCPT TO；DATA 正文中无 Bcc 头
优先级：P0
```

### TC-TRANSPORT-013 sendMessage BCC 头不出现在 DATA 正文
```
步骤：setRecipients(BCC,[bcc@x.com])；sendMessage
期望：服务器接收到的 DATA 内容不含 "Bcc: bcc@x.com"
angus-mail：sendMessage strips Bcc
优先级：P0（安全性）
```

### TC-TRANSPORT-014 sendPartial=false 部分收件人失败抛异常
```
前置：服务器对 invalid@bad.com 返回 550
步骤：addresses=[valid@ok.com, invalid@bad.com]
      sendMessage(msg, addresses)
期望：抛 SMTPSendFailedException，含 validSent 和 invalid 地址列表
angus-mail：sendPartial=false（默认行为）
优先级：P0
```

### TC-TRANSPORT-015 sendPartial=true 部分失败继续
```
步骤：同上，但 props["mail.smtp.sendpartial"]="true"
期望：不抛异常，valid 地址发送成功，DELIVERED/PARTIALLY_DELIVERED 事件
angus-mail：mail.smtp.sendpartial=true
优先级：P1
```

### TC-TRANSPORT-016 所有收件人失败抛 SMTPSendFailedException
```
步骤：所有 RCPT TO 返回 5xx
期望：抛 SMTPSendFailedException，validSent 为空
优先级：P0
```

### TC-TRANSPORT-017 sendMessage 未连接抛 MessagingException
```
步骤：直接调 sendMessage（不先 connect）
期望：抛 MessagingException（含 "未连接" 或类似信息）
优先级：P0
```

### TC-TRANSPORT-018 PIPELINING 批量命令路径
```
前置：EHLO 声明 PIPELINING，不声明 CHUNKING
步骤：sendMessage 内部选择 sendMessagePipelined
期望：
  服务器在一次 TCP 读取中收到 MAIL FROM + 所有 RCPT TO + DATA
  响应后正文正确发送
  最终 250 OK
angus-mail：SMTPTransport pipelining support
优先级：P1
```

### TC-TRANSPORT-019 BDAT/CHUNKING 分块路径
```
前置：EHLO 声明 CHUNKING
步骤：sendMessage；内部选 sendDataBdat
期望：服务器收到 "BDAT <n> LAST" 命令及正文字节
      最终 250 OK；无 DATA 命令
angus-mail：CHUNKING extension
优先级：P2
```

### TC-TRANSPORT-020 Transport.send() 静态方法
```
步骤：Transport.send(msg)
期望：一次性完成 connect → sendMessage → close
angus-mail：Transport.send(Message)
优先级：P1
```

### TC-TRANSPORT-021 TransportListener DELIVERED
```
步骤：注册 listener；sendMessage 全部成功
期望：messageDelivered 被调用，validSentAddresses 非空，invalidAddresses 为空
angus-mail：TransportListener.messageDelivered
优先级：P2
```

### TC-TRANSPORT-022 TransportListener PARTIALLY_DELIVERED
```
步骤：sendPartial=true；部分收件人失败
期望：messagePartiallyDelivered 被调用
优先级：P2
```

### TC-TRANSPORT-023 ConnectionListener OPENED / CLOSED
```
步骤：注册 listener；connect → close
期望：opened() 在 connect 后调用；closed() 在 close 后调用
angus-mail：ConnectionListener
优先级：P2
```

### TC-TRANSPORT-024 supportsExtension 大小写不敏感
```
步骤：EHLO 响应含 "STARTTLS"
      transport.supportsExtension("starttls")
期望：true
angus-mail：SMTPTransport.supportsExtension(String)
优先级：P1
```

---

## 八、TC-SMTPMSG — SMTPMessage 信封扩展

### TC-SMTPMSG-001 setEnvelopeFrom 与 From 头分离
```
步骤：
  msg.setFrom(InternetAddress("marketing@corp.com"))
  msg.setEnvelopeFrom("bounce@corp.com")
  MAIL FROM 命令的地址
期望：MAIL FROM:<bounce@corp.com>，而 From 头仍为 marketing@corp.com
angus-mail：SMTPMessage.setEnvelopeFrom(String)
优先级：P2
```

### TC-SMTPMSG-002 setNotifyOptions 位掩码正确
```
步骤：
  msg.setNotifyOptions(NOTIFY_SUCCESS | NOTIFY_FAILURE)
  msg.getNotifyOptions()
期望：getNotifyOptions() == 3（0x01 | 0x02）
angus-mail：setNotifyOptions(int)
优先级：P2
```

### TC-SMTPMSG-003 setNotifyOptions → RCPT TO NOTIFY= 参数
```
前置：服务器 EHLO 声明 DSN
步骤：msg.setNotifyOptions(NOTIFY_SUCCESS | NOTIFY_FAILURE | NOTIFY_DELAY)
      发送时 RCPT TO 命令
期望：RCPT TO:<addr> NOTIFY=SUCCESS,FAILURE,DELAY
angus-mail：DSN NOTIFY
优先级：P2
```

### TC-SMTPMSG-004 setReturnOption RETURN_HDRS → MAIL FROM RET=HDRS
```
前置：服务器 EHLO 声明 DSN
步骤：msg.setReturnOption(RETURN_HDRS)
期望：MAIL FROM:<addr> RET=HDRS
angus-mail：DSN RET
优先级：P2
```

### TC-SMTPMSG-005 setEnvelopeId → MAIL FROM ENVID=
```
前置：服务器声明 DSN
步骤：msg.setEnvelopeId("TXID-20260601-001")
期望：MAIL FROM:<addr> ENVID=TXID-20260601-001
angus-mail：DSN ENVID
优先级：P2
```

### TC-SMTPMSG-006 setAllow8bitMIME → MAIL FROM BODY=8BITMIME
```
前置：服务器声明 8BITMIME
步骤：msg.setAllow8bitMIME(true)
期望：MAIL FROM:<addr> BODY=8BITMIME
angus-mail：SMTPMessage.setAllow8bitMIME
优先级：P2
```

### TC-SMTPMSG-007 setSmtpUtf8 → MAIL FROM SMTPUTF8
```
前置：服务器声明 SMTPUTF8
步骤：msg.setSmtpUtf8(true)
期望：MAIL FROM:<addr> SMTPUTF8
angus-mail：SMTPUTF8 extension
优先级：P2
```

### TC-SMTPMSG-008 setSendPartial 消息级优先于 Transport 级
```
步骤：transport._sendPartial=false；msg.setSendPartial(true)
      部分收件人失败时
期望：遵循消息级 sendPartial=true，不抛异常
angus-mail：SMTPMessage.setSendPartial
优先级：P2
```

### TC-SMTPMSG-009 setMailExtension 自定义 MAIL FROM 参数
```
步骤：msg.setMailExtension("SIZE=12345")
期望：MAIL FROM:<addr> SIZE=12345
优先级：P2
```

### TC-SMTPMSG-010 SMTPMessage(source: MimeMessage) 复制构造
```
步骤：
  val mime = MimeMessage(session); mime.setSubject("Test")
  val smtp = SMTPMessage(mime)
  smtp.getSubject()
期望：Some("Test")；新的 Message-ID
angus-mail：new SMTPMessage(MimeMessage)
优先级：P2
```

---

## 九、TC-PROTOCOL — SMTP 协议命令正确性

### TC-PROTOCOL-001 MAIL FROM 地址格式
```
期望："MAIL FROM:<sender@example.com>" （含尖括号）
优先级：P0
```

### TC-PROTOCOL-002 MAIL FROM + SIZE 参数
```
前置：服务器声明 SIZE 扩展
期望："MAIL FROM:<addr> SIZE=<n>"，n 为消息估算字节数
angus-mail：SIZE extension
优先级：P1
```

### TC-PROTOCOL-003 MAIL FROM SIZE 超限抛异常
```
前置：服务器声明 SIZE=1024；消息大于 1024 字节
期望：抛 MessagingException（含 "超过服务器限制"）；不发 MAIL FROM
优先级：P1
```

### TC-PROTOCOL-004 MAIL FROM + BODY=8BITMIME
```
前置：服务器声明 8BITMIME；allow8bitMIME=true
期望："MAIL FROM:<addr> BODY=8BITMIME"
angus-mail：8BITMIME extension
优先级：P2
```

### TC-PROTOCOL-005 RCPT TO 地址格式
```
期望："RCPT TO:<recipient@example.com>" （含尖括号）
优先级：P0
```

### TC-PROTOCOL-006 DATA 后点填充（dot-stuffing）
```
步骤：正文含以 "." 开头的行（如 ".hidden"）
期望：DATA 正文中对应行变为 "..hidden"（前置额外 "."）
angus-mail：RFC 5321 dot-stuffing
优先级：P0（协议正确性）
```

### TC-PROTOCOL-007 DATA 结束符
```
期望：正文最后一行为 ".\r\n"（单独一个点）
优先级：P0
```

### TC-PROTOCOL-008 BDAT 单块（小消息）
```
前置：服务器声明 CHUNKING
步骤：消息 < 64KB
期望：发送 "BDAT <n> LAST\r\n" 后紧跟 n 字节原始内容；无点填充
angus-mail：BDAT single chunk
优先级：P2
```

### TC-PROTOCOL-009 BDAT 多块（大消息）
```
前置：服务器声明 CHUNKING；mail.smtp.chunksize=4096；消息 > 4096 字节
期望：
  多次 "BDAT 4096\r\n<chunk>" + 最后 "BDAT <n> LAST\r\n<chunk>"
  每块后服务器返回 250
angus-mail：BDAT multi-chunk
优先级：P2
```

### TC-PROTOCOL-010 PIPELINING 批量写出
```
前置：服务器声明 PIPELINING，不声明 CHUNKING
步骤：sendMessage(msg, [a, b, c])
期望（socket 层面）：
  一次写出 "MAIL FROM:...\r\nRCPT TO:<a>\r\nRCPT TO:<b>\r\nRCPT TO:<c>\r\nDATA\r\n"
  再读 5 个响应（250×4 + 354）
优先级：P1
```

### TC-PROTOCOL-011 EHLO 扩展解析
```
步骤：模拟 EHLO 响应：
  250-SIZE 10240000
  250-AUTH LOGIN PLAIN NTLM
  250-8BITMIME
  250-PIPELINING
  250 DSN
期望：
  supportsExtension("SIZE")==true，getExtensionParameter("SIZE")==Some("10240000")
  serverAuthMechanisms 含 "LOGIN"、"PLAIN"、"NTLM"
  supportsExtension("8BITMIME")==true
  supportsExtension("PIPELINING")==true
  supportsExtension("DSN")==true
优先级：P0
```

### TC-PROTOCOL-012 STARTTLS 后重新 EHLO
```
步骤：STARTTLS 升级成功后，检查 _extMap 和 _serverAuthMechanisms
期望：被清空并重新填充（RFC 要求 STARTTLS 后重新协商扩展）
angus-mail：STARTTLS 后 re-issue EHLO
优先级：P1
```

### TC-PROTOCOL-013 HELO 回退（EHLO 失败时）
```
前置：服务器对 EHLO 返回 5xx
步骤：connect()
期望：Transport 自动发送 HELO 命令，连接成功建立
angus-mail：HELO fallback
优先级：P1
```

### TC-PROTOCOL-014 多行 EHLO 响应正确解析
```
步骤：EHLO 响应含 "250-" 开头的延续行
期望：所有扩展均被解析，不因 "-" 截断而遗漏
优先级：P1
```

### TC-PROTOCOL-015 增强状态码（RFC 2034）解析
```
步骤：服务器响应 "250 2.1.5 Recipient accepted"
      transport.getLastEnhancedStatus()
期望："2.1.5"
angus-mail：getLastEnhancedStatus()
优先级：P2
```

### TC-PROTOCOL-016 quitOnSessionReject=true（问候拒绝时发 QUIT）
```
前置：服务器问候语为 550（拒绝）；quitOnSessionReject=true
步骤：connect()
期望：Transport 在抛 MessagingException 前发送 QUIT
angus-mail：mail.smtp.quitonsessionreject
优先级：P1
```

### TC-PROTOCOL-017 RCPT TO 返回 251（转发）视为成功
```
步骤：服务器对 RCPT TO 返回 251（Forwarded）
期望：地址被加入 validSent，不被计为失败
angus-mail：251 is a success response
优先级：P1
```

### TC-PROTOCOL-018 MAIL FROM + SMTPUTF8 + DSN 组合
```
前置：服务器声明 SMTPUTF8 和 DSN
步骤：msg.setSmtpUtf8(true); msg.setReturnOption(RETURN_HDRS); msg.setEnvelopeId("ID-001")
期望：MAIL FROM:<addr> SMTPUTF8 RET=HDRS ENVID=ID-001
优先级：P2
```

---

## 十、TC-ERROR — 错误与异常处理

### TC-ERROR-001 发件人拒绝（MAIL FROM 5xx）→ SMTPSenderFailedException
```
前置：服务器对 MAIL FROM 返回 550
期望：抛 SMTPSenderFailedException，含 address、returnCode
angus-mail：SMTPSenderFailedException
优先级：P0
```

### TC-ERROR-002 收件人拒绝（RCPT TO 5xx）→ SMTPAddressFailedException
```
前置：服务器对某 RCPT TO 返回 550
期望：抛 SMTPAddressFailedException，含 address、returnCode
angus-mail：SMTPAddressFailedException
优先级：P0
```

### TC-ERROR-003 DATA 拒绝（354 以外）→ SMTPSendFailedException
```
前置：服务器对 DATA 返回 503
期望：抛 SMTPSendFailedException，command=="DATA"
优先级：P0
```

### TC-ERROR-004 DATA END 拒绝（250 以外）→ SMTPSendFailedException
```
前置：DATA 体发完后服务器返回 554（拒绝）
期望：抛 SMTPSendFailedException，command=="DATA END"
优先级：P0
```

### TC-ERROR-005 全部收件人无效 → SMTPSendFailedException（validSent 为空）
```
期望：validSent==[]，invalidAddresses 包含全部地址
优先级：P0
```

### TC-ERROR-006 认证失败 → AuthenticationFailedException
```
前置：服务器对 AUTH LOGIN 最终返回 535
期望：抛 AuthenticationFailedException
优先级：P0
```

### TC-ERROR-007 connect 失败后 isConnected 为 false
```
步骤：connect() 异常后 isConnected()
期望：false（连接状态正确重置）
优先级：P0
```

### TC-ERROR-008 connect 失败后资源清理
```
步骤：connect() 抛异常后，重新 connect 成功
期望：_rawFd 正确清理，无资源泄漏迹象（第二次能成功）
angus-mail：cleanupConnections() on failure
优先级：P1
```

### TC-ERROR-009 消息大小超限（服务器 SIZE）
```
步骤：getExtensionParameter("SIZE")=="1024"；消息 > 1024 字节
期望：抛 MessagingException，不发送 MAIL FROM
优先级：P1
```

### TC-ERROR-010 MAIL FROM 失败后 PIPELINING 响应排空
```
前置：PIPELINING 模式；MAIL FROM 返回 5xx
步骤：sendMessage
期望：抛 SMTPSenderFailedException；所有已写出的 RCPT TO + DATA 响应被读取完毕
      不影响后续 sendMessage 调用（连接可复用）
优先级：P1
```

### TC-ERROR-011 PIPELINING 所有 RCPT TO 失败后中止 DATA
```
前置：PIPELINING；全部 RCPT TO 返回 5xx；DATA 返回 354
步骤：sendMessage
期望：发送空体（".\r\n"）中止事务后抛 SMTPSendFailedException
优先级：P1
```

### TC-ERROR-012 STARTTLS 要求但 TLS 握手失败
```
前置：STARTTLS 服务器响应 220 但 TLS 握手失败
期望：抛 MessagingException（含 "TLS 握手失败" 或类似）；连接清理
优先级：P1
```

---

## 十一、TC-CRYPTO — 加密工具（CryptoUtil）

### TC-CRYPTO-001 MD4 哈希（NTLM NT hash）
```
步骤：CryptoUtil.md4(CryptoUtil.toUtf16LE("Password"))
期望：长度 16 字节；结果与 RFC 1320 测试向量一致
优先级：P1
```

### TC-CRYPTO-002 MD5 哈希（标准向量）
```
步骤：CryptoUtil.md5("".toArray())
期望：hexEncode == "d41d8cd98f00b204e9800998ecf8427e"（空串 MD5）
步骤2：CryptoUtil.md5("abc".toArray())
期望：hexEncode == "900150983cd24fb0d6963f7d28e17f72"
优先级：P1
```

### TC-CRYPTO-003 HMAC-MD5（RFC 2104 测试向量）
```
步骤：key = 0x0b×20，data = "Hi There"
      hexEncode(CryptoUtil.hmacMd5(key, data))
期望："9294727a3811050de6c7b413a8b43b5" 等 RFC 测试向量（可选，至少验证长度 16）
优先级：P1
```

### TC-CRYPTO-004 hexEncode 正确性
```
步骤：CryptoUtil.hexEncode([0x00, 0xFF, 0xAB])
期望："00ffab"（小写）
优先级：P1
```

### TC-CRYPTO-005 hexEncode 空数组
```
步骤：CryptoUtil.hexEncode([])
期望：""
优先级：P2
```

### TC-CRYPTO-006 toUtf16LE ASCII
```
步骤：CryptoUtil.toUtf16LE("AB")
期望：[0x41, 0x00, 0x42, 0x00]
优先级：P1
```

### TC-CRYPTO-007 toUtf16LE 非 ASCII
```
步骤：CryptoUtil.toUtf16LE("中")（U+4E2D）
期望：[0x2D, 0x4E]（little-endian）
优先级：P1
```

### TC-CRYPTO-008 randomBytes 长度和唯一性
```
步骤：两次 CryptoUtil.randomBytes(16)
期望：各长度==16；两次结果不同（概率极高）
优先级：P2
```

---

## 十二、TC-BASE64 — Base64 编解码工具

### TC-BASE64-001 encode 基本
```
步骤：Base64Util.encode("Hello".toArray())
期望："SGVsbG8="
优先级：P0
```

### TC-BASE64-002 encode 空数组
```
步骤：Base64Util.encode([])
期望：""
优先级：P1
```

### TC-BASE64-003 decode 基本
```
步骤：Base64Util.decode("SGVsbG8=")
期望：[72,101,108,108,111]（"Hello"）
优先级：P0
```

### TC-BASE64-004 decodeToString 往返
```
步骤：Base64Util.decodeToString(Base64Util.encodeString("你好世界"))
期望："你好世界"
优先级：P1
```

### TC-BASE64-005 encode / decode 大数据往返
```
步骤：1024 字节随机数据；encode 后 decode
期望：结果与原始数据相同
优先级：P1
```

### TC-BASE64-006 decode 忽略空白和填充
```
步骤：Base64Util.decode("S G V s b G 8 =")（含空格）
期望：与 decode("SGVsbG8=") 相同
优先级：P2
```

---

## 十三、TC-MIMEUTIL — MIME 编码工具（MimeUtility）

### TC-MIMEUTIL-001 encodeWord ASCII 不编码
```
步骤：MimeUtility.encodeWord("Hello World")
期望："Hello World"（无 =?...?= 包装）
angus-mail：MimeUtility.encodeWord(String)
优先级：P1
```

### TC-MIMEUTIL-002 encodeWord 中文 Base64
```
步骤：MimeUtility.encodeWord("你好", charset:"UTF-8", encoding:Some("B"))
期望：以 "=?UTF-8?B?" 开头，以 "?=" 结尾
angus-mail：MimeUtility.encodeWord(String, String, String)
优先级：P1
```

### TC-MIMEUTIL-003 decodeWord 还原
```
步骤：MimeUtility.decodeWord("=?UTF-8?B?5L2g5aW9?=")
期望：原始中文字符串（"你好"）
angus-mail：MimeUtility.decodeWord(String)
优先级：P1
```

### TC-MIMEUTIL-004 encodeText / decodeText 往返
```
步骤：
  val encoded = MimeUtility.encodeText("日本語テスト", charset:"UTF-8", encoding:Some("B"))
  MimeUtility.decodeText(encoded)
期望："日本語テスト"
angus-mail：encodeText / decodeText
优先级：P1
```

### TC-MIMEUTIL-005 encodeWord 特殊字符（= 和 ?）
```
步骤：MimeUtility.encodeWord("a=b?c")
期望：触发编码（含 =?...?=），因为 = 和 ? 是 RFC 2047 保留字符
优先级：P1
```

### TC-MIMEUTIL-006 fold 长头部折叠
```
步骤：超过 76 字符的头值通过 fold 处理
期望：输出在 CRLF+WSP 处换行，每行 ≤ 998 字符
angus-mail：MimeUtility.fold(int, String)
优先级：P2
```

### TC-MIMEUTIL-007 unfold 去除折叠换行
```
步骤：MimeUtility.unfold("Subject: Long\r\n Subject")
期望："Subject: Long Subject"（CRLF+WSP 被移除）
angus-mail：MimeUtility.unfold(String)
优先级：P2
```

### TC-MIMEUTIL-008 Quoted-Printable encodeWord
```
步骤：MimeUtility.encodeWord("café", charset:"UTF-8", encoding:Some("Q"))
期望：含 "?Q?" 的编码字符串；decodeWord 还原为 "café"
优先级：P2
```

---

## 附录 A — 测试执行建议

### A.1 单元测试（离线）
以下模块可**无需真实 SMTP 服务器**直接运行：
- TC-ADDRESS、TC-MESSAGE、TC-MULTIPART、TC-BODYPART（消息构造序列化）
- TC-AUTH（认证算法逻辑，使用 mock ctx）
- TC-SMTPMSG（SMTPMessage 字段）
- TC-CRYPTO、TC-BASE64、TC-MIMEUTIL（工具类）
- TC-TRANSPORT-006、TC-TRANSPORT-009（isConnected/noop 离线状态）

### A.2 集成测试（需 SMTP 服务器）
以下模块需要真实或 mock SMTP 服务器：
- TC-SESSION-008（Transport 工厂）
- TC-TRANSPORT-001~TC-TRANSPORT-024（连接、发送、事件）
- TC-PROTOCOL-001~TC-PROTOCOL-018（协议命令验证）
- TC-ERROR（错误处理）

**推荐工具**：[GreenMail](https://greenmail-mail-test.github.io/greenmail/) 或 [smtp4dev](https://github.com/rnwood/smtp4dev) 作为本地 mock 服务器。

### A.3 优先级执行顺序
```
P0（必须通过） → P1（强烈建议） → P2（完善性）
```

| 优先级 | 用例数 | 说明 |
|--------|--------|------|
| P0 | 约 45 项 | 协议正确性、安全性、基本可用性 |
| P1 | 约 85 项 | 兼容性、配置覆盖 |
| P2 | 约 59 项 | 完善性、边缘场景 |

---

## 附录 B — angus-mail 对标索引

| mail-cj API | angus-mail 对应 | 测试用例 |
|-------------|----------------|---------|
| `Session.getInstance(HashMap)` | `Session.getInstance(Properties)` | TC-SESSION-001 |
| `MimeMessage(Session, InputStream)` | `new MimeMessage(Session, InputStream)` | TC-MESSAGE-033~037 |
| `MimeMessage(source)` | `new MimeMessage(MimeMessage)` | TC-MESSAGE-025~026 |
| `Transport.send(msg)` | `Transport.send(Message)` | TC-TRANSPORT-020 |
| `SMTPMessage.setEnvelopeFrom` | `SMTPMessage.setEnvelopeFrom` | TC-SMTPMSG-001 |
| `SMTPMessage.setNotifyOptions` | `SMTPMessage.setNotifyOptions` | TC-SMTPMSG-002~003 |
| `SMTPMessage.setEnvelopeId` | `SMTPMessage.setEnvelopeId` (DSN ENVID=) | TC-SMTPMSG-005 |
| `SMTPMessage.setSmtpUtf8` | SMTPUTF8 extension | TC-SMTPMSG-007 |
| `sendDataBdat` | CHUNKING/BDAT (RFC 3030) | TC-TRANSPORT-019, TC-PROTOCOL-008~009 |
| `sendMessagePipelined` | PIPELINING (RFC 2920) | TC-TRANSPORT-018, TC-PROTOCOL-010 |
| `DigestMd5Mechanism` | DIGEST-MD5 SASL | TC-AUTH-007 |
| `CryptoUtil.hexEncode` | (内部) | TC-CRYPTO-004~005 |
| `notifyTransportListeners` | `TransportListener` events | TC-TRANSPORT-021~022 |
| `notifyConnectionOpened/Closed` | `ConnectionListener` events | TC-TRANSPORT-023 |
