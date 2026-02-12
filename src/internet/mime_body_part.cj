/**
 * MIME 正文部分实现
 */
package mail.internet

import mail.activation.*
import mail.util.*
import std.io.*
import std.collection.*

// 导入 FileTypeMap 和 MimeUtility（同包内已可用）

/**
 * Part 常量定义
 * 对应：jakarta.mail.Part
 */
public let PART_INLINE: String = "inline"
public let PART_ATTACHMENT: String = "attachment"

/**
 * MIME 正文部分
 * 对应：jakarta.mail.internet.MimeBodyPart
 */
public class MimeBodyPart {
    private var _headers: InternetHeaders = InternetHeaders()
    private var _content: ?Array<Byte> = None
    private var _dataHandler: ?DataHandler = None
    private var _fileName: ?String = None
    private var _disposition: ?String = None
    private var _contentId: ?String = None
    private var _contentType: String = "text/plain; charset=UTF-8"
    private var _description: ?String = None
    private var _encoding: String = "base64"

    /**
     * 默认构造函数
     */
    public init() {}

    /**
     * 设置文本内容
     */
    public func setText(text: String): Unit {
        _content = Some(text.toArray())
        _contentType = "text/plain; charset=UTF-8"
        _encoding = "8bit"
    }

    /**
     * 设置文本内容（指定字符集）
     */
    public func setText(text: String, charset: String): Unit {
        _content = Some(text.toArray())
        _contentType = "text/plain; charset=${charset}"
        _encoding = "8bit"
    }

    /**
     * 设置文本内容（指定字符集和子类型）
     */
    public func setText(text: String, charset: String, subtype: String): Unit {
        _content = Some(text.toArray())
        _contentType = "text/${subtype}; charset=${charset}"
        _encoding = "8bit"
    }

    /**
     * 设置 HTML 内容
     */
    public func setHtmlContent(html: String): Unit {
        setText(html, "UTF-8", "html")
    }

    /**
     * 设置数据处理器
     */
    public func setDataHandler(handler: DataHandler): Unit {
        _dataHandler = Some(handler)
        _contentType = handler.getContentType()
        if (_fileName.isNone()) {
            let name = handler.getName()
            if (!name.isEmpty()) {
                _fileName = Some(name)
            }
        }
    }

    /**
     * 获取数据处理器
     */
    public func getDataHandler(): ?DataHandler {
        _dataHandler
    }

    /**
     * 附加文件
     * 使用 FileTypeMap 自动检测 MIME 类型
     * 使用 MimeUtility 编码文件名（支持中文）
     */
    public func attachFile(path: String): Unit {
        let fds = FileDataSource(path)

        // 使用 FileTypeMap 获取正确的 MIME 类型
        let mimeType = FileTypeMap.getDefaultFileTypeMap().getContentType(path)
        _contentType = mimeType

        setDataHandler(DataHandler(fds))

        // 使用 MimeUtility 编码文件名（支持中文等非 ASCII 字符）
        let rawFileName = fds.getName()
        let encodedFileName = MimeUtility.encodeWord(rawFileName)
        _fileName = Some(encodedFileName)

        setDisposition(PART_ATTACHMENT)
    }

    /**
     * 附加文件（指定字符集编码文件名）
     */
    public func attachFile(path: String, charset: String): Unit {
        let fds = FileDataSource(path)

        // 使用 FileTypeMap 获取正确的 MIME 类型
        let mimeType = FileTypeMap.getDefaultFileTypeMap().getContentType(path)
        _contentType = mimeType

        setDataHandler(DataHandler(fds))

        // 使用指定字符集编码文件名
        let rawFileName = fds.getName()
        let encodedFileName = MimeUtility.encodeWord(rawFileName, charset: charset)
        _fileName = Some(encodedFileName)

        setDisposition(PART_ATTACHMENT)
    }


    /**
     * 设置文件名
     */
    public func setFileName(fileName: String): Unit {
        _fileName = Some(fileName)
    }

    /**
     * 获取文件名
     */
    public func getFileName(): ?String {
        _fileName
    }

