/**
 * MIME 消息实现
 */
package mail.internet

import mail.core.*
import mail.util.*
import std.collection.*
import std.time.*
import std.io.*
import std.random.*

/**
 * MIME 消息实现
 * 对应：jakarta.mail.internet.MimeMessage
 */
public open class MimeMessage <: Message {
    protected var _headers: InternetHeaders = InternetHeaders()
    protected var _content: ?String = None
    protected var _contentType: String = "text/plain; charset=UTF-8"
    protected var _multipart: ?MimeMultipart = None
    protected var _subject: ?String = None
    protected var _from: ArrayList<Address> = ArrayList<Address>()
    protected var _to: ArrayList<Address> = ArrayList<Address>()
    protected var _cc: ArrayList<Address> = ArrayList<Address>()
    protected var _bcc: ArrayList<Address> = ArrayList<Address>()
    protected var _replyTo: ArrayList<Address> = ArrayList<Address>()
    protected var _sentDate: ?DateTime = None
    protected var _messageId: ?String = None
    protected var _saved: Bool = false
    protected var _sender: ?Address = None

    /**
     * 使用会话构造
     */
    public init(session: Session) {
        super(session)
        _messageId = Some(MimeMessage.newMessageId())
    }

    /**
     * 复制构造（用于群发时为每个收件人生成独立副本）
     * 对应：jakarta.mail.internet.MimeMessage(MimeMessage source)
     */
    public init(source: MimeMessage) {
        super(source._session)
        _content     = source._content
        _contentType = source._contentType
        _multipart   = source._multipart
        _subject     = source._subject
        _sentDate    = source._sentDate
        _sender      = source._sender
        for (a in source._from)    { _from.add(a) }
        for (a in source._to)      { _to.add(a) }
        for (a in source._cc)      { _cc.add(a) }
        for (a in source._bcc)     { _bcc.add(a) }
        for (a in source._replyTo) { _replyTo.add(a) }
        _messageId = Some(MimeMessage.newMessageId())
        _saved = false
    }

    /**
     * 从输入流解析 RFC 2822 邮件消息（加载现有邮件/转发原始消息）
     * 对应：jakarta.mail.internet.MimeMessage(Session, InputStream)
     */
    public init(session: Session, input: InputStream) {
        super(session)
        // 读取字节流（open class 构造函数只能调用 static 方法）
        let buf = Array<Byte>(4096, repeat: 0u8)
        var allBytes = ArrayList<Byte>()
        var nr = input.read(buf)
        while (nr > 0) {
            for (i in 0..nr) { allBytes.add(buf[i]) }
            nr = input.read(buf)
        }
        let raw = try {
            String.fromUtf8(allBytes.toArray())
        } catch (_: Exception) {
            var s = ""
            for (b in allBytes) { s += Rune(b).toString() }
            s
        }
        // 按行分割，找头/体分隔符（第一个空行）
        let rawLines = raw.split("\n")
        var headerLines = ArrayList<String>()
        var bodyLines = ArrayList<String>()
        var foundBlank = false
        for (line in rawLines) {
            if (!foundBlank) {
                let stripped = if (line.endsWith("\r")) { line[0..(line.size - 1)] } else { line }
                if (stripped.isEmpty()) { foundBlank = true } else { headerLines.add(stripped) }
            } else {
                bodyLines.add(line)
            }
        }
        // 解析头（静态方法）
        _headers = MimeMessage.buildRfc2822Headers(headerLines)
        // 从头同步字段
        match (_headers.getFirstHeader("Subject")) {
            case Some(s) => _subject = Some(s)
            case None    => ()
        }
        match (_headers.getFirstHeader("Message-ID")) {
            case Some(id) => _messageId = Some(id.trimAscii())
            case None     => ()
        }
        match (_headers.getFirstHeader("Content-Type")) {
            case Some(ct) => _contentType = ct
            case None     => ()
        }
        match (_headers.getFirstHeader("From")) {
            case Some(v) => for (a in InternetAddress.parse(v)) { _from.add(a) }
            case None    => ()
        }
        match (_headers.getFirstHeader("To")) {
            case Some(v) => for (a in InternetAddress.parse(v)) { _to.add(a) }
            case None    => ()
        }
        match (_headers.getFirstHeader("Cc")) {
            case Some(v) => for (a in InternetAddress.parse(v)) { _cc.add(a) }
            case None    => ()
        }
        match (_headers.getFirstHeader("Reply-To")) {
            case Some(v) => for (a in InternetAddress.parse(v)) { _replyTo.add(a) }
            case None    => ()
        }
        match (_headers.getFirstHeader("Sender")) {
            case Some(v) =>
                let addrs = InternetAddress.parse(v)
                if (!addrs.isEmpty()) { _sender = Some(addrs[0]) }
            case None => ()
        }
        // 重建正文字符串
        var bodyStr = ""
        for (i in 0..bodyLines.size) {
            if (i > 0) { bodyStr += "\n" }
            bodyStr += bodyLines[i]
        }
        // 按 Content-Type 解析正文
        let ctLower = _contentType.toAsciiLower()
        if (ctLower.startsWith("multipart/")) {
            let subType = MimeMessage.rfc2822SubType(_contentType)
            match (MimeMessage.rfc2822Boundary(_contentType)) {
                case Some(boundary) =>
                    _multipart = Some(MimeMessage.rfc2822Multipart(bodyStr, boundary, subType))
                    _content = None
                case None =>
                    _content = Some(bodyStr)
            }
        } else {
            let enc = match (_headers.getFirstHeader("Content-Transfer-Encoding")) {
                case Some(e) => e.trimAscii().toAsciiLower()
                case None    => "8bit"
            }
            _content = Some(MimeMessage.rfc2822Decode(bodyStr, enc))
        }
        _saved = true
    }

