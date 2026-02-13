/**
 * MimeUtility 测试
 * 参照 angus-mail 的 MIME 编码测试设计
 */
package mail_test.internet

import mail.internet.*
import mail_test.test_helpers.*
import std.collection.*

/**
 * 测试 Base64 编码
 */
public func testBase64Encoding(): Unit {
    // 测试简单 ASCII 文本
    let text1 = "Hello, World!"
    let encoded1 = MimeUtility.encodeText(text1, "UTF-8", "B")
    assertTrue(encoded1.contains("?B?"), "Base64 编码标识")
    let decoded1 = MimeUtility.decodeText(encoded1)
    assertEqual(decoded1, text1, "Base64 编解码一致")

    // 测试中文文本
    let text2 = "你好，世界！"
    let encoded2 = MimeUtility.encodeText(text2, "UTF-8", "B")
    assertTrue(encoded2.contains("UTF-8"), "字符集标识")
    assertTrue(encoded2.contains("?B?"), "Base64 标识")
    let decoded2 = MimeUtility.decodeText(encoded2)
    assertEqual(decoded2, text2, "中文 Base64 编解码")
}

/**
 * 测试 Quoted-Printable 编码
 */
public func testQuotedPrintableEncoding(): Unit {
    // 测试 QP 编码
    let text1 = "Hello, World!"
    let encoded1 = MimeUtility.encodeText(text1, "UTF-8", "Q")
    assertTrue(encoded1.contains("?Q?"), "QP 编码标识")
    let decoded1 = MimeUtility.decodeText(encoded1)
    assertEqual(decoded1, text1, "QP 编解码一致")

    // 测试包含特殊字符的文本
    let text2 = "Hello, 你好!"
    let encoded2 = MimeUtility.encodeText(text2, "UTF-8", "Q")
    let decoded2 = MimeUtility.decodeText(encoded2)
    assertEqual(decoded2, text2, "QP 特殊字符编解码")
}

/**
 * 测试自动编码选择
 */
public func testAutoEncodingSelection(): Unit {
    // ASCII 文本应该不编码或使用简单编码
    let ascii = "Simple ASCII Text"
    let encodedAscii = MimeUtility.encodeText(ascii)
    let decodedAscii = MimeUtility.decodeText(encodedAscii)
    assertEqual(decodedAscii, ascii, "ASCII 自动编码")

    // 非 ASCII 文本应该自动选择合适的编码
    let nonAscii = "中文文本测试"
    let encodedNonAscii = MimeUtility.encodeText(nonAscii)
    assertTrue(
        encodedNonAscii.contains("?B?") || encodedNonAscii.contains("?Q?"),
        "非 ASCII 自动选择编码"
    )
    let decodedNonAscii = MimeUtility.decodeText(encodedNonAscii)
    assertEqual(decodedNonAscii, nonAscii, "非 ASCII 自动编解码")
}

/**
 * 测试编码词（encodeWord）
 */
public func testEncodeWord(): Unit {
    // 测试单个词
    let word1 = "Hello"
    let encodedWord1 = MimeUtility.encodeWord(word1, "UTF-8", "B")
    let decodedWord1 = MimeUtility.decodeWord(encodedWord1)
    assertEqual(decodedWord1, word1, "单词编解码")

    // 测试中文词
    let word2 = "你好"
    let encodedWord2 = MimeUtility.encodeWord(word2, "UTF-8", "B")
    let decodedWord2 = MimeUtility.decodeWord(encodedWord2)
    assertEqual(decodedWord2, word2, "中文词编解码")
}

/**
 * 测试多个编码词
 */
public func testMultipleEncodedWords(): Unit {
    // 测试包含多个编码词的文本
    let text = "=?UTF-8?B?5L2g5aW9?= =?UTF-8?B?5LiW55WM?="
    let decoded = MimeUtility.decodeText(text)
    assertContains(decoded, "你好", "解码多个编码词")
}

/**
 * 测试邮件头折叠
 */
public func testHeaderFolding(): Unit {
    // 测试短文本（不需要折叠）
    let shortText = "Subject: Short subject"
    let folded1 = MimeUtility.fold(0, shortText)
    assertEqual(folded1, shortText, "短文本不折叠")

    // 测试长文本（需要折叠）
    let longText = "Subject: " + "A".repeat(100)
    let folded2 = MimeUtility.fold(0, longText)
    assertTrue(folded2.contains("\r\n "), "长文本折叠包含换行")

    // 测试展开
    let unfolded = MimeUtility.unfold(folded2)
    assertFalse(unfolded.contains("\r\n"), "展开后无换行")
}

