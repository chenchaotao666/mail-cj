/**
 * MIME 消息实现
 */
package mail.internet

import mail.core.*
import std.collection.*
import std.time.*
import std.io.*
import std.random.*

/**
 * MIME 消息实现
 * 对应：jakarta.mail.internet.MimeMessage
 */
public class MimeMessage <: Message {
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

    /**
     * 使用会话构造
     */
    public init(session: Session) {
        super(session)
        generateMessageId()
    }

    /**
     * 生成唯一的消息 ID
     */
    private func generateMessageId(): Unit {
        let random = Random()
        let timestamp = DateTime.now().toUnixTimeStamp().toNanoseconds()
        let randomPart = random.nextInt64()
        _messageId = Some("<${timestamp}.${randomPart}@cangjie-mail>")
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
    public override func setSubject(subject: String, charset: String): Unit {
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
     * 保存消息更改
     */
    public override func saveChanges(): Unit {
        if (_saved) {
            return
        }

        // 从消息属性更新头
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
        saveChanges()

        // 写入头
        let headerStr = _headers.toString()
        output.write(headerStr.toArray())

        // 头和正文之间的空行
        output.write("\r\n".toArray())

        // 写入正文（优先处理 Multipart）
        match (_multipart) {
            case Some(mp) =>
                mp.writeTo(output)
            case None =>
                match (_content) {
                    case Some(content) =>
                        output.write(content.toArray())
                    case None => ()
                }
        }

        output.flush()
    }

    /**
     * 获取消息字符串
     */
    public func getMessageString(): String {
        saveChanges()

        var result = _headers.toString()
        result += "\r\n"

        // 优先处理 Multipart
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
