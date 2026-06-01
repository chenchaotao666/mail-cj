/**
 * 加密工具类
 * 实现 MD4、MD5、HMAC-MD5（用于 NTLM 认证）及 UTF-16LE 编码
 */
package mail.util

import std.collection.*
import std.random.*

public class CryptoUtil {

    // =========================================================================
    // MD4 (RFC 1320) — NTLM NT hash 所需
    // =========================================================================

    public static func md4(data: Array<Byte>): Array<Byte> {
        // 填充：追加 0x80，补零到 56 mod 64，再追加原始长度（bits，8字节LE）
        var msg = ArrayList<Byte>()
        for (b in data) { msg.add(b) }
        msg.add(0x80u8)
        while (msg.size % 64 != 56) { msg.add(0u8) }
        let bits = Int64(data.size) * 8
        for (i in 0..8) { msg.add(UInt8((bits >> (i * 8)) & 0xFF)) }

        var a: Int64 = 0x67452301
        var b: Int64 = 0xEFCDAB89
        var c: Int64 = 0x98BADCFE
        var d: Int64 = 0x10325476

        var off = 0
        while (off < msg.size) {
            var x = Array<Int64>(16, repeat: 0)
            for (j in 0..16) {
                let o = off + j * 4
                x[j] = (Int64(msg[o]) | (Int64(msg[o+1]) << 8) |
                        (Int64(msg[o+2]) << 16) | (Int64(msg[o+3]) << 24)) & 0xFFFFFFFF
            }
            let aa = a; let bb = b; let cc = c; let dd = d

            // Round 1: F(b,c,d) = (b&c)|(~b&d), rotations {3,7,11,19}
            let r1 = [3,7,11,19,3,7,11,19,3,7,11,19,3,7,11,19]
            for (i in 0..16) {
                let nb = (b ^ 0xFFFFFFFF) & 0xFFFFFFFF
                let fi = ((b & c) | (nb & d)) & 0xFFFFFFFF
                let t = (a + fi + x[i]) & 0xFFFFFFFF
                a = d; d = c; c = b
                b = rotl32(t, r1[i])
            }

            // Round 2: G(b,c,d) = (b&c)|(b&d)|(c&d), constant 0x5A827999
            let r2 = [3,5,9,13,3,5,9,13,3,5,9,13,3,5,9,13]
            let ord2 = [0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15]
            for (i in 0..16) {
                let fi = ((b & c) | (b & d) | (c & d)) & 0xFFFFFFFF
                let t = (a + fi + x[ord2[i]] + 0x5A827999) & 0xFFFFFFFF
                a = d; d = c; c = b
                b = rotl32(t, r2[i])
            }

            // Round 3: H(b,c,d) = b^c^d, constant 0x6ED9EBA1
            let r3 = [3,9,11,15,3,9,11,15,3,9,11,15,3,9,11,15]
            let ord3 = [0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15]
            for (i in 0..16) {
                let fi = (b ^ c ^ d) & 0xFFFFFFFF
                let t = (a + fi + x[ord3[i]] + 0x6ED9EBA1) & 0xFFFFFFFF
                a = d; d = c; c = b
                b = rotl32(t, r3[i])
            }

            a = (a + aa) & 0xFFFFFFFF
            b = (b + bb) & 0xFFFFFFFF
            c = (c + cc) & 0xFFFFFFFF
            d = (d + dd) & 0xFFFFFFFF
            off += 64
        }

        let out = Array<Byte>(16, repeat: 0u8)
        putLE32(out, 0, a); putLE32(out, 4, b)
        putLE32(out, 8, c); putLE32(out, 12, d)
        out
    }

    // =========================================================================
    // MD5 (RFC 1321) — HMAC-MD5 所需
    // =========================================================================

    public static func md5(data: Array<Byte>): Array<Byte> {
        var msg = ArrayList<Byte>()
        for (b in data) { msg.add(b) }
        msg.add(0x80u8)
        while (msg.size % 64 != 56) { msg.add(0u8) }
        let bits = Int64(data.size) * 8
        for (i in 0..8) { msg.add(UInt8((bits >> (i * 8)) & 0xFF)) }

        var a: Int64 = 0x67452301
        var b: Int64 = 0xEFCDAB89
        var c: Int64 = 0x98BADCFE
        var d: Int64 = 0x10325476

        let s = [7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
                 5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
                 4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
                 6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21]
        let k = [
            0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
            0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
            0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
            0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
            0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
            0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
            0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
            0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
            0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
            0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
            0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
            0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
            0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
            0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
            0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
            0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
        ]

        var off = 0
        while (off < msg.size) {
            var x = Array<Int64>(16, repeat: 0)
            for (j in 0..16) {
                let o = off + j * 4
                x[j] = (Int64(msg[o]) | (Int64(msg[o+1]) << 8) |
                        (Int64(msg[o+2]) << 16) | (Int64(msg[o+3]) << 24)) & 0xFFFFFFFF
            }
            let aa = a; let bb = b; let cc = c; let dd = d

            for (i in 0..64) {
                var f: Int64
                var g: Int64
                if (i < 16) {
                    let nb = (b ^ 0xFFFFFFFF) & 0xFFFFFFFF
                    f = ((b & c) | (nb & d)) & 0xFFFFFFFF
                    g = i
                } else if (i < 32) {
                    let nd = (d ^ 0xFFFFFFFF) & 0xFFFFFFFF
                    f = ((d & b) | (nd & c)) & 0xFFFFFFFF
                    g = (5 * i + 1) % 16
                } else if (i < 48) {
                    f = (b ^ c ^ d) & 0xFFFFFFFF
                    g = (3 * i + 5) % 16
                } else {
                    let nd = (d ^ 0xFFFFFFFF) & 0xFFFFFFFF
                    f = (c ^ (b | nd)) & 0xFFFFFFFF
                    g = (7 * i) % 16
                }
                let t = (a + f + k[i] + x[g]) & 0xFFFFFFFF
                a = d; d = c; c = b
                b = (b + rotl32(t, s[i])) & 0xFFFFFFFF
            }

            a = (a + aa) & 0xFFFFFFFF
            b = (b + bb) & 0xFFFFFFFF
            c = (c + cc) & 0xFFFFFFFF
            d = (d + dd) & 0xFFFFFFFF
            off += 64
        }

        let out = Array<Byte>(16, repeat: 0u8)
        putLE32(out, 0, a); putLE32(out, 4, b)
        putLE32(out, 8, c); putLE32(out, 12, d)
        out
    }

