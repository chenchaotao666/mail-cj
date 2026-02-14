/**
 * Session 测试
 * 使用仓颉官方 unittest 框架
 * 参照 angus-mail 的 Session 测试设计
 */
package mail.test.core

import mail.core.*
import std.collection.*

@Test
public class SessionTest {
    /**
     * 测试 Session 创建
     */
    @TestCase
    func testSessionCreation(): Unit {
        let props = HashMap<String, String>()
        props["mail.smtp.host"] = "smtp.example.com"
        props["mail.smtp.port"] = "587"

        let session = Session.getInstance(props)

        // 验证属性
        let host = session.getProperty("mail.smtp.host")
        @Expect(host.getOrThrow(), "smtp.example.com")
    }

    /**
     * 测试默认 Session（单例）
     */
    @TestCase
    func testDefaultSession(): Unit {
        let props = HashMap<String, String>()
        props["mail.smtp.host"] = "smtp.example.com"

        let session1 = Session.getDefaultInstance(props)
        let session2 = Session.getDefaultInstance(props)

        // 验证 Session 创建成功
        @Assert(session1.getProperty("mail.smtp.host").isSome())
        @Assert(session2.getProperty("mail.smtp.host").isSome())
        // TODO: 验证是同一个实例（需要支持引用相等性比较）
    }

    /**
     * 测试属性管理 - 获取单个属性
     */
    @TestCase
    func testPropertyGet(): Unit {
        let props = HashMap<String, String>()
        props["mail.smtp.host"] = "smtp.example.com"
        props["mail.smtp.port"] = "587"
        props["mail.smtp.auth"] = "true"

        let session = Session.getInstance(props)

        @Expect(session.getProperty("mail.smtp.host").getOrThrow(), "smtp.example.com")
        @Expect(session.getProperty("mail.smtp.port").getOrThrow(), "587")
    }

    /**
     * 测试属性管理 - 不存在的属性
     */
    @TestCase
    func testPropertyNonExistent(): Unit {
        let props = HashMap<String, String>()
        let session = Session.getInstance(props)

        @Expect(session.getProperty("mail.smtp.nonexist"), None)
    }

    /**
     * 测试属性管理 - 带默认值
     */
    @TestCase
    func testPropertyWithDefault(): Unit {
        let props = HashMap<String, String>()
        let session = Session.getInstance(props)

        @Expect(session.getProperty("mail.smtp.nonexist", "default"), "default")
    }

    // 注：以下 Transport 测试需要导入 mail.smtp 模块，暂时注释
    // - testGetTransportDefault: 需要注册 SMTP transport 工厂
    // - testGetTransportSMTP: 需要注册 SMTP transport 工厂

    // /**
    //  * 测试 Transport 获取 - 默认
    //  */
    // @TestCase
    // func testGetTransportDefault(): Unit {
    //     let props = HashMap<String, String>()
    //     props["mail.smtp.host"] = "smtp.example.com"
    //
    //     let session = Session.getInstance(props)
    //     let transport = session.getTransport()
    //
    //     // Transport 对象创建成功
    // }
    //
    // /**
    //  * 测试 Transport 获取 - SMTP
    //  */
    // @TestCase
    // func testGetTransportSMTP(): Unit {
    //     let props = HashMap<String, String>()
    //     props["mail.smtp.host"] = "smtp.example.com"
    //
    //     let session = Session.getInstance(props)
    //     let transport = session.getTransport("smtp")
    //
    //     // Transport 对象创建成功
    // }

    /**
     * 测试调试模式 - 默认关闭
     */
    @TestCase
    func testDebugModeDefaultOff(): Unit {
        let props = HashMap<String, String>()
        let session = Session.getInstance(props)

        @Assert(!session.getDebug())
    }

    /**
     * 测试调试模式 - 开启
     */
    @TestCase
    func testDebugModeTurnOn(): Unit {
        let props = HashMap<String, String>()
        let session = Session.getInstance(props)

        session.setDebug(true)
        @Assert(session.getDebug())
    }

    /**
     * 测试调试模式 - 关闭
     */
    @TestCase
    func testDebugModeTurnOff(): Unit {
        let props = HashMap<String, String>()
        let session = Session.getInstance(props)

        session.setDebug(true)
        session.setDebug(false)
        @Assert(!session.getDebug())
    }

    /**
     * 测试属性设置 - 运行时设置
     */
    @TestCase
    func testPropertySet(): Unit {
        let props = HashMap<String, String>()
        props["mail.smtp.host"] = "smtp.example.com"

        let session = Session.getInstance(props)
        session.setProperty("mail.smtp.port", "587")

        @Expect(session.getProperty("mail.smtp.port").getOrThrow(), "587")
    }

    /**
     * 测试边界情况 - 空属性创建
     */
    @TestCase
    func testEmptyProps(): Unit {
        let emptyProps = HashMap<String, String>()
        let session = Session.getInstance(emptyProps)

        // 验证 Session 创建成功
        @Assert(session.getProperty("nonexist").isNone())
    }

    /**
     * 测试边界情况 - 不存在的协议
     */
    @TestCase
    func testNonExistentProtocol(): Unit {
        try {
            let props = HashMap<String, String>()
            let session = Session.getInstance(props)
            session.getTransport("nonexistent-protocol")
            @Assert(false)  // 应该抛出异常
        } catch (e: MessagingException) {
            @Assert(true)  // 预期行为
        }
    }
}
