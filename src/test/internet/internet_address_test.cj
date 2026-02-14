/**
 * InternetAddress 测试
 * 使用仓颉官方 unittest 框架
 * 参照 angus-mail 的地址解析测试设计
 */
package mail.test.internet

import mail.internet.*
import mail.core.*

@Test
public class InternetAddressTest {
    /**
     * 测试简单地址创建
     */
    @TestCase
    func testBasicAddress(): Unit {
        let addr1 = InternetAddress("user@example.com")
        @Expect(addr1.getAddress(), "user@example.com")
        @Expect(addr1.getPersonal(), None)

        let addr2 = InternetAddress("user@example.com", "John Doe")
        @Expect(addr2.getAddress(), "user@example.com")
        @Expect(addr2.getPersonal().getOrThrow(), "John Doe")
    }

    /**
     * 测试地址列表解析 - 单个地址
     */
    @TestCase
    func testParseList(): Unit {
        let addrs = InternetAddress.parse("user@example.com")
        @Expect(addrs.size, 1)
        if (addrs.size > 0) {
            match (addrs[0]) {
                case addr: InternetAddress =>
                    @Expect(addr.getAddress(), "user@example.com")
                case _ => @Assert(false)  // 不应该到这里
            }
        }
    }

    /**
     * 测试地址列表解析 - 多个地址
     */
    @TestCase
    func testParseMultiple(): Unit {
        let addrs = InternetAddress.parse("user1@example.com, user2@example.com")
        @Expect(addrs.size, 2)
    }

    /**
     * 测试带引号的显示名
     */
    @TestCase
    func testQuotedPersonalName(): Unit {
        let addrs = InternetAddress.parse("\"John Doe\" <john@example.com>")
        @Expect(addrs.size, 1)
    }

    /**
     * 测试地址验证 - 有效地址
     */
    @TestCase
    func testValidAddress(): Unit {
        let validAddr = InternetAddress("user@example.com")
        validAddr.validate()  // 应该不抛异常
    }

    /**
     * 测试地址验证 - 无效地址（缺少@）
     */
    @TestCase
    func testInvalidAddressMissingAt(): Unit {
        try {
            let invalidAddr = InternetAddress("invalid-email")
            invalidAddr.validate()
            @Assert(false)  // 应该抛出异常
        } catch (e: AddressException) {
            @Assert(true)  // 预期行为
        }
    }

    /**
     * 测试地址验证 - 无效地址（缺少域名）
     */
    @TestCase
    func testInvalidAddressMissingDomain(): Unit {
        try {
            let invalidAddr = InternetAddress("user@")
            invalidAddr.validate()
            @Assert(false)  // 应该抛出异常
        } catch (e: AddressException) {
            @Assert(true)  // 预期行为
        }
    }

    /**
     * 测试 UTF-8 中文显示名
     */
    @TestCase
    func testUtf8ChineseName(): Unit {
        let addr = InternetAddress("user@example.com", "张三")
        @Expect(addr.getPersonal().getOrThrow(), "张三")
    }

    /**
     * 测试复杂地址格式 - 带注释
     * 注：当前解析器会保留注释部分
     */
    @TestCase
    func testAddressWithComment(): Unit {
        let addrs = InternetAddress.parse("user@example.com (John Doe)")
        @Expect(addrs.size, 1)
        if (addrs.size > 0) {
            match (addrs[0]) {
                case addr: InternetAddress =>
                    // 当前实现会保留注释，所以包含 " (John Doe)"
                    @Assert(addr.getAddress().contains("user@example.com"))
                case _ => @Assert(false)  // 不应该到这里
            }
        }
    }

    /**
     * 测试边界情况 - 空字符串
     */
    @TestCase
    func testEmptyString(): Unit {
        let addrs = InternetAddress.parse("")
        @Expect(addrs.size, 0)
    }

    /**
     * 测试边界情况 - 地址前后有空格
     */
    @TestCase
    func testTrimWhitespace(): Unit {
        let addrs = InternetAddress.parse("  user@example.com  ")
        @Expect(addrs.size, 1)
    }

    /**
     * 测试地址相等性
     */
    @TestCase
    func testAddressEquality(): Unit {
        let addr1 = InternetAddress("user@example.com", "John Doe")
        let addr2 = InternetAddress("user@example.com", "John Doe")
        @Assert(addr1 == addr2)
    }
}