    /**
     * 设置 Content-Disposition
     */
    public func setDisposition(disposition: String): Unit {
        _disposition = Some(disposition)
    }

    /**
     * 获取 Content-Disposition
     */
    public func getDisposition(): ?String {
        _disposition
    }

    /**
     * 设置 Content-ID（用于内嵌图片）
     */
    public func setContentID(cid: String): Unit {
        // 确保格式为 <xxx>
        if (cid.startsWith("<") && cid.endsWith(">")) {
            _contentId = Some(cid)
        } else {
            _contentId = Some("<${cid}>")
        }
    }

    /**
     * 获取 Content-ID
     */
    public func getContentID(): ?String {
        _contentId
    }

    /**
     * 设置内容类型
     */
    public func setContentType(contentType: String): Unit {
        _contentType = contentType
    }

    /**
     * 获取内容类型
     */
    public func getContentType(): String {
        _contentType
    }

    /**
     * 设置描述
     */
    public func setDescription(description: String): Unit {
        _description = Some(description)
    }

    /**
     * 获取描述
     */
    public func getDescription(): ?String {
        _description
    }

    /**
     * 设置头
     */
    public func setHeader(name: String, value: String): Unit {
        _headers.setHeader(name, value)
    }

    /**
     * 获取头
     */
    public func getHeader(name: String): ?String {
        _headers.getFirstHeader(name)
    }

    /**
     * 添加头
     */
    public func addHeader(name: String, value: String): Unit {
        _headers.addHeader(name, value)
    }

    /**
     * 设置传输编码
     */
    public func setTransferEncoding(encoding: String): Unit {
        _encoding = encoding
    }

    /**
     * 获取传输编码
     */
    public func getTransferEncoding(): String {
        _encoding
    }

    /**
     * 判断是否是指定的 MIME 类型
     */
    public func isMimeType(mimeType: String): Bool {
        _contentType.toAsciiLower().startsWith(mimeType.toAsciiLower())
    }

    /**
     * 写入到输出流
     */
    public func writeTo(output: OutputStream): Unit {
        // 构建头
        let headersStr = buildHeaders()
        output.write(headersStr.toArray())
        output.write("\r\n".toArray())

        // 写入内容
        writeContent(output)
    }

    /**
     * 构建 MIME 头字符串
     */
    private func buildHeaders(): String {
        var result = ""

        // Content-Type
        var ct = _contentType
        match (_fileName) {
            case Some(fn) =>
                if (!ct.contains("name=")) {
                    ct = "${ct}; name=\"${fn}\""
                }
            case None => ()
        }
        result += "Content-Type: ${ct}\r\n"

        // Content-Transfer-Encoding
        result += "Content-Transfer-Encoding: ${_encoding}\r\n"

        // Content-Disposition
        match (_disposition) {
            case Some(disp) =>
                var dispStr = disp
                match (_fileName) {
                    case Some(fn) =>
                        dispStr = "${disp}; filename=\"${fn}\""
                    case None => ()
                }
                result += "Content-Disposition: ${dispStr}\r\n"
            case None => ()
        }

        // Content-ID
        match (_contentId) {
            case Some(cid) => result += "Content-ID: ${cid}\r\n"
            case None => ()
        }

        // Content-Description
        match (_description) {
            case Some(desc) => result += "Content-Description: ${desc}\r\n"
            case None => ()
        }

        result
    }

    /**
     * 写入内容部分
     */
    private func writeContent(output: OutputStream): Unit {
        // 优先使用 DataHandler
        match (_dataHandler) {
            case Some(handler) =>
                if (_encoding == "base64") {
                    writeBase64Content(handler, output)
                } else {
                    handler.writeTo(output)
                }
                return
            case None => ()
        }

        // 使用直接内容
        match (_content) {
            case Some(data) =>
                if (_encoding == "base64") {
                    let encoded = Base64Util.encode(data)
                    // 每 76 字符换行
                    var i = 0
                    while (i < encoded.size) {
                        let end = if (i + 76 < encoded.size) { i + 76 } else { encoded.size }
                        output.write(encoded[i..end].toArray())
                        output.write("\r\n".toArray())
                        i += 76
                    }
                } else {
                    output.write(data)
                }
            case None => ()
        }
    }