    /**
     * 生成唯一 Message-ID 字符串（静态，可在构造函数中安全调用）
     */
    private static func newMessageId(): String {
        let random = Random()
        let ts = DateTime.now().toUnixTimeStamp().toNanoseconds()
        let r  = random.nextInt64()
        "<${ts}.${r}@cangjie-mail>"
    }

    /**
     * 获取发件人地址
     */
    public override func getFrom(): Array<Address> {
        _from.toArray()
    }

    /**
     * 设置发件人地址
     */
    public override func setFrom(address: Address): Unit {
        _from.clear()
        _from.add(address)
        _saved = false
    }

    /**
     * 追加发件人（多发件人场景）
     * 对应：jakarta.mail.internet.MimeMessage.addFrom
     */
    public func addFrom(addresses: Array<Address>): Unit {
        for (a in addresses) { _from.add(a) }
        _saved = false
    }

    /**
     * 获取 RFC 2822 Sender（代发人）
     */
    public func getSender(): ?Address {
        _sender
    }

    /**
     * 设置 RFC 2822 Sender（代发人）
     */
    public func setSender(address: Address): Unit {
        _sender = Some(address)
        _saved = false
    }

    /**
     * 从会话属性设置发件人
     */
    public func setFrom(): Unit {
        match (_session.getProperty("mail.from")) {
            case Some(addr) =>
                setFrom(InternetAddress(addr))
            case None =>
                match (_session.getProperty("mail.smtp.from")) {
                    case Some(addr) => setFrom(InternetAddress(addr))
                    case None => ()
                }
        }
    }

    /**
     * 获取指定类型的收件人
     */
    public override func getRecipients(recipientType: RecipientType): Array<Address> {
        match (recipientType) {
            case TO => _to.toArray()
            case CC => _cc.toArray()
            case BCC => _bcc.toArray()
        }
    }

    /**
     * 设置指定类型的收件人
     */
    public override func setRecipients(recipientType: RecipientType, addresses: Array<Address>): Unit {
        let list = match (recipientType) {
            case TO => _to
            case CC => _cc
            case BCC => _bcc
        }
        list.clear()
        for (addr in addresses) {
            list.add(addr)
        }
        _saved = false
    }

