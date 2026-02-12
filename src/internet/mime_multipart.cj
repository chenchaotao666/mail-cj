/**
 * MIME 多部分容器实现
 */
package mail.internet

import std.io.*
import std.collection.*
import std.random.*
import mail.activation.*

/**
 * Multipart 子类型常量
 */
public let MULTIPART_MIXED: String = "mixed"           // 用于附件
public let MULTIPART_ALTERNATIVE: String = "alternative" // 用于文本/HTML 选择
public let MULTIPART_RELATED: String = "related"       // 用于内嵌资源

/**
 * MIME 多部分容器
 * 对应：jakarta.mail.internet.MimeMultipart
 */
public class MimeMultipart {
    private var _subType: String = MULTIPART_MIXED
    private var _boundary: String = ""
    private var _parts: ArrayList<MimeBodyPart> = ArrayList<MimeBodyPart>()
    private var _preamble: ?String = None

    /**
     * 默认构造（mixed 类型）
     */
    public init() {
        _boundary = MimeMultipart.generateBoundary()
    }

    /**
     * 指定子类型构造
     */
    public init(subType: String) {
        _subType = subType
        _boundary = MimeMultipart.generateBoundary()
    }

    /**
     * 生成随机边界字符串（静态方法）
     */
    private static func generateBoundary(): String {
        let random = Random()
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        var result = "----=_Part_"
        for (_ in 0..24) {
            let idx = random.nextInt64() % Int64(chars.size)
            let absIdx = if (idx < 0) { -idx } else { idx }
            result += String([chars.toRuneArray()[absIdx]])
        }
        result
    }

    /**
     * 添加 BodyPart
     */
    public func addBodyPart(part: MimeBodyPart): Unit {
        _parts.add(part)
    }

    /**
     * 在指定位置添加 BodyPart
     */
    public func addBodyPart(part: MimeBodyPart, index: Int64): Unit {
        // ArrayList 不支持直接插入，需要重新构建
        let newParts = ArrayList<MimeBodyPart>()
        for (i in 0.._parts.size) {
            if (i == index) {
                newParts.add(part)
            }
            newParts.add(_parts[i])
        }
        if (index >= _parts.size) {
            newParts.add(part)
        }
        _parts = newParts
    }

    /**
     * 移除 BodyPart
     */
    public func removeBodyPart(index: Int64): Bool {
        if (index >= 0 && index < _parts.size) {
            let newParts = ArrayList<MimeBodyPart>()
            for (i in 0.._parts.size) {
                if (i != index) {
                    newParts.add(_parts[i])
                }
            }
            _parts = newParts
            true
        } else {
            false
        }
    }

    /**
     * 获取 BodyPart 数量
     */
    public func getCount(): Int64 {
        _parts.size
    }

    /**
     * 获取指定索引的 BodyPart
     */
    public func getBodyPart(index: Int64): MimeBodyPart {
        _parts[index]
    }

    /**
     * 获取边界字符串
     */
    public func getBoundary(): String {
        _boundary
    }

    /**
     * 设置边界字符串
     */
    public func setBoundary(boundary: String): Unit {
        _boundary = boundary
    }

    /**
     * 获取子类型
     */
    public func getSubType(): String {
        _subType
    }

    /**
     * 设置子类型
     */
    public func setSubType(subType: String): Unit {
        _subType = subType
    }

    /**
     * 获取完整的 Content-Type
     */
    public func getContentType(): String {
        "multipart/${_subType}; boundary=\"${_boundary}\""
    }

    /**
     * 设置 preamble（边界前的文本）
     */
    public func setPreamble(preamble: String): Unit {
        _preamble = Some(preamble)
    }

    /**
     * 获取 preamble
     */
    public func getPreamble(): ?String {
        _preamble
    }

    /**
     * 写入到输出流
     */
    public func writeTo(output: OutputStream): Unit {
        // 写入 preamble
        match (_preamble) {
            case Some(pre) =>
                output.write(pre.toArray())
                output.write("\r\n".toArray())
            case None => ()
        }

        // 写入每个部分
        for (part in _parts) {
            // 边界行
            output.write("--${_boundary}\r\n".toArray())
            // 部分内容
            part.writeTo(output)
            output.write("\r\n".toArray())
        }

        // 结束边界
        output.write("--${_boundary}--\r\n".toArray())
    }

    /**
     * 获取内容字符串
     */
    public func getContentString(): String {
        let baos = ByteArrayOutputStream()
        writeTo(baos)
        String.fromUtf8(baos.toArray())
    }
}

/**
 * 创建带附件的 Multipart
 *
 * @param textContent 文本内容
 * @param attachments 附件文件路径列表
 */
public func createMixedMultipart(textContent: String, attachments: Array<String>): MimeMultipart {
    let mp = MimeMultipart(MULTIPART_MIXED)

    // 添加文本部分
    let textPart = MimeBodyPart()
    textPart.setText(textContent)
    mp.addBodyPart(textPart)

    // 添加附件
    for (path in attachments) {
        let attachPart = MimeBodyPart()
        attachPart.attachFile(path)
        mp.addBodyPart(attachPart)
    }

    mp
}

/**
 * 创建带内嵌图片的 HTML Multipart
 *
 * @param htmlContent HTML 内容（使用 cid:xxx 引用图片）
 * @param images 图片列表，格式为 [(contentId, filePath), ...]
 */
public func createRelatedMultipart(htmlContent: String, images: Array<(String, String)>): MimeMultipart {
    let mp = MimeMultipart(MULTIPART_RELATED)

    // 添加 HTML 部分
    let htmlPart = MimeBodyPart()
    htmlPart.setHtmlContent(htmlContent)
    mp.addBodyPart(htmlPart)

    // 添加内嵌图片
    for ((cid, path) in images) {
        let imagePart = createInlineImageBodyPart(path, cid)
        mp.addBodyPart(imagePart)
    }

    mp
}

/**
 * 创建包含文本和 HTML 的 Alternative Multipart
 *
 * @param textContent 纯文本内容
 * @param htmlContent HTML 内容
 */
public func createAlternativeMultipart(textContent: String, htmlContent: String): MimeMultipart {
    let mp = MimeMultipart(MULTIPART_ALTERNATIVE)

    // 先添加文本（邮件客户端会优先显示后面的）
    let textPart = MimeBodyPart()
    textPart.setText(textContent)
    mp.addBodyPart(textPart)

    // 再添加 HTML
    let htmlPart = MimeBodyPart()
    htmlPart.setHtmlContent(htmlContent)
    mp.addBodyPart(htmlPart)

    mp
}