    /**
     * 写入 Base64 编码的内容
     */
    private func writeBase64Content(handler: DataHandler, output: OutputStream): Unit {
        let input = handler.getInputStream()
        var allData = ArrayList<Byte>()
        let buffer = Array<Byte>(4096, repeat: 0)

        while (true) {
            let n = input.read(buffer)
            if (n <= 0) {
                break
            }
            for (i in 0..n) {
                allData.add(buffer[i])
            }
        }

        let encoded = Base64Util.encode(allData.toArray())

        // 每 76 字符换行（MIME 标准）
        var i = 0
        while (i < encoded.size) {
            let end = if (i + 76 < encoded.size) { i + 76 } else { encoded.size }
            output.write(encoded[i..end].toArray())
            output.write("\r\n".toArray())
            i += 76
        }
    }

    /**
     * 获取内容字符串（用于简单的文本/HTML 内容）
     */
    public func getContentString(): String {
        let baos = ByteArrayOutputStream()
        writeContent(baos)
        String.fromUtf8(baos.toArray())
    }
}

/**
 * 创建文本 BodyPart
 */
public func createTextBodyPart(text: String): MimeBodyPart {
    let part = MimeBodyPart()
    part.setText(text)
    part.setDisposition(PART_INLINE)
    part
}

/**
 * 创建 HTML BodyPart
 */
public func createHtmlBodyPart(html: String): MimeBodyPart {
    let part = MimeBodyPart()
    part.setHtmlContent(html)
    part.setDisposition(PART_INLINE)
    part
}

/**
 * 创建附件 BodyPart
 * 自动检测 MIME 类型并编码文件名（支持中文）
 */
public func createAttachmentBodyPart(filePath: String): MimeBodyPart {
    let part = MimeBodyPart()
    part.attachFile(filePath)
    part
}

/**
 * 创建附件 BodyPart（指定文件名编码字符集）
 */
public func createAttachmentBodyPart(filePath: String, charset: String): MimeBodyPart {
    let part = MimeBodyPart()
    part.attachFile(filePath, charset)
    part
}

/**
 * 创建内嵌图片 BodyPart（从文件路径）
 * 自动检测 MIME 类型并编码文件名
 */
public func createInlineImageBodyPart(filePath: String, contentId: String): MimeBodyPart {
    let fds = FileDataSource(filePath)
    let part = MimeBodyPart()
    part.setDataHandler(DataHandler(fds))

    // 使用 MimeUtility 编码文件名
    let encodedName = MimeUtility.encodeWord(fds.getName())
    part.setFileName(encodedName)

    // 使用 FileTypeMap 获取 MIME 类型
    let mimeType = FileTypeMap.getDefaultFileTypeMap().getContentType(filePath)
    part.setContentType(mimeType)

    part.setContentID(contentId)
    part.setDisposition(PART_INLINE)
    part
}

/**
 * 创建内嵌图片 BodyPart（从 DataSource）
 */
public func createInlineImageBodyPartFromDataSource(dataSource: DataSource, contentId: String): MimeBodyPart {
    let part = MimeBodyPart()
    part.setDataHandler(DataHandler(dataSource))
    let name = dataSource.getName()
    if (!name.isEmpty()) {
        part.setFileName(name)
    }
    part.setContentID(contentId)
    part.setDisposition(PART_INLINE)
    part
}

/**
 * 创建附件 BodyPart（从 DataSource）
 */
public func createAttachmentBodyPartFromDataSource(dataSource: DataSource): MimeBodyPart {
    let part = MimeBodyPart()
    part.setDataHandler(DataHandler(dataSource))
    let name = dataSource.getName()
    if (!name.isEmpty()) {
        part.setFileName(name)
    }
    part.setDisposition(PART_ATTACHMENT)
    part
}