    /**
     * 添加指定类型的收件人
     */
    public override func addRecipients(recipientType: RecipientType, addresses: Array<Address>): Unit {
        let list = match (recipientType) {
            case TO => _to
            case CC => _cc
            case BCC => _bcc
        }
        for (addr in addresses) {
            list.add(addr)
        }
        _saved = false
    }

    /**
     * 获取所有收件人
     */
    public override func getAllRecipients(): Array<Address> {
        let result = ArrayList<Address>()
        for (addr in _to) {
            result.add(addr)
        }
        for (addr in _cc) {
            result.add(addr)
        }
        for (addr in _bcc) {
            result.add(addr)
        }
        result.toArray()
    }

    /**
     * 获取主题
     */
    public override func getSubject(): ?String {
        _subject
    }

    /**
     * 设置主题
     */
    public override func setSubject(subject: String): Unit {
        _subject = Some(subject)
        _saved = false
    }

    /**
     * 设置主题（指定字符集）
     */
    public override func setSubject(subject: String, _: String): Unit {
        _subject = Some(subject)
        _saved = false
    }

    /**
     * 获取发送日期
     */
    public override func getSentDate(): ?DateTime {
        _sentDate
    }

    /**
     * 设置发送日期
     */
    public override func setSentDate(date: DateTime): Unit {
        _sentDate = Some(date)
        _saved = false
    }

    /**
     * 获取回复地址
     */
    public override func getReplyTo(): Array<Address> {
        if (_replyTo.isEmpty()) {
            return getFrom()
        }
        _replyTo.toArray()
    }

    /**
     * 设置回复地址
     */
    public override func setReplyTo(addresses: Array<Address>): Unit {
        _replyTo.clear()
        for (addr in addresses) {
            _replyTo.add(addr)
        }
        _saved = false
    }

    /**
     * 设置文本内容
     */
    public override func setText(text: String): Unit {
        _content = Some(text)
        _contentType = "text/plain; charset=UTF-8"
        _saved = false
    }

    /**
     * 设置文本内容（指定字符集）
     */
    public override func setText(text: String, charset: String): Unit {
        _content = Some(text)
        _contentType = "text/plain; charset=${charset}"
        _saved = false
    }

    /**
     * 设置 HTML 内容
     */
    public func setHtmlContent(html: String): Unit {
        _content = Some(html)
        _contentType = "text/html; charset=UTF-8"
        _saved = false
    }

    /**
     * 设置 HTML 内容（指定字符集）
     */
    public func setHtmlContent(html: String, charset: String): Unit {
        _content = Some(html)
        _contentType = "text/html; charset=${charset}"
        _saved = false
    }

    /**
     * 设置 Multipart 内容
     */
    public func setContent(multipart: MimeMultipart): Unit {
        _multipart = Some(multipart)
        _content = None
        _contentType = multipart.getContentType()
        _saved = false
    }

    /**
     * 获取 Multipart 内容
     */
    public func getMultipart(): ?MimeMultipart {
        _multipart
    }

    /**
     * 获取内容类型
     */
    public func getContentType(): String {
        _contentType
    }

    /**
     * 设置内容类型
     */
    public func setContentType(contentType: String): Unit {
        _contentType = contentType
        _saved = false
    }

    /**
     * 获取消息 ID
     */
    public func getMessageID(): ?String {
        _messageId
    }

    /**
     * 设置消息 ID
     */
    public func setMessageID(messageId: String): Unit {
        _messageId = Some(messageId)
    }

    /**
     * 获取头值
     */
    public func getHeader(name: String): ?String {
        _headers.getFirstHeader(name)
    }

    /**
     * 设置头值
     */
    public func setHeader(name: String, value: String): Unit {
        _headers.setHeader(name, value)
        _saved = false
    }

    /**
     * 添加头值
     */
    public func addHeader(name: String, value: String): Unit {
        _headers.addHeader(name, value)
        _saved = false
    }

    /**
     * 删除头
     */
    public func removeHeader(name: String): Unit {
        _headers.removeHeader(name)
    }

    /**
     * 直接获取所有头（调用前会先 saveChanges）
     * 对应：jakarta.mail.internet.MimeMessage.getAllHeaders
     */
    public func getAllHeaders(): ArrayList<Header> {
        saveChanges()
        _headers.getAllHeaders()
    }

