package mail.test.util

import mail.util.*

// ─── MD5 ─────────────────────────────────────────────────────────────────────

@Test
public class Md5Test {

    @TestCase
    func emptyStringVector(): Unit {
        @Expect(CryptoUtil.hexEncode(CryptoUtil.md5("".toArray())),
                "d41d8cd98f00b204e9800998ecf8427e")
    }

    @TestCase
    func abcVector(): Unit {
        @Expect(CryptoUtil.hexEncode(CryptoUtil.md5("abc".toArray())),
                "900150983cd24fb0d6963f7d28e17f72")
    }

    @TestCase
    func helloVector(): Unit {
        @Expect(CryptoUtil.hexEncode(CryptoUtil.md5("hello".toArray())),
                "5d41402abc4b2a76b9719d911017c592")
    }

    @TestCase
    func outputIs16Bytes(): Unit {
        for (s in ["", "a", "abc", "message digest"]) {
            @Expect(CryptoUtil.md5(s.toArray()).size, 16)
        }
    }

    @TestCase
    func hexOutputIs32Chars(): Unit {
        @Expect(CryptoUtil.hexEncode(CryptoUtil.md5("test".toArray())).size, 32)
    }
}

// ─── MD4 ─────────────────────────────────────────────────────────────────────

@Test
public class Md4Test {

    @TestCase
    func emptyStringVector(): Unit {
        @Expect(CryptoUtil.hexEncode(CryptoUtil.md4("".toArray())),
                "31d6cfe0d16ae931b73c59d7e0c089c0")
    }

    @TestCase
    func outputIs16Bytes(): Unit {
        @Expect(CryptoUtil.md4("Password".toArray()).size, 16)
    }

    @TestCase
    func differentInputsDifferentOutputs(): Unit {
        let h1 = CryptoUtil.hexEncode(CryptoUtil.md4("abc".toArray()))
        let h2 = CryptoUtil.hexEncode(CryptoUtil.md4("xyz".toArray()))
        @Assert(h1 != h2)
    }
}

// ─── HMAC-MD5 ────────────────────────────────────────────────────────────────

@Test
public class HmacMd5Test {

    @TestCase
    func outputIs16Bytes(): Unit {
        let key = Array<Byte>(16, repeat: 0x0bu8)
        @Expect(CryptoUtil.hmacMd5(key, "Hi There".toArray()).size, 16)
    }

    @TestCase
    func hexOutputIs32LowercaseHexChars(): Unit {
        let key = Array<Byte>(16, repeat: 0x0bu8)
        let result = CryptoUtil.hexEncode(CryptoUtil.hmacMd5(key, "Hi There".toArray()))
        @Expect(result.size, 32)
        for (ch in result.toRuneArray()) {
            let c = Int64(UInt32(ch))
            @Assert((c >= 48 && c <= 57) || (c >= 97 && c <= 102))
        }
    }

    @TestCase
    func differentKeysDifferentHmacs(): Unit {
        let data = "message".toArray()
        let h1 = CryptoUtil.hexEncode(CryptoUtil.hmacMd5(Array<Byte>(16, repeat: 0x0bu8), data))
        let h2 = CryptoUtil.hexEncode(CryptoUtil.hmacMd5(Array<Byte>(16, repeat: 0x0cu8), data))
        @Assert(h1 != h2)
    }

    @TestCase
    func keyLongerThan64BytesIsHashedFirst(): Unit {
        let longKey = Array<Byte>(100, repeat: 0xAAu8)
        let result = CryptoUtil.hmacMd5(longKey, "data".toArray())
        @Expect(result.size, 16)
    }
}

// ─── hexEncode ───────────────────────────────────────────────────────────────

@Test
public class HexEncodeTest {

    @TestCase
    func basicBytesEncodedCorrectly(): Unit {
        let input: Array<Byte> = [0x00u8, 0xFFu8, 0xABu8]
        @Expect(CryptoUtil.hexEncode(input), "00ffab")
    }

    @TestCase
    func singleByteBoundaries(): Unit {
        @Expect(CryptoUtil.hexEncode([0x00u8]), "00")
        @Expect(CryptoUtil.hexEncode([0x0Fu8]), "0f")
        @Expect(CryptoUtil.hexEncode([0xF0u8]), "f0")
        @Expect(CryptoUtil.hexEncode([0xFFu8]), "ff")
    }

    @TestCase
    func emptyArrayReturnsEmptyString(): Unit {
        @Expect(CryptoUtil.hexEncode(Array<Byte>(0, repeat: 0u8)), "")
    }

