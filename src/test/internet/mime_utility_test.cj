package mail.test.internet

import mail.internet.*

// ─── encodeWord / decodeWord ─────────────────────────────────────────────────

@Test
public class MimeUtilityEncodeWordTest {

    @TestCase
    func pureAsciiNotEncoded(): Unit {
        let result = MimeUtility.encodeWord("Hello World")
        @Expect(result, "Hello World")
    }

    @TestCase
    func chineseBase64Encoded(): Unit {
        let result = MimeUtility.encodeWord("你好", charset: "UTF-8", encoding: Some("B"))
        @Assert(result.startsWith("=?UTF-8?B?") || result.startsWith("=?utf-8?b?"))
        @Assert(result.endsWith("?="))
    }

    @TestCase
    func japaneseBase64Encoded(): Unit {
        let result = MimeUtility.encodeWord("日本語", charset: "UTF-8", encoding: Some("B"))
        @Assert(result.contains("?B?") || result.contains("?b?"))
    }

    @TestCase
    func equalSignTrigersEncoding(): Unit {
        let result = MimeUtility.encodeWord("a=b")
        @Assert(result.contains("?="))
    }

    @TestCase
    func questionMarkTriggersEncoding(): Unit {
        let result = MimeUtility.encodeWord("a?b")
        @Assert(result.contains("?="))
    }

    @TestCase
    func quotedPrintableEncoding(): Unit {
        let result = MimeUtility.encodeWord("café", charset: "UTF-8", encoding: Some("Q"))
        @Assert(result.contains("?Q?") || result.contains("?q?"))
        @Assert(result.endsWith("?="))
    }
}

@Test
public class MimeUtilityDecodeWordTest {

    @TestCase
    func decodePlainTextIsIdentity(): Unit {
        @Expect(MimeUtility.decodeWord("Hello"), "Hello")
    }

    @TestCase
    func decodeBase64ChineseRoundTrips(): Unit {
        let orig = "你好世界"
        let encoded = MimeUtility.encodeWord(orig, charset: "UTF-8", encoding: Some("B"))
        @Expect(MimeUtility.decodeWord(encoded), orig)
    }

    @TestCase
    func decodeJapaneseRoundTrips(): Unit {
        let orig = "日本語テスト"
        let encoded = MimeUtility.encodeWord(orig, charset: "UTF-8", encoding: Some("B"))
        @Expect(MimeUtility.decodeWord(encoded), orig)
    }
}

// ─── encodeText / decodeText ─────────────────────────────────────────────────

@Test
public class MimeUtilityEncodeTextTest {

    @TestCase
    func asciiRoundTrips(): Unit {
        let text = "Hello, World!"
        @Expect(MimeUtility.decodeText(MimeUtility.encodeText(text)), text)
    }

    @TestCase
    func chineseRoundTrips(): Unit {
        let text = "你好，世界！"
        let encoded = MimeUtility.encodeText(text, charset: "UTF-8", encoding: Some("B"))
        @Assert(encoded.contains("UTF-8"))
        @Assert(encoded.contains("?B?"))
        @Expect(MimeUtility.decodeText(encoded), text)
    }

    @TestCase
    func mixedAsciiAndChineseRoundTrips(): Unit {
        let text = "Hello 你好 World 世界"
        let encoded = MimeUtility.encodeText(text, charset: "UTF-8", encoding: Some("B"))
        @Expect(MimeUtility.decodeText(encoded), text)
    }

    @TestCase
    func longTextRoundTrips(): Unit {
        let text = "这是一段很长的中文文本，用于测试 MIME 编码在处理长文本时的表现，编码后的文本可能会被分成多行。"
        let encoded = MimeUtility.encodeText(text, charset: "UTF-8", encoding: Some("B"))
        @Expect(MimeUtility.decodeText(encoded), text)
    }

    @TestCase
    func emptyStringRoundTrips(): Unit {
        @Expect(MimeUtility.decodeText(MimeUtility.encodeText("")), "")
    }

    @TestCase
    func specialCharsRoundTrips(): Unit {
        let text = "!@#$%^&*()"
        @Expect(MimeUtility.decodeText(MimeUtility.encodeText(text)), text)
    }
}

// ─── fold / unfold ───────────────────────────────────────────────────────────

@Test
public class MimeUtilityFoldTest {

    @TestCase
    func shortLineNotFolded(): Unit {
        let line = "Subject: Short"
        let result = MimeUtility.fold(line)
        @Expect(result, line)
    }

    @TestCase
    func longLineGetsFolded(): Unit {
        var long = "Subject: "
        for (_ in 0..80) { long += "A" }
        let folded = MimeUtility.fold(long)
        @Assert(folded.contains("\r\n "))
    }

    @TestCase
    func unfoldRemovesCrlfWhitespace(): Unit {
        let folded = "Subject: Long\r\n Subject Continuation"
        let result = MimeUtility.unfold(folded)
        @Assert(!result.contains("\r\n"))
        @Assert(result.contains("Long"))
        @Assert(result.contains("Continuation"))
    }

    @TestCase
    func foldThenUnfoldIsIdentity(): Unit {
        var long = "Subject: "
        for (_ in 0..80) { long += "X" }
        let unfolded = MimeUtility.unfold(MimeUtility.fold(long))
        @Assert(!unfolded.contains("\r\n"))
        @Assert(unfolded.contains("Subject:"))
    }
}