    /**
     * 获取名称在列表中的头
     * 对应：jakarta.mail.internet.MimeMessage.getMatchingHeaders
     */
    public func getMatchingHeaders(names: Array<String>): ArrayList<Header> {
        saveChanges()
        _headers.getMatchingHeaders(names)
    }

    /**
     * 获取名称不在列表中的头
     * 对应：jakarta.mail.internet.MimeMessage.getNonMatchingHeaders
     */
    public func getNonMatchingHeaders(names: Array<String>): ArrayList<Header> {
        saveChanges()
        _headers.getNonMatchingHeaders(names)
    }

    /**
     * 获取消息内容（文本消息返回字符串，多 part 消息返回内容字符串）
     * 对应：jakarta.mail.internet.MimeMessage.getContent（简化版）
     */
    public func getContent(): ?String {
        match (_content) {
            case Some(c) => Some(c)
            case None =>
                match (_multipart) {
                    case Some(mp) => Some(mp.getContentString())
                    case None => None
                }
        }
    }

    /**
     * 估算消息大小（字节）
     * 对应：jakarta.mail.internet.MimeMessage.getSize
     */
    public func getSize(): Int64 {
        saveChanges()
        var size = Int64(_headers.toString().size) + 2  // +2 for blank line
        match (_multipart) {
            case Some(mp) => size += Int64(mp.getContentString().size)
            case None =>
                match (_content) {
                    case Some(c) => size += Int64(c.size)
                    case None => ()
                }
        }
        size
    }

    /**
     * 生成回复消息（不填写正文，由调用方补充）
     * replyToAll=true 时将原始 To/Cc 列入新消息的 Cc
     * 对应：jakarta.mail.internet.MimeMessage.reply
     */
    public func reply(replyToAll: Bool): MimeMessage {
        let replyMsg = MimeMessage(_session)

        // Subject: 加 "Re: " 前缀（已有则保留）
        let origSubj = match (_subject) { case Some(s) => s; case None => "" }
        let upOrig = origSubj.toAsciiUpper()
        replyMsg.setSubject(
            if (upOrig.startsWith("RE:") || upOrig.startsWith("RE: ")) {
                origSubj
            } else {
                "Re: ${origSubj}"
            }
        )

        // To: Reply-To 优先，否则 From
        let toList = if (!_replyTo.isEmpty()) { _replyTo.toArray() } else { _from.toArray() }
        replyMsg.setRecipients(RecipientType.TO, toList)

        // Cc: 原 To + Cc（仅 replyToAll）
        if (replyToAll) {
            let ccList = ArrayList<Address>()
            for (a in _to)  { ccList.add(a) }
            for (a in _cc)  { ccList.add(a) }
            if (!ccList.isEmpty()) {
                replyMsg.setRecipients(RecipientType.CC, ccList.toArray())
            }
        }

        // In-Reply-To / References
        match (_messageId) {
            case Some(id) =>
                replyMsg.setHeader("In-Reply-To", id)
                replyMsg.setHeader("References", id)
            case None => ()
        }

        replyMsg
    }