    @TestCase
    func outputIsAlwaysLowercase(): Unit {
        let result = CryptoUtil.hexEncode([0xABu8, 0xCDu8, 0xEFu8])
        @Expect(result, "abcdef")
    }
}

// ─── toUtf16LE ───────────────────────────────────────────────────────────────

@Test
public class Utf16LeTest {

    @TestCase
    func asciiCharsAreTwoBytesLittleEndian(): Unit {
        let result = CryptoUtil.toUtf16LE("AB")
        @Expect(result.size, 4)
        @Expect(result[0], 0x41u8)
        @Expect(result[1], 0x00u8)
        @Expect(result[2], 0x42u8)
        @Expect(result[3], 0x00u8)
    }

    @TestCase
    func chineseCharU4E2D(): Unit {
        // U+4E2D = "中" → LE bytes: 0x2D 0x4E
        let result = CryptoUtil.toUtf16LE("中")
        @Expect(result.size, 2)
        @Expect(result[0], 0x2Du8)
        @Expect(result[1], 0x4Eu8)
    }

    @TestCase
    func emptyStringReturnsEmpty(): Unit {
        @Expect(CryptoUtil.toUtf16LE("").size, 0)
    }
}

// ─── randomBytes ─────────────────────────────────────────────────────────────

@Test
public class RandomBytesTest {

    @TestCase
    func producesRequestedLength(): Unit {
        @Expect(CryptoUtil.randomBytes(16).size, 16)
        @Expect(CryptoUtil.randomBytes(8).size, 8)
        @Expect(CryptoUtil.randomBytes(0).size, 0)
    }

    @TestCase
    func twoCallsProduceDifferentValues(): Unit {
        let r1 = CryptoUtil.randomBytes(16)
        let r2 = CryptoUtil.randomBytes(16)
        var same = true
        for (i in 0..16) {
            if (r1[i] != r2[i]) { same = false; break }
        }
        @Assert(!same)
    }
}

// ─── Base64 ──────────────────────────────────────────────────────────────────

@Test
public class Base64EncodeTest {

    @TestCase
    func knownVectors(): Unit {
        @Expect(Base64Util.encode("Hello".toArray()),       "SGVsbG8=")
        @Expect(Base64Util.encode("Man".toArray()),         "TWFu")
        @Expect(Base64Util.encode("Ma".toArray()),          "TWE=")
        @Expect(Base64Util.encode("M".toArray()),           "TQ==")
    }

    @TestCase
    func emptyArrayEncodesEmpty(): Unit {
        @Expect(Base64Util.encode(Array<Byte>(0, repeat: 0u8)), "")
    }

    @TestCase
    func encodeStringMatchesEncodeBytes(): Unit {
        let s = "test string"
        @Expect(Base64Util.encodeString(s), Base64Util.encode(s.toArray()))
    }
}

@Test
public class Base64DecodeTest {

    @TestCase
    func knownVector(): Unit {
        let result = Base64Util.decode("SGVsbG8=")
        let expected = "Hello".toArray()
        @Expect(result.size, expected.size)
        for (i in 0..expected.size) { @Expect(result[i], expected[i]) }
    }

    @TestCase
    func ignoresWhitespaceAndNewlines(): Unit {
        let clean  = Base64Util.decode("SGVsbG8=")
        let spaces = Base64Util.decode("S G V s b G 8 =")
        let crlf   = Base64Util.decode("SGVs\r\nbG8=")
        @Expect(spaces.size, clean.size)
        @Expect(crlf.size,   clean.size)
    }

    @TestCase
    func decodeToStringRoundTrips(): Unit {
        for (s in ["Hello", "你好世界", "test 123 !@#", ""]) {
            @Expect(Base64Util.decodeToString(Base64Util.encodeString(s)), s)
        }
    }
}

@Test
public class Base64RoundtripTest {

    @TestCase
    func largeBinaryDataRoundTrips(): Unit {
        let data = Array<Byte>(1024, repeat: 0u8)
        for (i in 0..1024) { data[i] = UInt8(i % 256) }
        let decoded = Base64Util.decode(Base64Util.encode(data))
        @Expect(decoded.size, 1024)
        for (i in 0..1024) { @Expect(decoded[i], data[i]) }
    }

    @TestCase
    func authPlainNullSeparatedFormat(): Unit {
        let authStr = "\u{0000}user@example.com\u{0000}secretpass"
        let encoded = Base64Util.encodeString(authStr)
        @Assert(!encoded.isEmpty())
        @Expect(Base64Util.decodeToString(encoded), authStr)
    }
}
