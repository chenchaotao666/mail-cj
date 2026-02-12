/**
 * Base64 编码工具
 */
package mail.util

import std.collection.*

/**
 * Base64 编码器/解码器
 */
public class Base64Util {
    private static let ALPHABET_CHARS: Array<Rune> = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toRuneArray()

    /**
     * 将 Rune 转换为单字符字符串
     */
    private static func runeToString(r: Rune): String {
        String([r])
    }

    /**
     * 将字节数组编码为 Base64 字符串
     */
    public static func encode(data: Array<Byte>): String {
        if (data.isEmpty()) {
            return ""
        }

        var result = ""
        var i = 0

        while (i < data.size) {
            let b0 = Int64(data[i]) & 0xFF
            let b1 = if (i + 1 < data.size) { Int64(data[i + 1]) & 0xFF } else { 0 }
            let b2 = if (i + 2 < data.size) { Int64(data[i + 2]) & 0xFF } else { 0 }

            let c0 = (b0 >> 2) & 0x3F
            let c1 = ((b0 << 4) | (b1 >> 4)) & 0x3F
            let c2 = ((b1 << 2) | (b2 >> 6)) & 0x3F
            let c3 = b2 & 0x3F

            result += runeToString(ALPHABET_CHARS[c0])
            result += runeToString(ALPHABET_CHARS[c1])

            if (i + 1 < data.size) {
                result += runeToString(ALPHABET_CHARS[c2])
            } else {
                result += "="
            }

            if (i + 2 < data.size) {
                result += runeToString(ALPHABET_CHARS[c3])
            } else {
                result += "="
            }

            i += 3
        }

        result
    }

    /**
     * 将字符串编码为 Base64
     */
    public static func encodeString(str: String): String {
        encode(str.toArray())
    }

    /**
     * 将 Base64 字符串解码为字节数组
     */
    public static func decode(encoded: String): Array<Byte> {
        if (encoded.isEmpty()) {
            return Array<Byte>()
        }

        // 构建查找表
        var lookup = Array<Int64>(128, repeat: -1)
        for (i in 0..64) {
            lookup[Int64(UInt32(ALPHABET_CHARS[i]))] = i
        }

        // 移除填充和空白字符
        var inputChars = ArrayList<Rune>()
        for (ch in encoded.toRuneArray()) {
            if (ch != r'=' && ch != r' ' && ch != r'\n' && ch != r'\r') {
                inputChars.add(ch)
            }
        }

        // 计算输出大小
        let outputLen = (inputChars.size * 3) / 4
        var output = Array<Byte>(outputLen, repeat: 0)

        var outIndex = 0
        var i = 0

        while (i < inputChars.size) {
            let c0 = lookup[Int64(UInt32(inputChars[i]))]
            let c1 = if (i + 1 < inputChars.size) { lookup[Int64(UInt32(inputChars[i + 1]))] } else { 0 }
            let c2 = if (i + 2 < inputChars.size) { lookup[Int64(UInt32(inputChars[i + 2]))] } else { 0 }
            let c3 = if (i + 3 < inputChars.size) { lookup[Int64(UInt32(inputChars[i + 3]))] } else { 0 }

            if (outIndex < outputLen) {
                output[outIndex] = UInt8(((c0 << 2) | (c1 >> 4)) & 0xFF)
                outIndex++
            }

            if (i + 2 < inputChars.size && outIndex < outputLen) {
                output[outIndex] = UInt8(((c1 << 4) | (c2 >> 2)) & 0xFF)
                outIndex++
            }

            if (i + 3 < inputChars.size && outIndex < outputLen) {
                output[outIndex] = UInt8(((c2 << 6) | c3) & 0xFF)
                outIndex++
            }

            i += 4
        }

        // 裁剪到实际大小
        if (outIndex < outputLen) {
            var trimmed = Array<Byte>(outIndex, repeat: 0)
            for (j in 0..outIndex) {
                trimmed[j] = output[j]
            }
            return trimmed
        }

        output
    }

    /**
     * 将 Base64 字符串解码为字符串
     */
    public static func decodeToString(encoded: String): String {
        String.fromUtf8(decode(encoded))
    }
}