    /**
     * 保存消息更改
     */
    public override func saveChanges(): Unit {
        if (_saved) {
            return
        }

        // 保留用户通过 setHeader/addHeader 设置的自定义头
        let standardHeaders = ["date", "from", "sender", "to", "cc", "bcc",
            "reply-to", "subject", "message-id", "content-type",
            "content-transfer-encoding", "mime-version"]
        let customHeaders = _headers.getNonMatchingHeaders(standardHeaders.toArray())

        // 从消息属性重建标准头
        _headers = InternetHeaders()

        // Date 头
        let date = match (_sentDate) {
            case Some(d) => d
            case None =>
                let now = DateTime.now()
                _sentDate = Some(now)
                now
        }
        _headers.setHeader("Date", formatDate(date))

        // From 头
        if (!_from.isEmpty()) {
            _headers.setHeader("From", addressesToString(_from))
        }

        // Sender 头（代发）
        match (_sender) {
            case Some(s) => _headers.setHeader("Sender", s.toString())
            case None => ()
        }

        // To 头
        if (!_to.isEmpty()) {
            _headers.setHeader("To", addressesToString(_to))
        }

        // Cc 头
        if (!_cc.isEmpty()) {
            _headers.setHeader("Cc", addressesToString(_cc))
        }

        // 注意：BCC 不包含在头中（密送）

        // Reply-To 头
        if (!_replyTo.isEmpty()) {
            _headers.setHeader("Reply-To", addressesToString(_replyTo))
        }

        // Subject 头
        match (_subject) {
            case Some(s) => _headers.setHeader("Subject", s)
            case None => ()
        }

        // Message-ID 头
        match (_messageId) {
            case Some(id) => _headers.setHeader("Message-ID", id)
            case None => ()
        }

        // Content-Type 头
        _headers.setHeader("Content-Type", _contentType)

        // Content-Transfer-Encoding 头
        _headers.setHeader("Content-Transfer-Encoding", "8bit")

        // MIME-Version 头
        _headers.setHeader("MIME-Version", "1.0")

        // 补回自定义头
        for (h in customHeaders) {
            _headers.addHeader(h.getName(), h.getValue())
        }

        _saved = true
    }

    /**
     * 格式化邮件头日期
     */
    private func formatDate(date: DateTime): String {
        // RFC 2822 日期格式："Mon, 20 Jan 2025 15:30:00 +0800"
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        // 获取星期枚举的序数值
        let dayIdx = match (date.dayOfWeek) {
            case Sunday => 0
            case Monday => 1
            case Tuesday => 2
            case Wednesday => 3
            case Thursday => 4
            case Friday => 5
            case Saturday => 6
        }
        let dayOfWeek = days[dayIdx]

        // 获取月份枚举的序数值
        let monthIdx = match (date.month) {
            case January => 0
            case February => 1
            case March => 2
            case April => 3
            case May => 4
            case June => 5
            case July => 6
            case August => 7
            case September => 8
            case October => 9
            case November => 10
            case December => 11
        }
        let month = months[monthIdx]

        "${dayOfWeek}, ${date.dayOfMonth} ${month} ${date.year} ${padZero(Int64(date.hour))}:${padZero(Int64(date.minute))}:${padZero(Int64(date.second))} +0000"
    }

    /**
     * 数字前补零
     */
    private func padZero(n: Int64): String {
        if (n < 10) {
            "0${n}"
        } else {
            "${n}"
        }
    }

    /**
     * 将地址列表转换为字符串
     */
    private func addressesToString(addresses: ArrayList<Address>): String {
        var result = ""
        for (i in 0..addresses.size) {
            if (i > 0) {
                result += ", "
            }
            result += addresses[i].toString()
        }
        result
    }

    /**
     * 将消息写入输出流
     */
    public override func writeTo(output: OutputStream): Unit {
        writeTo(output, [])
    }

    /**
     * 获取消息字符串（完整，含所有头）
     */
    public func getMessageString(): String {
        getMessageString([])
    }

    /**
     * 获取消息字符串，忽略指定头（如 Bcc）
     * SMTP DATA 提交时应传入 ["Bcc"] 防止密送地址泄露
     */
    public func getMessageString(ignoreHeaders: Array<String>): String {
        saveChanges()

        var result = buildFilteredHeaderString(ignoreHeaders)
        result += "\r\n"

        match (_multipart) {
            case Some(mp) =>
                result += mp.getContentString()
            case None =>
                match (_content) {
                    case Some(content) => result += content
                    case None => ()
                }
        }

        result
    }

    /**
     * 将消息写入输出流，忽略指定头
     */
    public func writeTo(output: OutputStream, ignoreHeaders: Array<String>): Unit {
        saveChanges()

        let headerStr = buildFilteredHeaderString(ignoreHeaders)
        output.write(headerStr.toArray())
        output.write("\r\n".toArray())

        match (_multipart) {
            case Some(mp) => mp.writeTo(output)
            case None =>
                match (_content) {
                    case Some(content) => output.write(content.toArray())
                    case None => ()
                }
        }

        output.flush()
    }