/**
 * 测试字符集转换
 */
public func testCharsetConversion(): Unit {
    // 测试获取默认字符集
    let defaultCharset = MimeUtility.getDefaultMIMECharset()
    assertTrue(defaultCharset.length > 0, "默认字符集非空")

    // 测试 MIME 字符集转换
    let mimeCharset = MimeUtility.mimeCharset("utf8")
    assertTrue(
        mimeCharset == "UTF-8" || mimeCharset == "utf-8",
        "MIME 字符集转换"
    )
}

/**
 * 测试引用处理
 */
public func testQuoting(): Unit {
    // 测试不需要引用的文本
    let simple = "simple"
    let quoted1 = MimeUtility.quote(simple, " \"")
    assertEqual(quoted1, simple, "简单文本不引用")

    // 测试需要引用的文本
    let complex = "complex text"
    let quoted2 = MimeUtility.quote(complex, " \"")
    assertTrue(quoted2.startsWith("\""), "复杂文本添加引号")
    assertTrue(quoted2.endsWith("\""), "复杂文本添加引号")
}

/**
 * 测试各种编码的边界情况
 */
public func testEncodingEdgeCases(): Unit {
    // 空字符串
    let empty = ""
    let encodedEmpty = MimeUtility.encodeText(empty)
    let decodedEmpty = MimeUtility.decodeText(encodedEmpty)
    assertEqual(decodedEmpty, empty, "空字符串编解码")

    // 只有空格
    let spaces = "   "
    let encodedSpaces = MimeUtility.encodeText(spaces)
    let decodedSpaces = MimeUtility.decodeText(encodedSpaces)
    assertEqual(decodedSpaces, spaces, "空格编解码")

    // 特殊字符
    let special = "!@#$%^&*()"
    let encodedSpecial = MimeUtility.encodeText(special)
    let decodedSpecial = MimeUtility.decodeText(encodedSpecial)
    assertEqual(decodedSpecial, special, "特殊字符编解码")
}

/**
 * 测试混合内容编码
 */
public func testMixedContent(): Unit {
    // 测试 ASCII 和非 ASCII 混合
    let mixed = "Hello 你好 World 世界"
    let encoded = MimeUtility.encodeText(mixed, "UTF-8", "B")
    let decoded = MimeUtility.decodeText(encoded)
    assertEqual(decoded, mixed, "混合内容编解码")

    // 测试数字和字母混合
    let alphaNum = "Test123测试456"
    let encodedAlphaNum = MimeUtility.encodeText(alphaNum, "UTF-8", "B")
    let decodedAlphaNum = MimeUtility.decodeText(encodedAlphaNum)
    assertEqual(decodedAlphaNum, alphaNum, "数字字母混合编解码")
}

/**
 * 测试长文本编码
 */
public func testLongTextEncoding(): Unit {
    // 测试超长文本
    let longText = "这是一段很长的中文文本，用于测试 MIME 编码在处理长文本时的表现。" +
                   "编码后的文本可能会被分成多行，解码时需要正确处理这种情况。"
    let encoded = MimeUtility.encodeText(longText, "UTF-8", "B")
    let decoded = MimeUtility.decodeText(encoded)
    assertEqual(decoded, longText, "长文本编解码")
}

/**
 * 运行所有测试
 */
public func runAllTests(): Unit {
    let runner = TestRunner()

    runner.runTest("Base64 编码", testBase64Encoding)
    runner.runTest("Quoted-Printable 编码", testQuotedPrintableEncoding)
    runner.runTest("自动编码选择", testAutoEncodingSelection)
    runner.runTest("编码词", testEncodeWord)
    runner.runTest("多个编码词", testMultipleEncodedWords)
    runner.runTest("邮件头折叠", testHeaderFolding)
    runner.runTest("字符集转换", testCharsetConversion)
    runner.runTest("引用处理", testQuoting)
    runner.runTest("编码边界情况", testEncodingEdgeCases)
    runner.runTest("混合内容编码", testMixedContent)
    runner.runTest("长文本编码", testLongTextEncoding)

    runner.printReport()

    if (!runner.allPassed()) {
        throw Exception("MimeUtility 测试失败")
    }
}

/**
 * 主函数入口
 */
main(): Int64 {
    println("=== MimeUtility 单元测试 ===\n")

    try {
        runAllTests()
        println("\n✓ 所有测试通过")
        return 0
    } catch (e: Exception) {
        println("\n✗ 测试失败: ${e.message}")
        return 1
    }
}