    // =========================================================================
    // HMAC-MD5 — NTLMv2 所需
    // =========================================================================

    public static func hmacMd5(key: Array<Byte>, data: Array<Byte>): Array<Byte> {
        // 若 key 超过 64 字节则先做 MD5
        var k = if (key.size > 64) { md5(key) } else { key }

        // 填充到 64 字节
        var kPad = Array<Byte>(64, repeat: 0u8)
        for (i in 0..k.size) { kPad[i] = k[i] }

        var ipad = Array<Byte>(64, repeat: 0u8)
        var opad = Array<Byte>(64, repeat: 0u8)
        for (i in 0..64) {
            ipad[i] = kPad[i] ^ 0x36u8
            opad[i] = kPad[i] ^ 0x5Cu8
        }

        // inner = MD5(ipad || data)
        var innerMsg = ArrayList<Byte>()
        for (b in ipad) { innerMsg.add(b) }
        for (b in data) { innerMsg.add(b) }
        let inner = md5(innerMsg.toArray())

        // outer = MD5(opad || inner)
        var outerMsg = ArrayList<Byte>()
        for (b in opad) { outerMsg.add(b) }
        for (b in inner) { outerMsg.add(b) }
        md5(outerMsg.toArray())
    }

    // =========================================================================
    // 辅助：UTF-16LE 编码
    // =========================================================================

    public static func toUtf16LE(s: String): Array<Byte> {
        let result = ArrayList<Byte>()
        for (ch in s.toRuneArray()) {
            let cp = Int64(UInt32(ch))
            if (cp < 0x10000) {
                result.add(UInt8(cp & 0xFF))
                result.add(UInt8((cp >> 8) & 0xFF))
            } else {
                let v = cp - 0x10000
                let hi = 0xD800 + (v >> 10)
                let lo = 0xDC00 + (v & 0x3FF)
                result.add(UInt8(hi & 0xFF))
                result.add(UInt8((hi >> 8) & 0xFF))
                result.add(UInt8(lo & 0xFF))
                result.add(UInt8((lo >> 8) & 0xFF))
            }
        }
        result.toArray()
    }

    // =========================================================================
    // 辅助：随机字节
    // =========================================================================

    public static func randomBytes(n: Int64): Array<Byte> {
        let rng = Random()
        let out = Array<Byte>(n, repeat: 0u8)
        for (i in 0..n) {
            out[i] = UInt8(rng.nextInt64() & 0xFF)
        }
        out
    }

    // =========================================================================
    // 十六进制编码
    // =========================================================================

    public static func hexEncode(data: Array<Byte>): String {
        let hexChars = "0123456789abcdef".toRuneArray()
        var result = ""
        for (b in data) {
            let v = Int64(b) & 0xFF
            result += hexChars[(v >> 4) & 0xF].toString()
            result += hexChars[v & 0xF].toString()
        }
        result
    }

    // =========================================================================
    // 私有辅助函数
    // =========================================================================

    private static func rotl32(x: Int64, n: Int64): Int64 {
        ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF
    }

    private static func putLE32(buf: Array<Byte>, off: Int64, v: Int64): Unit {
        buf[off]     = UInt8(v & 0xFF)
        buf[off + 1] = UInt8((v >> 8) & 0xFF)
        buf[off + 2] = UInt8((v >> 16) & 0xFF)
        buf[off + 3] = UInt8((v >> 24) & 0xFF)
    }

    // 读取 little-endian 32-bit int
    public static func le32(buf: Array<Byte>, off: Int64): Int64 {
        (Int64(buf[off]) | (Int64(buf[off+1]) << 8) |
         (Int64(buf[off+2]) << 16) | (Int64(buf[off+3]) << 24)) & 0xFFFFFFFF
    }

    // 读取 little-endian 16-bit int
    public static func le16(buf: Array<Byte>, off: Int64): Int64 {
        (Int64(buf[off]) | (Int64(buf[off+1]) << 8)) & 0xFFFF
    }
}
