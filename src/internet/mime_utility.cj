/**
 * MIME 工具类
 * 提供 RFC 2047 编码/解码等功能
 */
package mail.internet

import mail.util.*
import std.collection.*

/**
 * MIME 工具类
 * 对应：jakarta.mail.internet.MimeUtility
 */
public class MimeUtility {
    /**
     * RFC 2047 编码字符串（用于邮件头，如附件文件名）
     * 格式: =?charset?encoding?encoded_text?=
     *
     * @param word 要编码的字符串
     * @param charset 字符集，默认 UTF-8
     * @param encoding 编码方式，"B" 表示 Base64，"Q" 表示 Quoted-Printable，默认为 None 自动选择
     * @return 编码后的字符串
     */
    public static func encodeWord(word: String, charset!: String = "UTF-8", encoding!: ?String = None): String {
        if (word.isEmpty()) {
            return word
        }

        // 检查是否需要编码（只有 ASCII 可打印字符不需要）
        var needsEncoding = false
        for (ch in word.toRuneArray()) {
            let code = UInt32(ch)
            // ASCII 可打印字符范围：32-126，排除特殊字符
            if (code > 126 || code < 32 || ch == r'=' || ch == r'?' || ch == r'_') {
                needsEncoding = true
                break
            }
        }

        if (!needsEncoding) {
            return word
        }

        // 确定编码方式
        let enc = match (encoding) {
            case Some(e) => e.toAsciiUpper()
            case None => "B"  // 默认使用 Base64
        }

        match (enc) {
            case "B" => encodeWordBase64(word, charset)
            case "Q" => encodeWordQuotedPrintable(word, charset)
            case _ => encodeWordBase64(word, charset)
        }
    }

    /**
     * 使用 Base64 编码 word
     */
    private static func encodeWordBase64(word: String, charset: String): String {
        let encoded = Base64Util.encodeString(word)
        "=?${charset}?B?${encoded}?="
    }

    /**
     * 使用 Quoted-Printable 编码 word
     */
    private static func encodeWordQuotedPrintable(word: String, charset: String): String {
        var result = ""
        let bytes = word.toArray()

        for (b in bytes) {
            let code = UInt8(b)
            // 可以直接表示的字符：字母、数字
            if ((code >= 65 && code <= 90) ||   // A-Z
                (code >= 97 && code <= 122) ||  // a-z
                (code >= 48 && code <= 57)) {   // 0-9
                result += Rune(b).toString()
            } else if (code == 32) {
                // 空格编码为下划线
                result += "_"
            } else {
                // 其他字符用 =XX 表示
                result += "=" + byteToHex(code)
            }
        }

        "=?${charset}?Q?${result}?="
    }

    /**
     * 字节转十六进制
     */
    private static func byteToHex(b: UInt8): String {
        let hexChars = "0123456789ABCDEF"
        let high = (b >> 4) & 0x0F
        let low = b & 0x0F
        "${hexChars[Int64(high)]}${hexChars[Int64(low)]}"
    }

    /**
     * 解码 RFC 2047 编码的字符串
     *
     * @param word 编码的字符串
     * @return 解码后的字符串
     */
    public static func decodeWord(word: String): String {
        if (!word.startsWith("=?") || !word.endsWith("?=")) {
            return word
        }

        // 解析 =?charset?encoding?text?=
        let inner = word[2..(word.size - 2)]

        // 查找分隔符位置
        var firstQ = -1
        var secondQ = -1
        var i = 0
        for (ch in inner.toRuneArray()) {
            if (ch == r'?') {
                if (firstQ < 0) {
                    firstQ = i
                } else {
                    secondQ = i
                    break
                }
            }
            i += 1
        }

        if (firstQ < 0 || secondQ < 0) {
            return word
        }

        let encoding = inner[(firstQ + 1)..secondQ].toAsciiUpper()
        let text = inner[(secondQ + 1)..inner.size]

        match (encoding) {
            case "B" => Base64Util.decodeToString(text)
            case "Q" => decodeQEncoded(text)
            case _ => word
        }
    }

