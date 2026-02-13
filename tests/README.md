# Cangjie Mail 单元测试

本目录包含 Cangjie Mail 库的完整单元测试套件，测试设计参照 [Eclipse Angus Mail](https://github.com/eclipse-ee4j/angus-mail) 的测试用例。

## 目录结构

```
tests/
├── README.md                    # 本文档
├── run_all_tests.cj            # 测试套件主入口
└── mail_test/
    ├── test_helpers/           # 测试辅助工具
    │   └── test_utils.cj      # 测试框架和断言函数
    ├── core/                   # 核心模块测试
    │   └── session_test.cj    # Session 测试
    ├── internet/               # Internet 邮件规范测试
    │   ├── internet_address_test.cj  # InternetAddress 测试
    │   ├── mime_utility_test.cj      # MimeUtility 测试
    │   ├── mime_message_test.cj      # MimeMessage 测试 (待实现)
    │   └── mime_multipart_test.cj    # MimeMultipart 测试 (待实现)
    ├── smtp/                   # SMTP 协议测试 (待实现)
    │   ├── smtp_transport_test.cj
    │   └── smtp_auth_test.cj
    ├── activation/             # 数据激活框架测试 (待实现)
    │   ├── data_source_test.cj
    │   └── data_handler_test.cj
    └── util/                   # 工具模块测试 (待实现)
        └── base64_test.cj
```

## 运行测试

### 运行所有测试

```bash
cd tests
cjpm run
```

### 运行单个测试模块

```bash
# Session 测试
cjpm run --run-args="mail_test/core/session_test"

# InternetAddress 测试
cjpm run --run-args="mail_test/internet/internet_address_test"

# MimeUtility 测试
cjpm run --run-args="mail_test/internet/mime_utility_test"
```

## 测试覆盖范围

### ✅ 已实现

**Core 模块**
- [x] Session - 会话管理测试
  - Session 创建和单例模式
  - 属性管理
  - Transport 获取
  - Provider 注册
  - 调试模式
  - Authenticator

**Internet 模块**
- [x] InternetAddress - 邮件地址测试
  - 基础地址解析
  - 地址列表解析
  - 带引号显示名
  - 地址验证
  - UTF-8 支持
  - 复杂格式和边界情况

- [x] MimeUtility - MIME 编码测试
  - Base64 编码/解码
  - Quoted-Printable 编码
  - 自动编码选择
  - 编码词处理
  - 邮件头折叠/展开
  - 字符集转换
  - 混合内容编码

### 🚧 待实现

**Internet 模块**
- [ ] MimeMessage - MIME 消息测试
  - 消息创建和属性
  - 发件人/收件人设置
  - 主题和内容
  - 邮件头操作
  - 附件处理

- [ ] MimeMultipart - 多部分消息测试
  - Multipart 创建
  - BodyPart 添加/移除
  - 边界字符串处理
  - Mixed/Alternative/Related 类型

- [ ] MimeBodyPart - 消息体部分测试
  - 内容设置
  - 附件文件
  - Content-Type/Disposition
  - 内嵌图片

**SMTP 模块**
- [ ] SMTPTransport - SMTP 传输测试
  - 连接管理
  - SMTP 命令
  - 认证机制
  - 错误处理

- [ ] SMTP Authentication - 认证测试
  - LOGIN 认证
  - PLAIN 认证
  - 认证失败处理

**TLS 模块**
- [ ] TlsSocket - TLS 连接测试
  - SSL/TLS 握手
  - 证书验证
  - 加密通信

**Activation 模块**
- [ ] DataSource - 数据源测试
  - FileDataSource
  - ByteArrayDataSource
  - 输入/输出流

- [ ] DataHandler - 数据处理器测试
  - 数据包装
  - MIME 类型处理
  - 内容访问

**Util 模块**
- [ ] Base64 - Base64 编解码测试
  - 标准 Base64
  - MIME Base64
  - URL 安全 Base64

## 测试框架

测试框架位于 `test_helpers/test_utils.cj`，提供以下功能：

### 断言函数

```cangjie
assertEqual(actual, expected, message)    // 断言相等
assertTrue(condition, message)            // 断言为真
assertFalse(condition, message)           // 断言为假
assertNone(value, message)                // 断言为 None
assertNotNone(value, message)             // 断言不为 None
assertThrows<E>(action, message)          // 断言抛出异常
assertContains(haystack, needle, message) // 断言包含
assertArrayEqual(actual, expected, msg)   // 断言数组相等
```

### 测试运行器

```cangjie
let runner = TestRunner()
runner.runTest("测试名称", testFunction)
runner.printReport()
```

## 编写新测试

### 1. 创建测试文件

在相应的模块目录下创建测试文件，例如：

```cangjie
// tests/mail_test/internet/new_feature_test.cj
package mail_test.internet

import mail.internet.*
import mail_test.test_helpers.*

public func testNewFeature(): Unit {
    // 测试代码
    let result = someFunction()
    assertEqual(result, expected, "功能测试")
}

public func runAllTests(): Unit {
    let runner = TestRunner()
    runner.runTest("新功能测试", testNewFeature)
    runner.printReport()

    if (!runner.allPassed()) {
        throw Exception("测试失败")
    }
}

main(): Int64 {
    try {
        runAllTests()
        return 0
    } catch (e: Exception) {
        return 1
    }
}
```

### 2. 添加到测试套件

在 `run_all_tests.cj` 中添加新测试模块：

```cangjie
let testModules = [
    // ... 现有测试 ...
    ("Internet - NewFeature", internet.new_feature_test.runAllTests),
]
```

## 参考资料

- [Eclipse Angus Mail 测试源码](https://github.com/eclipse-ee4j/angus-mail/tree/master/providers/angus-mail/src/test/java)
- [Jakarta Mail 规范](https://jakarta.ee/specifications/mail/)
- [RFC 822 - Standard for ARPA Internet Text Messages](https://www.rfc-editor.org/rfc/rfc822)
- [RFC 2045 - MIME Part One](https://www.rfc-editor.org/rfc/rfc2045)
- [RFC 2047 - MIME Part Three: Message Header Extensions](https://www.rfc-editor.org/rfc/rfc2047)

## 贡献指南

欢迎贡献更多测试用例！请确保：

1. 遵循现有的测试结构和命名约定
2. 每个测试函数测试一个明确的功能点
3. 添加清晰的注释说明测试目的
4. 包含正常情况和边界情况
5. 使用有意义的断言消息
6. 参照 angus-mail 的相应测试用例

## 许可证

MIT License
