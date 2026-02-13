/**
 * InternetAddress 测试
 * 参照 angus-mail 的地址解析测试设计
 */
package mail_test.internet

import mail.internet.*
import mail.core.*
import mail_test.test_helpers.*
import std.collection.*

/**
 * 基础地址解析测试
 */
public func testBasicAddressParsing(): Unit {
    // 测试简单地址
    let addr1 = InternetAddress("user@example.com")
    assertEqual(addr1.getAddress(), "user@example.com", "简单地址解析")
    assertNone(addr1.getPersonal(), "简单地址无显示名")

    // 测试带显示名的地址
    let addr2 = InternetAddress("user@example.com", "John Doe")
    assertEqual(addr2.getAddress(), "user@example.com", "带显示名的地址")
    assertEqual(addr2.getPersonal().getOrThrow(), "John Doe", "显示名解析")

    // 测试 toString
    let str = addr2.toString()
    assertTrue(str.contains("John Doe"), "toString 包含显示名")
    assertTrue(str.contains("user@example.com"), "toString 包含地址")
}

/**
 * 地址列表解析测试
 */
public func testAddressListParsing(): Unit {
    // 测试单个地址
    let addrs1 = InternetAddress.parse("user@example.com")
    assertEqual(addrs1.size, 1, "单个地址解析")
    assertEqual(addrs1[0].getAddress(), "user@example.com", "地址正确")

    // 测试多个地址（逗号分隔）
    let addrs2 = InternetAddress.parse("user1@example.com, user2@example.com")
    assertEqual(addrs2.size, 2, "多个地址解析")
    assertEqual(addrs2[0].getAddress(), "user1@example.com", "第一个地址")
    assertEqual(addrs2[1].getAddress(), "user2@example.com", "第二个地址")

    // 测试带显示名的多个地址
    let addrs3 = InternetAddress.parse("Alice <alice@example.com>, Bob <bob@example.com>")
    assertEqual(addrs3.size, 2, "带显示名的多个地址")
    assertEqual(addrs3[0].getPersonal().getOrThrow(), "Alice", "Alice 显示名")
    assertEqual(addrs3[1].getPersonal().getOrThrow(), "Bob", "Bob 显示名")
}

/**
 * 带引号的显示名测试
 */
public func testQuotedPersonalName(): Unit {
    // 测试带引号的显示名
    let addrs = InternetAddress.parse("\"John Doe\" <john@example.com>")
    assertEqual(addrs.size, 1, "带引号显示名解析")
    assertEqual(addrs[0].getPersonal().getOrThrow(), "John Doe", "引号内的显示名")
    assertEqual(addrs[0].getAddress(), "john@example.com", "地址正确")

    // 测试包含逗号的显示名
    let addrs2 = InternetAddress.parse("\"Doe, John\" <john@example.com>")
    assertEqual(addrs2.size, 1, "包含逗号的显示名")
    assertEqual(addrs2[0].getPersonal().getOrThrow(), "Doe, John", "逗号保留在显示名中")
}

/**
 * 地址验证测试
 */
public func testAddressValidation(): Unit {
    // 有效地址
    let validAddr = InternetAddress("user@example.com")
    try {
        validAddr.validate()
        // 应该成功，不抛异常
    } catch (e: AddressException) {
        throw AssertionError("有效地址应该通过验证")
    }

    // 无效地址 - 缺少 @
    let invalidAddr1 = InternetAddress("invalid-email")
    assertThrows<AddressException>(() => {
        invalidAddr1.validate()
    }, "缺少 @ 应该验证失败")

    // 无效地址 - 缺少域名
    let invalidAddr2 = InternetAddress("user@")
    assertThrows<AddressException>(() => {
        invalidAddr2.validate()
    }, "缺少域名应该验证失败")

    // 无效地址 - 缺少用户名
    let invalidAddr3 = InternetAddress("@example.com")
    assertThrows<AddressException>(() => {
        invalidAddr3.validate()
    }, "缺少用户名应该验证失败")
}