    /**
     * 构建过滤后的头字符串（跳过 ignoreHeaders 中的头，大小写不敏感）
     */
    private func buildFilteredHeaderString(ignoreHeaders: Array<String>): String {
        if (ignoreHeaders.isEmpty()) {
            return _headers.toString()
        }
        // 转为小写集合
        let ignoreSet = ArrayList<String>()
        for (h in ignoreHeaders) { ignoreSet.add(h.toAsciiLower()) }

        var result = ""
        for (h in _headers.getAllHeaders()) {
            let lowerName = h.getName().toAsciiLower()
            var skip = false
            for (ig in ignoreSet) {
                if (ig == lowerName) { skip = true; break }
            }
            if (!skip) {
                result += "${h.getName()}: ${h.getValue()}\r\n"
            }
        }
        result
    }

    /**
     * 判断消息是否包含 Multipart 内容
     */
    public func isMultipart(): Bool {
        _multipart.isSome()
    }

    /**
     * 添加附件到消息
     * 如果消息已有内容，会自动转换为 multipart/mixed
     */
    public func addAttachment(filePath: String): Unit {
        // 获取或创建 mixed multipart
        let mp = match (_multipart) {
            case Some(existing) =>
                // 如果已有 multipart，直接使用
                existing
            case None =>
                // 创建新的 mixed multipart，并将现有内容作为第一部分
                let newMp = MimeMultipart(MULTIPART_MIXED)
                match (_content) {
                    case Some(content) =>
                        let textPart = MimeBodyPart()
                        if (_contentType.contains("html")) {
                            textPart.setHtmlContent(content)
                        } else {
                            textPart.setText(content)
                        }
                        newMp.addBodyPart(textPart)
                    case None => ()
                }
                _multipart = Some(newMp)
                _content = None
                _contentType = newMp.getContentType()
                newMp
        }

        // 添加附件部分
        let attachPart = MimeBodyPart()
        attachPart.attachFile(filePath)
        mp.addBodyPart(attachPart)
        _saved = false
    }