    /**
     * 解码 Q 编码（Quoted-Printable）
     */
    private static func decodeQEncoded(text: String): String {
        var result = ArrayList<Byte>()
        var i = 0
        let chars = text.toRuneArray()

        while (i < chars.size) {
            let ch = chars[i]
            if (ch == r'_') {
                // 下划线代表空格
                result.add(32)
                i += 1
            } else if (ch == r'=' && i + 2 < chars.size) {
                // =XX 十六进制编码
                let hex1 = chars[i + 1]
                let hex2 = chars[i + 2]
                let value = hexToByte(hex1, hex2)
                result.add(value)
                i += 3
            } else {
                // 普通字符
                let bytes = ch.toString().toArray()
                for (b in bytes) {
                    result.add(b)
                }
                i += 1
            }
        }

        String.fromUtf8(result.toArray())
    }

    /**
     * 两个十六进制字符转字节
     */
    private static func hexToByte(hex1: Rune, hex2: Rune): Byte {
        let high = hexCharToInt(hex1)
        let low = hexCharToInt(hex2)
        UInt8((high << 4) | low)
    }

    /**
     * 单个十六进制字符转整数
     */
    private static func hexCharToInt(ch: Rune): Int64 {
        let code = UInt32(ch)
        if (code >= 48 && code <= 57) {      // 0-9
            Int64(code - 48)
        } else if (code >= 65 && code <= 70) { // A-F
            Int64(code - 55)
        } else if (code >= 97 && code <= 102) { // a-f
            Int64(code - 87)
        } else {
            0
        }
    }

    /**
     * 编码文本（如果需要）
     * 自动检测是否需要编码
     */
    public static func encodeText(text: String, charset!: String = "UTF-8", encoding!: ?String = None): String {
        encodeWord(text, charset: charset, encoding: encoding)
    }

    /**
     * 解码文本
     */
    public static func decodeText(text: String): String {
        // 处理可能包含多个编码段的文本
        var result = ""
        var current = ""
        var inEncoded = false
        var i = 0
        let chars = text.toRuneArray()

        while (i < chars.size) {
            if (i + 1 < chars.size && chars[i] == r'=' && chars[i + 1] == r'?') {
                // 开始编码段
                if (!current.isEmpty()) {
                    result += current
                    current = ""
                }
                inEncoded = true
                current += "=?"
                i += 2
            } else if (inEncoded && i + 1 < chars.size && chars[i] == r'?' && chars[i + 1] == r'=') {
                // 结束编码段
                current += "?="
                result += decodeWord(current)
                current = ""
                inEncoded = false
                i += 2
            } else {
                current += chars[i].toString()
                i += 1
            }
        }

        if (!current.isEmpty()) {
            if (inEncoded) {
                result += current  // 未完成的编码段原样输出
            } else {
                result += current
            }
        }

        result
    }

    /**
     * 获取适合邮件头的编码字符串
     * 用于 Subject、附件文件名等
     */
    public static func encodeHeader(name: String, value: String, charset!: String = "UTF-8"): String {
        let encoded = encodeWord(value, charset: charset)
        "${name}: ${encoded}"
    }

    /**
     * 折叠长行（每行不超过 76 字符）
     */
    public static func fold(headerLine: String, used!: Int64 = 0): String {
        let maxLen = 76
        if (headerLine.size + used <= maxLen) {
            return headerLine
        }

        var result = ""
        var lineStart = 0
        var lastSpace = -1
        var currentLen = used

        for (i in 0..headerLine.size) {
            let ch = headerLine[i..(i + 1)]
            if (ch == " " || ch == "\t") {
                lastSpace = i
            }
            currentLen += 1

            if (currentLen >= maxLen && lastSpace > lineStart) {
                result += headerLine[lineStart..lastSpace] + "\r\n "
                lineStart = lastSpace + 1
                currentLen = i - lineStart + 1
                lastSpace = -1
            }
        }

        if (lineStart < headerLine.size) {
            result += headerLine[lineStart..headerLine.size]
        }

        result
    }
}