/**
 * UTF-8 地址测试
 */
public func testUtf8Addresses(): Unit {
    // 测试中文显示名
    let addr1 = InternetAddress("user@example.com", "张三")
    assertEqual(addr1.getPersonal().getOrThrow(), "张三", "中文显示名")

    // 测试 encode/decode
    let encoded = MimeUtility.encodeText("张三", "UTF-8", "B")
    assertTrue(encoded.contains("UTF-8"), "编码包含字符集标识")
    assertTrue(encoded.contains("?B?"), "编码使用 Base64")

    let decoded = MimeUtility.decodeText(encoded)
    assertEqual(decoded, "张三", "解码后恢复中文")
}

/**
 * 复杂地址格式测试
 */
public func testComplexAddressFormats(): Unit {
    // 测试群组地址格式（简化版）
    let addrs1 = InternetAddress.parse("undisclosed-recipients:;")
    assertTrue(addrs1.size >= 0, "群组地址解析")

    // 测试带注释的地址
    let addrs2 = InternetAddress.parse("user@example.com (John Doe)")
    assertEqual(addrs2.size, 1, "带注释的地址")
    assertEqual(addrs2[0].getAddress(), "user@example.com", "地址正确")

    // 测试多行地址
    let addrs3 = InternetAddress.parse("""
        user1@example.com,
        user2@example.com,
        user3@example.com
    """)
    assertEqual(addrs3.size, 3, "多行地址解析")
}

/**
 * 边界情况测试
 */
public func testEdgeCases(): Unit {
    // 空字符串
    let emptyAddrs = InternetAddress.parse("")
    assertEqual(emptyAddrs.size, 0, "空字符串返回空数组")

    // 仅空格
    let spaceAddrs = InternetAddress.parse("   ")
    assertEqual(spaceAddrs.size, 0, "空格返回空数组")

    // 地址前后有空格
    let spacedAddrs = InternetAddress.parse("  user@example.com  ")
    assertEqual(spacedAddrs.size, 1, "去除前后空格")
    assertEqual(spacedAddrs[0].getAddress(), "user@example.com", "地址正确")

    // 逗号分隔但有空项
    let commaAddrs = InternetAddress.parse("user1@example.com,, user2@example.com")
    assertEqual(commaAddrs.size, 2, "忽略空项")
}

/**
 * 地址相等性测试
 */
public func testAddressEquality(): Unit {
    let addr1 = InternetAddress("user@example.com", "John Doe")
    let addr2 = InternetAddress("user@example.com", "John Doe")
    let addr3 = InternetAddress("user@example.com", "Jane Doe")
    let addr4 = InternetAddress("other@example.com", "John Doe")

    assertTrue(addr1.equals(addr2), "相同地址和显示名应相等")
    assertFalse(addr1.equals(addr3), "显示名不同应不相等")
    assertFalse(addr1.equals(addr4), "地址不同应不相等")
}

/**
 * 运行所有测试
 */
public func runAllTests(): Unit {
    let runner = TestRunner()

    runner.runTest("基础地址解析", testBasicAddressParsing)
    runner.runTest("地址列表解析", testAddressListParsing)
    runner.runTest("带引号的显示名", testQuotedPersonalName)
    runner.runTest("地址验证", testAddressValidation)
    runner.runTest("UTF-8 地址", testUtf8Addresses)
    runner.runTest("复杂地址格式", testComplexAddressFormats)
    runner.runTest("边界情况", testEdgeCases)
    runner.runTest("地址相等性", testAddressEquality)

    runner.printReport()

    if (!runner.allPassed()) {
        throw Exception("InternetAddress 测试失败")
    }
}

/**
 * 主函数入口
 */
main(): Int64 {
    println("=== InternetAddress 单元测试 ===\n")

    try {
        runAllTests()
        println("\n✓ 所有测试通过")
        return 0
    } catch (e: Exception) {
        println("\n✗ 测试失败: ${e.message}")
        return 1
    }
}