    /**
     * 添加多个附件
     */
    public func addAttachments(filePaths: Array<String>): Unit {
        for (path in filePaths) {
            addAttachment(path)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RFC 2822 解析（private static，open class 构造函数可安全调用）
    // ─────────────────────────────────────────────────────────────────────────

    private static func buildRfc2822Headers(lines: ArrayList<String>): InternetHeaders {
        let hdrs = InternetHeaders()
        var curName = ""
        var curValue = ""
        for (line in lines) {
            if (line.startsWith(" ") || line.startsWith("\t")) {
                curValue += " " + line.trimAscii()
                continue
            }
            if (!curName.isEmpty()) { hdrs.addHeader(curName, curValue) }
            match (line.indexOf(":")) {
                case Some(idx) =>
                    curName = line[0..idx].trimAscii()
                    curValue = line[(idx + 1)..line.size].trimAscii()
                case None =>
                    curName = ""
                    curValue = ""
            }
        }
        if (!curName.isEmpty()) { hdrs.addHeader(curName, curValue) }
        hdrs
    }

    private static func rfc2822SubType(contentType: String): String {
        let lower = contentType.toAsciiLower()
        if (lower.startsWith("multipart/")) {
            let rest = lower[10..lower.size]
            match (rest.indexOf(";")) {
                case Some(idx) => rest[0..idx].trimAscii()
                case None      => rest.trimAscii()
            }
        } else {
            "mixed"
        }
    }

    private static func rfc2822Boundary(contentType: String): ?String {
        let lower = contentType.toAsciiLower()
        let key = "boundary="
        match (lower.indexOf(key)) {
            case Some(idx) =>
                let after = contentType[(idx + key.size)..contentType.size]
                if (after.startsWith("\"")) {
                    match (after[1..after.size].indexOf("\"")) {
                        case Some(end) => Some(after[1..(1 + end)])
                        case None      => Some(after[1..after.size].trimAscii())
                    }
                } else {
                    match (after.indexOf(";")) {
                        case Some(end) => Some(after[0..end].trimAscii())
                        case None      => Some(after.trimAscii())
                    }
                }
            case None => None
        }
    }

    private static func rfc2822Multipart(body: String, boundary: String, subType: String): MimeMultipart {
        let mp = MimeMultipart(subType)
        let delim = "--" + boundary
        let closeDelim = "--" + boundary + "--"
        let lines = body.split("\n")
        var partLines = ArrayList<String>()
        var inPart = false
        for (line in lines) {
            let stripped = if (line.endsWith("\r")) { line[0..(line.size - 1)] } else { line }
            if (stripped == closeDelim || stripped.startsWith(closeDelim)) {
                if (inPart && !partLines.isEmpty()) {
                    mp.addBodyPart(MimeMessage.rfc2822BodyPart(partLines))
                }
                break
            }
            if (stripped == delim || stripped.startsWith(delim + " ") || stripped.startsWith(delim + "\t")) {
                if (inPart && !partLines.isEmpty()) {
                    mp.addBodyPart(MimeMessage.rfc2822BodyPart(partLines))
                    partLines = ArrayList<String>()
                }
                inPart = true
                continue
            }
            if (inPart) { partLines.add(stripped) }
        }
        mp
    }

    private static func rfc2822BodyPart(lines: ArrayList<String>): MimeBodyPart {
        let part = MimeBodyPart()
        var hdrLines = ArrayList<String>()
        var bodyLines = ArrayList<String>()
        var inHdr = true
        for (line in lines) {
            if (inHdr) {
                if (line.isEmpty()) { inHdr = false } else { hdrLines.add(line) }
            } else {
                bodyLines.add(line)
            }
        }
        let partHdrs = MimeMessage.buildRfc2822Headers(hdrLines)
        let ct = match (partHdrs.getFirstHeader("Content-Type")) {
            case Some(v) => v
            case None    => "text/plain; charset=UTF-8"
        }
        part.setContentType(ct)
        match (partHdrs.getFirstHeader("Content-Disposition")) {
            case Some(v) =>
                if (v.toAsciiLower().contains("attachment")) {
                    part.setDisposition(PART_ATTACHMENT)
                    match (MimeMessage.rfc2822Param(v, "filename")) {
                        case Some(fn) => part.setFileName(fn)
                        case None     => ()
                    }
                } else {
                    part.setDisposition(PART_INLINE)
                }
            case None => ()
        }
        match (partHdrs.getFirstHeader("Content-ID")) {
            case Some(cid) => part.setContentID(cid.trimAscii())
            case None      => ()
        }
        let enc = match (partHdrs.getFirstHeader("Content-Transfer-Encoding")) {
            case Some(e) => e.trimAscii().toAsciiLower()
            case None    => "8bit"
        }
        var rawBody = ""
        for (i in 0..bodyLines.size) {
            if (i > 0) { rawBody += "\r\n" }
            rawBody += bodyLines[i]
        }
        let decoded = MimeMessage.rfc2822Decode(rawBody, enc)
        if (ct.toAsciiLower().contains("text/html")) {
            part.setHtmlContent(decoded)
        } else {
            part.setText(decoded)
        }
        part
    }

    private static func rfc2822Param(headerValue: String, paramName: String): ?String {
        let lower = headerValue.toAsciiLower()
        let key = paramName.toAsciiLower() + "="
        match (lower.indexOf(key)) {
            case Some(idx) =>
                let after = headerValue[(idx + key.size)..headerValue.size]
                if (after.startsWith("\"")) {
                    match (after[1..after.size].indexOf("\"")) {
                        case Some(end) => Some(after[1..(1 + end)])
                        case None      => Some(after[1..after.size].trimAscii())
                    }
                } else {
                    match (after.indexOf(";")) {
                        case Some(end) => Some(after[0..end].trimAscii())
                        case None      => Some(after.trimAscii())
                    }
                }
            case None => None
        }
    }

    private static func rfc2822Decode(content: String, encoding: String): String {
        match (encoding) {
            case "base64"           => Base64Util.decodeToString(content)
            case "quoted-printable" => MimeMessage.rfc2822DecodeQP(content)
            case _                  => content
        }
    }

    private static func rfc2822DecodeQP(content: String): String {
        var result = ""
        let runes = content.toRuneArray()
        var i = 0
        while (i < runes.size) {
            let ch = runes[i]
            if (ch == r'=') {
                if (i + 1 < runes.size && (runes[i + 1] == r'\r' || runes[i + 1] == r'\n')) {
                    if (i + 1 < runes.size && runes[i + 1] == r'\r' && i + 2 < runes.size && runes[i + 2] == r'\n') {
                        i += 3
                    } else {
                        i += 2
                    }
                } else if (i + 2 < runes.size) {
                    let hi = MimeMessage.rfc2822HexVal(runes[i + 1])
                    let lo = MimeMessage.rfc2822HexVal(runes[i + 2])
                    if (hi >= 0 && lo >= 0) {
                        result += Rune(UInt8((hi << 4) | lo)).toString()
                        i += 3
                    } else { result += "="; i++ }
                } else { result += "="; i++ }
            } else { result += ch.toString(); i++ }
        }
        result
    }

    private static func rfc2822HexVal(r: Rune): Int64 {
        let c = Int64(UInt32(r))
        if (c >= 48 && c <= 57)  { return c - 48 }
        if (c >= 65 && c <= 70)  { return c - 55 }
        if (c >= 97 && c <= 102) { return c - 87 }
        -1
    }

    /**
     * 设置带内嵌图片的 HTML 内容
     * @param html HTML 内容，使用 cid:xxx 引用图片
     * @param images 图片列表，格式为 [(contentId, filePath), ...]
     */
    public func setHtmlWithInlineImages(html: String, images: Array<(String, String)>): Unit {
        let mp = createRelatedMultipart(html, images)
        setContent(mp)
    }

    /**
     * 设置带附件的文本内容
     */
    public func setTextWithAttachments(text: String, attachments: Array<String>): Unit {
        let mp = createMixedMultipart(text, attachments)
        setContent(mp)
    }

    /**
     * 设置带附件的 HTML 内容
     */
    public func setHtmlWithAttachments(html: String, attachments: Array<String>): Unit {
        let mp = MimeMultipart(MULTIPART_MIXED)

        // HTML 部分
        let htmlPart = MimeBodyPart()
        htmlPart.setHtmlContent(html)
        mp.addBodyPart(htmlPart)

        // 附件部分
        for (path in attachments) {
            let attachPart = MimeBodyPart()
            attachPart.attachFile(path)
            mp.addBodyPart(attachPart)
        }

        setContent(mp)
    }

    /**
     * 设置同时包含内嵌图片和附件的 HTML 邮件
     * 结构: multipart/mixed
     *         - multipart/related
     *             - text/html
     *             - inline images
     *         - attachments
     */
    public func setHtmlWithImagesAndAttachments(html: String, images: Array<(String, String)>, attachments: Array<String>): Unit {
        let mixedMp = MimeMultipart(MULTIPART_MIXED)

        // 创建 related 部分（HTML + 内嵌图片）
        let relatedMp = createRelatedMultipart(html, images)

        // 将 related 部分包装为 BodyPart
        let relatedPart = MimeBodyPart()
        relatedPart.setContentType(relatedMp.getContentType())
        // 需要特殊处理嵌套的 multipart
        relatedPart.setHeader("Content-Type", relatedMp.getContentType())

        // 使用自定义方式添加 related multipart
        // 这里我们直接将 related 的内容作为 BodyPart 添加
        let htmlPart = MimeBodyPart()
        htmlPart.setHtmlContent(html)
        mixedMp.addBodyPart(htmlPart)

        // 添加内嵌图片
        for ((cid, path) in images) {
            let imagePart = createInlineImageBodyPart(path, cid)
            mixedMp.addBodyPart(imagePart)
        }

        // 添加附件
        for (path in attachments) {
            let attachPart = MimeBodyPart()
            attachPart.attachFile(path)
            mixedMp.addBodyPart(attachPart)
        }

        setContent(mixedMp)
    }
}
