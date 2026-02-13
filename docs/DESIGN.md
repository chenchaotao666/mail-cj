# 仓颉邮件库 (Cangjie Mail) 实现方案

## 1. 项目概述

### 1.1 目标
基于仓颉语言开发一个对标 Eclipse Angus Mail 的邮件发送库，当前阶段仅实现 SMTP 协议的邮件发送能力。

### 1.2 设计原则
- **接口兼容**：尽量保持与 angus-mail 一致的 API 设计，便于 Java 项目迁移
- **仓颉特性**：充分利用仓颉语言特性（如接口、枚举、Option 类型等）
- **简洁实用**：首期只实现核心发送功能，不过度设计

### 1.3 项目名称
`cangjie-mail` (包名: `mail`)

---

## 2. 项目结构

```
cangjie-mail/
├── cjpm.toml                    # 项目配置文件
├── README.md                    # 项目说明
├── docs/
│   └── DESIGN.md               # 本设计文档
├── src/
│   └── mail/
│       ├── core/                # 核心模块
│       │   ├── session.cj       # Session 会话管理
│       │   ├── transport.cj     # Transport 抽象接口
│       │   ├── message.cj       # Message 消息基类
│       │   ├── address.cj       # Address 地址类
│       │   ├── authenticator.cj # Authenticator 认证接口
│       │   ├── provider.cj      # Provider 提供者接口
│       │   └── exceptions.cj    # 核心异常定义
│       │
│       ├── activation/          # 数据激活框架（对标 Jakarta Activation）
│       │   ├── data_source.cj       # DataSource 接口
│       │   ├── data_handler.cj      # DataHandler 数据处理器
│       │   ├── file_data_source.cj  # 文件数据源
│       │   └── byte_array_data_source.cj  # 字节数组数据源
│       │
│       ├── internet/            # Internet 邮件规范实现
│       │   ├── mime_message.cj      # MimeMessage 实现
│       │   ├── internet_address.cj  # InternetAddress 实现
│       │   ├── mime_multipart.cj    # 多部分消息
│       │   ├── mime_body_part.cj    # 消息体部分
│       │   ├── content_type.cj      # Content-Type 解析
│       │   ├── content_disposition.cj # Content-Disposition 解析
│       │   ├── mime_utility.cj      # MIME 编码工具
│       │   ├── internet_headers.cj  # Internet 邮件头
│       │   └── header_tokenizer.cj  # 邮件头解析器
│       │
│       ├── smtp/                # SMTP 协议实现
│       │   ├── smtp_transport.cj    # SMTP Transport 实现
│       │   ├── smtp_message.cj      # SMTP 扩展消息
│       │   ├── smtp_provider.cj     # SMTP Provider
│       │   ├── smtp_authenticator.cj # SMTP 认证实现
│       │   └── smtp_exceptions.cj   # SMTP 异常
│       │
│       ├── tls/                 # TLS 支持（基于 openHiTLS）
│       │   ├── tls_config.cj        # TLS 配置
│       │   ├── tls_socket.cj        # TLS Socket 封装
│       │   ├── tls_smtp_transport.cj # TLS SMTP 传输
│       │   └── hitls_ffi.cj         # openHiTLS FFI 绑定
│       │
│       └── util/                # 工具模块
│           ├── base64_util.cj       # Base64 编解码
│           ├── quoted_printable.cj  # Quoted-Printable 编码
│           ├── line_output_stream.cj    # 行输出流
│           ├── smtp_output_stream.cj    # SMTP 输出流
│           └── parameter_list.cj    # MIME 参数列表解析
│
└── demo/                        # 演示程序
    ├── .env.example            # 配置模板
    ├── .gitignore              # Git 忽略文件
    ├── cjpm.toml.example       # 构建配置模板
    ├── build.sh                # 自动构建脚本
    ├── README.md               # Demo 使用说明
    ├── src/
    │   ├── main.cj            # 主入口
    │   ├── config.cj          # 配置加载器
    │   ├── handler.cj         # 企业级邮件处理器（仿 Angus-Mail）
    │   ├── demo_basic.cj      # 基础邮件发送演示
    │   ├── demo_angus.cj      # Angus-Mail 风格 Handler 演示
    │   └── demo_utils.cj      # 工具函数和高级演示
    └── assets/                 # 测试资源
        ├── test.txt           # 测试附件
        └── cangjie.png        # 测试图片
```

---

## 3. 核心接口设计

### 3.1 Address 地址抽象

```cangjie
// core/address.cj

/**
 * 邮件地址抽象基类
 * 对标: jakarta.mail.Address
 */
public abstract class Address {
    /**
     * 获取地址类型
     */
    public func getType(): String

    /**
     * 地址字符串表示
     */
    public func toString(): String

    /**
     * 判断地址是否相等
     */
    public func equals(other: Address): Bool
}
```

### 3.2 InternetAddress 实现

```cangjie
// internet/internet_address.cj

/**
 * RFC 822 地址实现
 * 对标: jakarta.mail.internet.InternetAddress
 */
public class InternetAddress <: Address {
    private var address: String          // 邮件地址 (user@domain)
    private var personal: ?String        // 个人名称
    private var charset: String          // 字符编码

    /**
     * 构造函数
     */
    public init(address: String)
    public init(address: String, personal: String)
    public init(address: String, personal: String, charset: String)

    /**
     * 解析地址列表
     * @param addressList 逗号分隔的地址字符串
     * @param strict 是否严格模式
     */
    public static func parse(addressList: String, strict!: Bool = true): Array<InternetAddress>

    /**
     * 获取邮件地址
     */
    public func getAddress(): String

    /**
     * 设置邮件地址
     */
    public func setAddress(address: String): Unit

    /**
     * 获取个人名称
     */
    public func getPersonal(): ?String

    /**
     * 设置个人名称
     */
    public func setPersonal(name: String): Unit
    public func setPersonal(name: String, charset: String): Unit

    /**
     * 验证地址格式
     * @throws AddressException 地址格式无效
     */
    public func validate(): Unit

    /**
     * 获取 RFC 822 格式字符串
     * 格式: "Personal Name" <user@domain>
     */
    public override func toString(): String

    /**
     * 仅获取 Unicode 字符串（不编码）
     */
    public func toUnicodeString(): String
}
```

### 3.3 Message 消息基类

```cangjie
// core/message.cj

/**
 * 收件人类型枚举
 * 对标: jakarta.mail.Message.RecipientType
 */
public enum RecipientType {
    | TO      // 主要收件人
    | CC      // 抄送
    | BCC     // 密送
}

/**
 * 邮件消息抽象基类
 * 对标: jakarta.mail.Message
 */
public abstract class Message {
    protected var session: Session

    /**
     * 获取发件人
     */
    public func getFrom(): Array<Address>

    /**
     * 设置发件人
     */
    public func setFrom(address: Address): Unit
    public func setFrom(): Unit  // 使用默认发件人

    /**
     * 获取收件人
     */
    public func getRecipients(recipientType: RecipientType): Array<Address>

    /**
     * 设置收件人
     */
    public func setRecipients(recipientType: RecipientType, addresses: Array<Address>): Unit

    /**
     * 添加收件人
     */
    public func addRecipients(recipientType: RecipientType, addresses: Array<Address>): Unit

    /**
     * 获取所有收件人
     */
    public func getAllRecipients(): Array<Address>

    /**
     * 获取/设置主题
     */
    public func getSubject(): ?String
    public func setSubject(subject: String): Unit
    public func setSubject(subject: String, charset: String): Unit

    /**
     * 获取/设置发送日期
     */
    public func getSentDate(): ?DateTime
    public func setSentDate(date: DateTime): Unit

    /**
     * 获取/设置回复地址
     */
    public func getReplyTo(): Array<Address>
    public func setReplyTo(addresses: Array<Address>): Unit

    /**
     * 设置文本内容
     */
    public func setText(text: String): Unit
    public func setText(text: String, charset: String): Unit

    /**
     * 设置内容
     */
    public func setContent(content: Object, mimeType: String): Unit
    public func setContent(multipart: Multipart): Unit

    /**
     * 保存更改
     */
    public func saveChanges(): Unit

    /**
     * 写入输出流
     */
    public func writeTo(output: OutputStream): Unit
}
```

### 3.4 MimeMessage 实现

```cangjie
// internet/mime_message.cj

/**
 * MIME 消息实现
 * 对标: jakarta.mail.internet.MimeMessage
 */
public class MimeMessage <: Message {
    protected var headers: HashMap<String, Array<String>>
    protected var content: ?Object
    protected var contentType: ?ContentType

    /**
     * 构造函数
     */
    public init(session: Session)
    public init(session: Session, input: InputStream)

    /**
     * 复制构造
     */
    public init(source: MimeMessage)

    /**
     * 获取/设置邮件头
     */
    public func getHeader(name: String): ?Array<String>
    public func getHeader(name: String, delimiter: String): ?String
    public func setHeader(name: String, value: String): Unit
    public func addHeader(name: String, value: String): Unit
    public func removeHeader(name: String): Unit

    /**
     * 获取所有邮件头
     */
    public func getAllHeaders(): Iterator<(String, String)>

    /**
     * 获取/设置 Message-ID
     */
    public func getMessageID(): ?String
    public func setMessageID(messageId: String): Unit

    /**
     * 获取/设置 Content-Type
     */
    public func getContentType(): String
    public func setContentType(contentType: String): Unit

    /**
     * 获取/设置 Content-Transfer-Encoding
     */
    public func getEncoding(): ?String

    /**
     * 获取内容
     */
    public func getContent(): Object

    /**
     * 获取原始输入流
     */
    public func getRawInputStream(): InputStream

    /**
     * 获取输入流
     */
    public func getInputStream(): InputStream

    /**
     * 获取大小
     */
    public func getSize(): Int64

    /**
     * 写入输出流
     */
    public override func writeTo(output: OutputStream): Unit
    public func writeTo(output: OutputStream, ignoreHeaders: Array<String>): Unit
}
```

### 3.5 Session 会话管理

```cangjie
// core/session.cj

/**
 * 邮件会话
 * 对标: jakarta.mail.Session
 */
public class Session {
    private var properties: HashMap<String, String>
    private var authenticator: ?Authenticator
    private var debug: Bool
    private var providers: HashMap<String, Provider>

    /**
     * 私有构造函数
     */
    private init(properties: HashMap<String, String>, authenticator: ?Authenticator)

    /**
     * 获取会话实例
     */
    public static func getInstance(properties: HashMap<String, String>): Session
    public static func getInstance(
        properties: HashMap<String, String>,
        authenticator: Authenticator
    ): Session

    /**
     * 获取默认会话实例（单例）
     */
    public static func getDefaultInstance(properties: HashMap<String, String>): Session
    public static func getDefaultInstance(
        properties: HashMap<String, String>,
        authenticator: Authenticator
    ): Session

    /**
     * 获取属性
     */
    public func getProperties(): HashMap<String, String>
    public func getProperty(name: String): ?String
    public func getProperty(name: String, defaultValue: String): String

    /**
     * 设置属性
     */
    public func setProperty(name: String, value: String): Unit

    /**
     * 获取 Transport
     */
    public func getTransport(): Transport
    public func getTransport(protocol: String): Transport

    /**
     * 获取 Authenticator
     */
    public func getAuthenticator(): ?Authenticator

    /**
     * 调试模式
     */
    public func getDebug(): Bool
    public func setDebug(debug: Bool): Unit

    /**
     * 注册 Provider
     */
    public func addProvider(provider: Provider): Unit
}
```

### 3.6 Transport 传输抽象

```cangjie
// core/transport.cj

/**
 * 邮件传输抽象类
 * 对标: jakarta.mail.Transport
 */
public abstract class Transport {
    protected var session: Session
    protected var urlName: ?URLName
    protected var connected: Bool

    /**
     * 构造函数
     */
    protected init(session: Session, urlName: ?URLName)

    /**
     * 连接服务器
     */
    public func connect(): Unit
    public func connect(host: String, user: String, password: String): Unit
    public func connect(host: String, port: Int, user: String, password: String): Unit

    /**
     * 协议连接（子类实现）
     */
    protected func protocolConnect(
        host: String,
        port: Int,
        user: String,
        password: String
    ): Bool

    /**
     * 发送消息
     */
    public func sendMessage(message: Message, addresses: Array<Address>): Unit

    /**
     * 静态发送方法
     */
    public static func send(message: Message): Unit
    public static func send(message: Message, addresses: Array<Address>): Unit
    public static func send(
        message: Message,
        user: String,
        password: String
    ): Unit

    /**
     * 关闭连接
     */
    public func close(): Unit

    /**
     * 检查连接状态
     */
    public func isConnected(): Bool
}
```

### 3.7 Authenticator 认证接口

```cangjie
// core/authenticator.cj

/**
 * 密码认证信息
 * 对标: jakarta.mail.PasswordAuthentication
 */
public class PasswordAuthentication {
    private let userName: String
    private let password: String

    public init(userName: String, password: String)

    public func getUserName(): String
    public func getPassword(): String
}

/**
 * 认证器抽象类
 * 对标: jakarta.mail.Authenticator
 */
public abstract class Authenticator {
    /**
     * 获取密码认证信息
     * 子类实现此方法提供认证凭据
     */
    protected func getPasswordAuthentication(): ?PasswordAuthentication
}
```

### 3.8 Provider 接口

```cangjie
// core/provider.cj

/**
 * 提供者类型
 */
public enum ProviderType {
    | STORE      // 邮件存储（接收）
    | TRANSPORT  // 邮件传输（发送）
}

/**
 * 协议提供者
 * 对标: jakarta.mail.Provider
 */
public class Provider {
    private let providerType: ProviderType
    private let protocol: String
    private let className: String
    private let vendor: String
    private let version: ?String

    public init(
        providerType: ProviderType,
        protocol: String,
        className: String,
        vendor: String,
        version: ?String
    )

    public func getType(): ProviderType
    public func getProtocol(): String
    public func getClassName(): String
    public func getVendor(): String
    public func getVersion(): ?String
}
```

### 3.9 核心异常体系

```cangjie
// core/exceptions.cj

/**
 * 邮件异常基类
 * 对标: jakarta.mail.MessagingException
 */
public open class MessagingException <: Exception {
    private var nextException: ?Exception

    public init()
    public init(message: String)
    public init(message: String, cause: Exception)

    /**
     * 获取链式异常
     */
    public func getNextException(): ?Exception

    /**
     * 设置链式异常
     */
    public func setNextException(ex: Exception): Bool
}

/**
 * 地址格式异常
 * 对标: jakarta.mail.internet.AddressException
 */
public class AddressException <: MessagingException {
    private let ref: ?String    // 引用的地址字符串
    private let pos: Int        // 错误位置

    public init()
    public init(message: String)
    public init(message: String, ref: String)
    public init(message: String, ref: String, pos: Int)

    /**
     * 获取引用的地址字符串
     */
    public func getRef(): ?String

    /**
     * 获取错误位置
     */
    public func getPos(): Int
}

/**
 * 认证失败异常
 * 对标: jakarta.mail.AuthenticationFailedException
 */
public class AuthenticationFailedException <: MessagingException {
    public init()
    public init(message: String)
    public init(message: String, cause: Exception)
}

/**
 * 邮件连接异常
 * 对标: org.eclipse.angus.mail.util.MailConnectException
 */
public class MailConnectException <: MessagingException {
    private let host: String
    private let port: Int
    private let connectionTimeout: Int

    public init(host: String, port: Int, connectionTimeout: Int, cause: Exception)

    public func getHost(): String
    public func getPort(): Int
    public func getConnectionTimeout(): Int
}

/**
 * 发送失败异常
 * 对标: jakarta.mail.SendFailedException
 */
public open class SendFailedException <: MessagingException {
    protected var validSentAddresses: Array<Address>
    protected var validUnsentAddresses: Array<Address>
    protected var invalidAddresses: Array<Address>

    public init()
    public init(message: String)
    public init(message: String, cause: Exception)
    public init(
        message: String,
        cause: ?Exception,
        validSent: Array<Address>,
        validUnsent: Array<Address>,
        invalid: Array<Address>
    )

    /**
     * 获取成功发送的地址
     */
    public func getValidSentAddresses(): Array<Address>

    /**
     * 获取未发送的有效地址
     */
    public func getValidUnsentAddresses(): Array<Address>

    /**
     * 获取无效地址
     */
    public func getInvalidAddresses(): Array<Address>
}

/**
 * 解析异常
 * 对标: jakarta.mail.internet.ParseException
 */
public class ParseException <: MessagingException {
    public init()
    public init(message: String)
}
```

---

## 4. 数据激活框架（Activation）

> 对标 Jakarta Activation Framework，用于统一处理各种数据类型（附件、嵌入资源等）

### 4.1 DataSource 接口

```cangjie
// activation/data_source.cj

/**
 * 数据源接口
 * 对标: jakarta.activation.DataSource
 *
 * 提供对数据的类型化访问，隐藏底层存储细节
 */
public interface DataSource {
    /**
     * 获取输入流
     * 每次调用返回新的输入流
     */
    func getInputStream(): InputStream

    /**
     * 获取输出流
     * 每次调用返回新的输出流
     */
    func getOutputStream(): OutputStream

    /**
     * 获取 MIME 类型
     * 如: "text/plain", "image/png", "application/pdf"
     */
    func getContentType(): String

    /**
     * 获取名称（可选，通常是文件名）
     */
    func getName(): String
}
```

### 4.2 FileDataSource 实现

```cangjie
// activation/file_data_source.cj

/**
 * 文件数据源
 * 对标: jakarta.activation.FileDataSource
 */
public class FileDataSource <: DataSource {
    private let file: File

    /**
     * 从文件路径构造
     */
    public init(filePath: String)

    /**
     * 从 File 对象构造
     */
    public init(file: File)

    public override func getInputStream(): InputStream

    public override func getOutputStream(): OutputStream

    /**
     * 根据文件扩展名推断 MIME 类型
     */
    public override func getContentType(): String

    /**
     * 返回文件名
     */
    public override func getName(): String

    /**
     * 获取底层 File 对象
     */
    public func getFile(): File
}
```

### 4.3 ByteArrayDataSource 实现

```cangjie
// activation/byte_array_data_source.cj

/**
 * 字节数组数据源
 * 对标: jakarta.mail.util.ByteArrayDataSource
 *
 * 用于从内存中的字节数据创建数据源，常用于：
 * - 动态生成的附件
 * - 从数据库读取的二进制数据
 * - 网络下载的内容
 */
public class ByteArrayDataSource <: DataSource {
    private let data: Array<Byte>
    private let contentType: String
    private var name: String

    /**
     * 从字节数组构造
     */
    public init(data: Array<Byte>, contentType: String)

    /**
     * 从字符串构造（使用 UTF-8 编码）
     */
    public init(data: String, contentType: String)

    /**
     * 从输入流构造
     */
    public init(input: InputStream, contentType: String)

    public override func getInputStream(): InputStream

    /**
     * 不支持输出，抛出异常
     */
    public override func getOutputStream(): OutputStream

    public override func getContentType(): String

    public override func getName(): String

    /**
     * 设置名称
     */
    public func setName(name: String): Unit
}
```

### 4.4 DataHandler 数据处理器

```cangjie
// activation/data_handler.cj

/**
 * 数据处理器
 * 对标: jakarta.activation.DataHandler
 *
 * 统一处理各种类型的数据，是附件处理的核心类。
 * 它封装了数据源，并提供统一的访问接口。
 */
public class DataHandler {
    private var dataSource: ?DataSource
    private var object: ?Object
    private var objectMimeType: ?String

    /**
     * 从 DataSource 构造
     */
    public init(dataSource: DataSource)

    /**
     * 从对象和 MIME 类型构造
     */
    public init(object: Object, mimeType: String)

    /**
     * 获取 MIME 类型
     */
    public func getContentType(): String

    /**
     * 获取输入流
     */
    public func getInputStream(): InputStream

    /**
     * 获取数据源
     */
    public func getDataSource(): DataSource

    /**
     * 获取内容对象
     * 根据 MIME 类型返回相应的对象：
     * - text/plain → String
     * - text/html → String
     * - multipart/* → MimeMultipart
     * - 其他 → InputStream
     */
    public func getContent(): Object

    /**
     * 获取名称
     */
    public func getName(): String

    /**
     * 写入输出流
     */
    public func writeTo(output: OutputStream): Unit

    /**
     * 设置命令映射（简化实现，可选）
     */
    public func setCommandMap(commandMap: CommandMap): Unit
}

/**
 * 命令映射（简化实现）
 * 对标: jakarta.activation.CommandMap
 */
public class CommandMap {
    /**
     * 获取默认命令映射
     */
    public static func getDefaultCommandMap(): CommandMap

    /**
     * 根据 MIME 类型创建数据内容处理器
     */
    public func createDataContentHandler(mimeType: String): ?DataContentHandler
}

/**
 * 数据内容处理器接口
 * 对标: jakarta.activation.DataContentHandler
 */
public interface DataContentHandler {
    /**
     * 获取传输编码
     */
    func getTransferDataFlavors(): Array<String>

    /**
     * 获取内容
     */
    func getContent(dataSource: DataSource): Object

    /**
     * 写入对象
     */
    func writeTo(object: Object, mimeType: String, output: OutputStream): Unit
}
```

---

## 5. MIME 工具类

### 5.1 MimeUtility 编码工具

```cangjie
// internet/mime_utility.cj

/**
 * MIME 编码工具类
 * 对标: jakarta.mail.internet.MimeUtility
 *
 * 处理 MIME 消息中的编码问题，包括：
 * - 邮件头的编码/解码（RFC 2047）
 * - 内容传输编码
 * - 字符集处理
 */
public class MimeUtility {

    // ==================== 邮件头编码（RFC 2047）====================

    /**
     * 编码文本（用于邮件头）
     * 将非 ASCII 文本编码为 RFC 2047 格式
     *
     * @param text 原始文本
     * @param charset 字符集（如 "UTF-8"）
     * @param encoding 编码方式 "B"(Base64) 或 "Q"(Quoted-Printable)
     * @return 编码后的字符串，格式: =?charset?encoding?encoded_text?=
     *
     * 示例:
     *   encodeText("你好", "UTF-8", "B") → "=?UTF-8?B?5L2g5aW9?="
     */
    public static func encodeText(text: String, charset: String, encoding: String): String

    /**
     * 编码文本（自动选择编码方式）
     */
    public static func encodeText(text: String, charset: String): String

    /**
     * 编码文本（使用默认字符集）
     */
    public static func encodeText(text: String): String

    /**
     * 解码文本
     * 将 RFC 2047 编码的字符串解码为原始文本
     *
     * @param encodedText 编码后的文本
     * @return 解码后的原始文本
     */
    public static func decodeText(encodedText: String): String

    /**
     * 编码单词（用于邮件头中的单个词）
     * 类似 encodeText，但适用于结构化头域（如 From, To）
     */
    public static func encodeWord(word: String, charset: String, encoding: String): String
    public static func encodeWord(word: String, charset: String): String
    public static func encodeWord(word: String): String

    /**
     * 解码单词
     */
    public static func decodeWord(encodedWord: String): String

    // ==================== 内容传输编码 ====================

    /**
     * 获取编码输出流
     * 根据编码类型包装输出流
     *
     * @param output 原始输出流
     * @param encoding 编码类型: "base64", "quoted-printable", "7bit", "8bit", "binary"
     * @return 编码输出流
     */
    public static func encode(output: OutputStream, encoding: String): OutputStream

    /**
     * 获取解码输入流
     * 根据编码类型包装输入流
     *
     * @param input 原始输入流
     * @param encoding 编码类型
     * @return 解码输入流
     */
    public static func decode(input: InputStream, encoding: String): InputStream

    // ==================== 字符集处理 ====================

    /**
     * 获取默认 MIME 字符集
     */
    public static func getDefaultMIMECharset(): String

    /**
     * 获取默认 Java 字符集
     */
    public static func getDefaultJavaCharset(): String

    /**
     * MIME 字符集转 Java 字符集
     */
    public static func mimeCharset(charset: String): String

    /**
     * Java 字符集转 MIME 字符集
     */
    public static func javaCharset(charset: String): String

    // ==================== 引用处理 ====================

    /**
     * 引用字符串（用于参数值）
     * 如果包含特殊字符，添加双引号
     */
    public static func quote(text: String, specials: String): String

    /**
     * 折叠邮件头
     * 将长邮件头按 RFC 2822 规则折叠（每行不超过78字符）
     *
     * @param used 当前行已使用的字符数
     * @param text 要折叠的文本
     * @return 折叠后的文本
     */
    public static func fold(used: Int, text: String): String

    /**
     * 展开邮件头
     * 将折叠的邮件头还原
     */
    public static func unfold(text: String): String
}
```

### 5.2 ContentType 解析

```cangjie
// internet/content_type.cj

/**
 * Content-Type 头解析器
 * 对标: jakarta.mail.internet.ContentType
 *
 * 解析和构建 Content-Type 头，格式:
 *   type/subtype; param1=value1; param2=value2
 *
 * 示例:
 *   text/plain; charset=UTF-8
 *   multipart/mixed; boundary="----=_Part_0_123456789"
 *   application/pdf; name="document.pdf"
 */
public class ContentType {
    private var primaryType: String      // 主类型 (text, image, application, etc.)
    private var subType: String          // 子类型 (plain, html, png, pdf, etc.)
    private var parameterList: ParameterList  // 参数列表

    /**
     * 默认构造
     */
    public init()

    /**
     * 从类型和子类型构造
     */
    public init(primaryType: String, subType: String, parameterList: ?ParameterList)

    /**
     * 从字符串解析
     * @throws ParseException 解析失败
     */
    public init(contentType: String)

    /**
     * 获取主类型
     */
    public func getPrimaryType(): String

    /**
     * 设置主类型
     */
    public func setPrimaryType(primaryType: String): Unit

    /**
     * 获取子类型
     */
    public func getSubType(): String

    /**
     * 设置子类型
     */
    public func setSubType(subType: String): Unit

    /**
     * 获取基础类型（type/subtype，不含参数）
     */
    public func getBaseType(): String

    /**
     * 获取参数值
     */
    public func getParameter(name: String): ?String

    /**
     * 设置参数
     */
    public func setParameter(name: String, value: String): Unit

    /**
     * 获取参数列表
     */
    public func getParameterList(): ParameterList

    /**
     * 设置参数列表
     */
    public func setParameterList(parameterList: ParameterList): Unit

    /**
     * 转为字符串
     */
    public override func toString(): String

    /**
     * 匹配类型
     * 支持通配符，如 "text/*" 匹配所有 text 类型
     */
    public func match(contentType: ContentType): Bool
    public func match(contentType: String): Bool
}
```

### 5.3 ContentDisposition 解析

```cangjie
// internet/content_disposition.cj

/**
 * Content-Disposition 头解析器
 * 对标: jakarta.mail.internet.ContentDisposition
 *
 * 解析和构建 Content-Disposition 头，格式:
 *   disposition; param1=value1; param2=value2
 *
 * 常见值:
 *   inline - 内联显示
 *   attachment - 作为附件
 *
 * 常见参数:
 *   filename - 文件名
 *   creation-date - 创建日期
 *   modification-date - 修改日期
 *   size - 文件大小
 */
public class ContentDisposition {
    private var disposition: String      // inline 或 attachment
    private var parameterList: ParameterList

    /**
     * 默认构造
     */
    public init()

    /**
     * 从字符串解析
     */
    public init(disposition: String)

    /**
     * 获取 disposition 类型
     */
    public func getDisposition(): String

    /**
     * 设置 disposition 类型
     */
    public func setDisposition(disposition: String): Unit

    /**
     * 获取参数
     */
    public func getParameter(name: String): ?String

    /**
     * 设置参数
     */
    public func setParameter(name: String, value: String): Unit

    /**
     * 获取参数列表
     */
    public func getParameterList(): ParameterList

    /**
     * 设置参数列表
     */
    public func setParameterList(parameterList: ParameterList): Unit

    /**
     * 转为字符串
     */
    public override func toString(): String
}
```

### 5.4 ParameterList 参数列表

```cangjie
// util/parameter_list.cj

/**
 * MIME 参数列表
 * 对标: jakarta.mail.internet.ParameterList
 *
 * 用于解析和构建 MIME 头中的参数部分
 * 格式: ; name1=value1; name2="value with spaces"
 *
 * 支持:
 * - RFC 2231 参数编码（支持非 ASCII 字符）
 * - RFC 2231 参数续行（超长参数值）
 */
public class ParameterList {
    private var parameters: HashMap<String, String>

    /**
     * 默认构造
     */
    public init()

    /**
     * 从字符串解析
     */
    public init(parameterList: String)

    /**
     * 获取参数数量
     */
    public func size(): Int

    /**
     * 获取参数值
     */
    public func get(name: String): ?String

    /**
     * 设置参数
     */
    public func set(name: String, value: String): Unit

    /**
     * 设置参数（带字符集）
     */
    public func set(name: String, value: String, charset: String): Unit

    /**
     * 移除参数
     */
    public func remove(name: String): Unit

    /**
     * 获取所有参数名
     */
    public func getNames(): Iterator<String>

    /**
     * 转为字符串
     */
    public override func toString(): String

    /**
     * 转为字符串（指定已使用的字符数，用于折行）
     */
    public func toString(used: Int): String
}
```

### 5.5 HeaderTokenizer 邮件头解析器

```cangjie
// internet/header_tokenizer.cj

/**
 * 邮件头标记化器
 * 对标: jakarta.mail.internet.HeaderTokenizer
 *
 * 用于解析结构化邮件头（如 Content-Type, Content-Disposition）
 */
public class HeaderTokenizer {
    /**
     * 标记类型
     */
    public enum TokenType {
        | ATOM           // 原子（不带引号的字符串）
        | QUOTEDSTRING   // 带引号的字符串
        | COMMENT        // 注释
        | EOF            // 结束
        | Special(Char)  // 特殊字符
    }

    /**
     * 标记
     */
    public class Token {
        public let tokenType: TokenType
        public let value: String

        public init(tokenType: TokenType, value: String)
    }

    // RFC 822 特殊字符
    public static let RFC822 = "()<>@,;:\\\"\t .[]"

    // MIME 特殊字符
    public static let MIME = "()<>@,;:\\\"\t []/?="

    /**
     * 构造函数
     */
    public init(header: String, delimiters: String, skipComments: Bool)
    public init(header: String, delimiters: String)

    /**
     * 获取下一个标记
     */
    public func next(): Token

    /**
     * 获取下一个标记（遇到指定字符停止）
     */
    public func next(endOfAtom: Char): Token

    /**
     * 获取下一个标记（遇到指定字符停止，可指定是否保留转义）
     */
    public func next(endOfAtom: Char, keepEscapes: Bool): Token

    /**
     * 查看下一个标记（不消费）
     */
    public func peek(): Token

    /**
     * 获取剩余字符串
     */
    public func getRemainder(): String
}
```

---

## 6. MIME 多部分消息

### 6.1 Multipart 抽象类

```cangjie
// internet/multipart.cj

/**
 * 多部分消息抽象类
 * 对标: jakarta.mail.Multipart
 */
public abstract class Multipart {
    protected var parts: ArrayList<BodyPart>
    protected var contentType: String
    protected var parent: ?Part

    public init()

    /**
     * 添加消息体部分
     */
    public func addBodyPart(part: BodyPart): Unit

    /**
     * 在指定位置添加消息体部分
     */
    public func addBodyPart(part: BodyPart, index: Int): Unit

    /**
     * 移除消息体部分
     */
    public func removeBodyPart(part: BodyPart): Bool

    /**
     * 移除指定位置的消息体部分
     */
    public func removeBodyPart(index: Int): BodyPart

    /**
     * 获取消息体部分数量
     */
    public func getCount(): Int

    /**
     * 获取指定位置的消息体部分
     */
    public func getBodyPart(index: Int): BodyPart

    /**
     * 获取 Content-Type
     */
    public func getContentType(): String

    /**
     * 获取父 Part
     */
    public func getParent(): ?Part

    /**
     * 设置父 Part
     */
    public func setParent(parent: Part): Unit

    /**
     * 写入输出流
     */
    public abstract func writeTo(output: OutputStream): Unit
}
```

### 6.2 MimeMultipart 实现

```cangjie
// internet/mime_multipart.cj

/**
 * MIME 多部分消息实现
 * 对标: jakarta.mail.internet.MimeMultipart
 *
 * 常见子类型:
 * - mixed: 混合类型（正文 + 附件）
 * - alternative: 替代类型（同一内容的不同格式，如纯文本和HTML）
 * - related: 关联类型（HTML + 内嵌图片）
 * - digest: 摘要类型
 */
public class MimeMultipart <: Multipart {
    private var subType: String = "mixed"
    private var boundary: String
    private var preamble: ?String
    private var parsed: Bool = true

    /**
     * 默认构造（mixed 类型）
     */
    public init()

    /**
     * 指定子类型构造
     */
    public init(subType: String)

    /**
     * 从 DataSource 构造（解析现有内容）
     */
    public init(dataSource: DataSource)

    /**
     * 获取子类型
     */
    public func getSubType(): String

    /**
     * 设置子类型
     */
    public func setSubType(subType: String): Unit

    /**
     * 获取前导文本
     */
    public func getPreamble(): ?String

    /**
     * 设置前导文本
     */
    public func setPreamble(preamble: String): Unit

    /**
     * 获取边界字符串
     */
    protected func getBoundary(): String

    /**
     * 创建新的边界字符串
     */
    protected static func generateBoundary(): String

    /**
     * 写入输出流
     */
    public override func writeTo(output: OutputStream): Unit

    /**
     * 检查内容类型是否匹配
     */
    public func isComplete(): Bool
}
```

### 6.3 MimeBodyPart 实现

```cangjie
// internet/mime_body_part.cj

/**
 * MIME 消息体部分
 * 对标: jakarta.mail.internet.MimeBodyPart
 *
 * 用于表示多部分消息中的单个部分，可以是：
 * - 文本内容
 * - HTML 内容
 * - 附件文件
 * - 内嵌图片
 */
public class MimeBodyPart <: BodyPart {
    protected var headers: InternetHeaders
    protected var content: ?Array<Byte>
    protected var dataHandler: ?DataHandler
    protected var contentDisposition: ?ContentDisposition

    /**
     * 默认构造
     */
    public init()

    /**
     * 从输入流构造
     */
    public init(input: InputStream)

    /**
     * 从 InternetHeaders 和字节数组构造
     */
    public init(headers: InternetHeaders, content: Array<Byte>)

    // ==================== 内容操作 ====================

    /**
     * 获取内容大小
     */
    public func getSize(): Int

    /**
     * 获取行数
     */
    public func getLineCount(): Int

    /**
     * 获取 Content-Type
     */
    public func getContentType(): String

    /**
     * 判断是否为指定 MIME 类型
     */
    public func isMimeType(mimeType: String): Bool

    /**
     * 获取 Content-Disposition
     */
    public func getDisposition(): ?String

    /**
     * 设置 Content-Disposition
     */
    public func setDisposition(disposition: String): Unit

    /**
     * 获取 Content-Transfer-Encoding
     */
    public func getEncoding(): ?String

    /**
     * 获取 Content-ID
     */
    public func getContentID(): ?String

    /**
     * 设置 Content-ID（用于内嵌资源）
     */
    public func setContentID(cid: String): Unit

    /**
     * 获取 Content-MD5
     */
    public func getContentMD5(): ?String

    /**
     * 设置 Content-MD5
     */
    public func setContentMD5(md5: String): Unit

    /**
     * 获取内容语言
     */
    public func getContentLanguage(): ?Array<String>

    /**
     * 设置内容语言
     */
    public func setContentLanguage(languages: Array<String>): Unit

    /**
     * 获取描述
     */
    public func getDescription(): ?String

    /**
     * 设置描述
     */
    public func setDescription(description: String): Unit
    public func setDescription(description: String, charset: String): Unit

    /**
     * 获取文件名
     */
    public func getFileName(): ?String

    /**
     * 设置文件名
     */
    public func setFileName(filename: String): Unit

    // ==================== 数据访问 ====================

    /**
     * 获取输入流
     */
    public func getInputStream(): InputStream

    /**
     * 获取原始输入流（未解码）
     */
    public func getRawInputStream(): InputStream

    /**
     * 获取 DataHandler
     */
    public func getDataHandler(): DataHandler

    /**
     * 设置 DataHandler
     */
    public func setDataHandler(dataHandler: DataHandler): Unit

    /**
     * 获取内容对象
     */
    public func getContent(): Object

    /**
     * 设置内容
     */
    public func setContent(content: Object, mimeType: String): Unit
    public func setContent(multipart: Multipart): Unit

    /**
     * 设置文本内容
     */
    public func setText(text: String): Unit
    public func setText(text: String, charset: String): Unit
    public func setText(text: String, charset: String, subtype: String): Unit

    // ==================== 附件操作 ====================

    /**
     * 附加文件
     */
    public func attachFile(file: File): Unit
    public func attachFile(filePath: String): Unit

    /**
     * 保存文件
     */
    public func saveFile(file: File): Unit
    public func saveFile(filePath: String): Unit

    // ==================== 邮件头操作 ====================

    /**
     * 获取邮件头
     */
    public func getHeader(name: String): ?Array<String>

    /**
     * 设置邮件头
     */
    public func setHeader(name: String, value: String): Unit

    /**
     * 添加邮件头
     */
    public func addHeader(name: String, value: String): Unit

    /**
     * 移除邮件头
     */
    public func removeHeader(name: String): Unit

    /**
     * 获取所有邮件头
     */
    public func getAllHeaders(): Iterator<Header>

    // ==================== 序列化 ====================

    /**
     * 写入输出流
     */
    public func writeTo(output: OutputStream): Unit

    /**
     * 获取邮件头行
     */
    public func getAllHeaderLines(): Iterator<String>
}

/**
 * 消息体部分抽象类
 * 对标: jakarta.mail.BodyPart
 */
public abstract class BodyPart {
    protected var parent: ?Multipart

    public func getParent(): ?Multipart
    public func setParent(parent: Multipart): Unit
}
```

---

## 7. SMTP 协议实现

### 7.1 SMTPTransport 实现

```cangjie
// smtp/smtp_transport.cj

/**
 * SMTP 传输实现
 * 对标: org.eclipse.angus.mail.smtp.SMTPTransport
 */
public class SMTPTransport <: Transport {
    // 协议配置
    private var name: String = "smtp"
    private var defaultPort: Int = 25
    private var isSSL: Bool = false

    // 连接状态
    private var host: String = ""
    private var port: Int = 25
    private var socket: ?TcpSocket
    private var reader: ?BufferedReader
    private var writer: ?BufferedWriter

    // ESMTP 扩展
    private var extMap: HashMap<String, String>
    private var serverAuthMechanisms: Array<String>

    // 配置选项
    private var useStartTLS: Bool = false
    private var requireStartTLS: Bool = false
    private var enableSASL: Bool = false
    private var saslRealm: ?String
    private var authorizationId: ?String
    private var localHost: ?String

    // 发送状态
    private var lastServerResponse: String = ""
    private var lastReturnCode: Int = 0

    /**
     * 构造函数
     */
    public init(session: Session, urlName: ?URLName)
    protected init(session: Session, urlName: ?URLName, name: String, isSSL: Bool)

    /**
     * 使用现有 Socket 连接
     */
    public func connect(socket: TcpSocket): Unit

    /**
     * 协议连接实现
     */
    protected override func protocolConnect(
        host: String,
        port: Int,
        user: String,
        password: String
    ): Bool

    /**
     * 发送消息
     */
    public override func sendMessage(message: Message, addresses: Array<Address>): Unit

    /**
     * 关闭连接
     */
    public override func close(): Unit

    // ==================== SMTP 命令 ====================

    /**
     * 发送 HELO 命令
     */
    protected func helo(domain: String): Unit

    /**
     * 发送 EHLO 命令
     * @return 是否成功（服务器支持 ESMTP）
     */
    protected func ehlo(domain: String): Bool

    /**
     * 发送 MAIL FROM 命令
     */
    protected func mailFrom(): Unit

    /**
     * 发送 RCPT TO 命令
     */
    protected func rcptTo(): Unit

    /**
     * 发送 DATA 命令，返回数据输出流
     */
    protected func data(): OutputStream

    /**
     * 完成 DATA 传输
     */
    protected func finishData(): Unit

    /**
     * 发送 RSET 命令
     */
    protected func rset(): Unit

    /**
     * 发送 QUIT 命令
     */
    protected func quit(): Unit

    /**
     * 发送 STARTTLS 命令
     */
    protected func startTLS(): Unit

    // ==================== 认证 ====================

    /**
     * 执行认证
     */
    protected func authenticate(user: String, password: String): Bool

    /**
     * LOGIN 认证
     */
    private func authLogin(user: String, password: String): Bool

    /**
     * PLAIN 认证
     */
    private func authPlain(user: String, password: String): Bool

    // ==================== 扩展查询 ====================

    /**
     * 检查服务器是否支持扩展
     */
    public func supportsExtension(ext: String): Bool

    /**
     * 获取扩展参数
     */
    public func getExtensionParameter(ext: String): ?String

    // ==================== 配置方法 ====================

    public func getStartTLS(): Bool
    public func setStartTLS(useStartTLS: Bool): Unit

    public func getRequireStartTLS(): Bool
    public func setRequireStartTLS(requireStartTLS: Bool): Unit

    public func getSASLEnabled(): Bool
    public func setSASLEnabled(enableSASL: Bool): Unit

    public func getSASLRealm(): ?String
    public func setSASLRealm(realm: String): Unit

    public func getAuthorizationId(): ?String
    public func setAuthorizationId(authzid: String): Unit

    public func getLocalHost(): ?String
    public func setLocalHost(localhost: String): Unit

    /**
     * 获取最后的服务器响应
     */
    public func getLastServerResponse(): String

    /**
     * 获取最后的返回码
     */
    public func getLastReturnCode(): Int

    // ==================== 底层命令 ====================

    /**
     * 发送命令并检查响应
     */
    public func issueCommand(cmd: String, expect: Int): Unit

    /**
     * 发送简单命令
     */
    public func simpleCommand(cmd: String): Int

    /**
     * 发送命令（不等待响应）
     */
    protected func sendCommand(cmd: String): Unit

    /**
     * 读取服务器响应
     */
    protected func readServerResponse(): Int
}
```

### 7.2 SMTPSSLTransport

```cangjie
// smtp/smtp_ssl_transport.cj

/**
 * SMTP over SSL/TLS 传输
 * 对标: org.eclipse.angus.mail.smtp.SMTPSSLTransport
 */
public class SMTPSSLTransport <: SMTPTransport {
    public init(session: Session, urlName: ?URLName) {
        super(session, urlName, "smtps", true)
    }
}
```

### 7.3 SMTPMessage

```cangjie
// smtp/smtp_message.cj

/**
 * DSN 通知选项
 */
public const NOTIFY_NEVER: Int = -1
public const NOTIFY_SUCCESS: Int = 1
public const NOTIFY_FAILURE: Int = 2
public const NOTIFY_DELAY: Int = 4

/**
 * DSN 返回选项
 */
public const RETURN_FULL: Int = 1
public const RETURN_HDRS: Int = 2

/**
 * SMTP 扩展消息
 * 对标: org.eclipse.angus.mail.smtp.SMTPMessage
 */
public class SMTPMessage <: MimeMessage {
    private var envelopeFrom: ?String      // 信封发件人
    private var notifyOptions: Int = 0     // DSN 通知选项
    private var returnOption: Int = 0      // DSN 返回选项
    private var sendPartial: Bool = false  // 部分发送
    private var allow8bitMIME: Bool = false // 8BIT MIME
    private var submitter: ?String         // 提交者
    private var mailExtension: ?String     // MAIL 命令扩展

    public init(session: Session)
    public init(session: Session, input: InputStream)
    public init(source: MimeMessage)

    // 信封发件人
    public func getEnvelopeFrom(): ?String
    public func setEnvelopeFrom(from: String): Unit

    // DSN 通知选项
    public func getNotifyOptions(): Int
    public func setNotifyOptions(options: Int): Unit

    // DSN 返回选项
    public func getReturnOption(): Int
    public func setReturnOption(option: Int): Unit

    // 部分发送
    public func getSendPartial(): Bool
    public func setSendPartial(partial: Bool): Unit

    // 8BIT MIME
    public func getAllow8bitMIME(): Bool
    public func setAllow8bitMIME(allow: Bool): Unit

    // 提交者
    public func getSubmitter(): ?String
    public func setSubmitter(submitter: String): Unit

    // MAIL 扩展
    public func getMailExtension(): ?String
    public func setMailExtension(extension: String): Unit
}
```

### 7.4 SMTP 异常

```cangjie
// smtp/smtp_exceptions.cj

/**
 * SMTP 发送失败异常
 * 对标: org.eclipse.angus.mail.smtp.SMTPSendFailedException
 */
public class SMTPSendFailedException <: SendFailedException {
    private let command: String
    private let returnCode: Int

    public init(
        command: String,
        returnCode: Int,
        message: String,
        validSent: Array<Address>,
        validUnsent: Array<Address>,
        invalid: Array<Address>
    )

    public func getCommand(): String
    public func getReturnCode(): Int
}

/**
 * SMTP 地址失败异常
 * 对标: org.eclipse.angus.mail.smtp.SMTPAddressFailedException
 */
public class SMTPAddressFailedException <: SendFailedException {
    private let address: InternetAddress
    private let command: String
    private let returnCode: Int

    public init(
        address: InternetAddress,
        command: String,
        returnCode: Int,
        message: String
    )

    public func getAddress(): InternetAddress
    public func getCommand(): String
    public func getReturnCode(): Int
}

/**
 * SMTP 发件人失败异常
 * 对标: org.eclipse.angus.mail.smtp.SMTPSenderFailedException
 */
public class SMTPSenderFailedException <: SendFailedException {
    private let address: InternetAddress
    private let command: String
    private let returnCode: Int

    public init(
        address: InternetAddress,
        command: String,
        returnCode: Int,
        message: String
    )

    public func getAddress(): InternetAddress
    public func getCommand(): String
    public func getReturnCode(): Int
}
```

### 7.5 SMTPProvider

```cangjie
// smtp/smtp_provider.cj

/**
 * SMTP Provider
 * 对标: org.eclipse.angus.mail.smtp.SMTPProvider
 */
public class SMTPProvider <: Provider {
    public init() {
        super(
            ProviderType.TRANSPORT,
            "smtp",
            "mail.smtp.SMTPTransport",
            "Cangjie Mail",
            Some("1.0.0")
        )
    }
}

/**
 * SMTPS Provider
 * 对标: org.eclipse.angus.mail.smtp.SMTPSSLProvider
 */
public class SMTPSSLProvider <: Provider {
    public init() {
        super(
            ProviderType.TRANSPORT,
            "smtps",
            "mail.smtp.SMTPSSLTransport",
            "Cangjie Mail",
            Some("1.0.0")
        )
    }
}
```

---

## 8. 其他工具类

### 8.1 SMTPOutputStream

```cangjie
// util/smtp_output_stream.cj

/**
 * SMTP 数据输出流
 * 处理行尾 CRLF 转换和点转义
 * 对标: org.eclipse.angus.mail.smtp.SMTPOutputStream
 */
public class SMTPOutputStream <: OutputStream {
    private var output: OutputStream
    private var lastByte: Int = -1

    public init(output: OutputStream)

    public override func write(b: Byte): Unit
    public override func write(buffer: Array<Byte>, offset: Int, length: Int): Unit
    public override func flush(): Unit
    public override func close(): Unit

    /**
     * 确保以 CRLF 结尾
     */
    public func ensureCRLF(): Unit
}
```

### 8.2 Base64 编解码

```cangjie
// util/base64.cj

/**
 * Base64 编解码工具
 */
public class Base64 {
    /**
     * 编码
     */
    public static func encode(data: Array<Byte>): String
    public static func encodeToBytes(data: Array<Byte>): Array<Byte>

    /**
     * 解码
     */
    public static func decode(data: String): Array<Byte>
    public static func decodeFromBytes(data: Array<Byte>): Array<Byte>

    /**
     * MIME 编码（带换行）
     */
    public static func mimeEncode(data: Array<Byte>): String
}
```

---

## 9. 配置属性

与 angus-mail 保持一致的配置属性命名：

### 9.1 SMTP 配置

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `mail.smtp.host` | String | - | SMTP 服务器地址 |
| `mail.smtp.port` | Int | 25 | SMTP 服务器端口 |
| `mail.smtp.user` | String | - | 默认用户名 |
| `mail.smtp.from` | String | - | 默认发件人 |
| `mail.smtp.localhost` | String | - | 本地主机名（HELO/EHLO） |
| `mail.smtp.auth` | Bool | false | 是否启用认证 |
| `mail.smtp.auth.mechanisms` | String | - | 认证机制列表（逗号分隔） |
| `mail.smtp.starttls.enable` | Bool | false | 启用 STARTTLS |
| `mail.smtp.starttls.required` | Bool | false | 强制 STARTTLS |
| `mail.smtp.ssl.enable` | Bool | false | 启用 SSL |
| `mail.smtp.connectiontimeout` | Int | -1 | 连接超时（毫秒） |
| `mail.smtp.timeout` | Int | -1 | 读取超时（毫秒） |
| `mail.smtp.writetimeout` | Int | -1 | 写入超时（毫秒） |
| `mail.smtp.sendpartial` | Bool | false | 部分发送模式 |
| `mail.smtp.allow8bitmime` | Bool | false | 允许 8BIT MIME |
| `mail.smtp.quitwait` | Bool | true | QUIT 后等待响应 |
| `mail.debug` | Bool | false | 调试模式 |

---

## 10. 使用示例

### 10.1 简单发送

```cangjie
import mail.core.*
import mail.internet.*
import mail.smtp.*

main() {
    // 1. 配置属性
    let props = HashMap<String, String>()
    props.put("mail.smtp.host", "smtp.example.com")
    props.put("mail.smtp.port", "587")
    props.put("mail.smtp.auth", "true")
    props.put("mail.smtp.starttls.enable", "true")

    // 2. 创建认证器
    let auth = object : Authenticator {
        protected override func getPasswordAuthentication(): ?PasswordAuthentication {
            Some(PasswordAuthentication("user@example.com", "password"))
        }
    }

    // 3. 创建会话
    let session = Session.getInstance(props, auth)
    session.setDebug(true)

    // 4. 创建消息
    let message = MimeMessage(session)
    message.setFrom(InternetAddress("sender@example.com"))
    message.setRecipients(RecipientType.TO, InternetAddress.parse("recipient@example.com"))
    message.setSubject("测试邮件")
    message.setText("你好，这是一封测试邮件。")

    // 5. 发送
    Transport.send(message)

    println("邮件发送成功！")
}
```

### 10.2 带附件发送

```cangjie
import mail.core.*
import mail.internet.*
import mail.activation.*
import mail.smtp.*
import std.fs.*

main() {
    let props = HashMap<String, String>()
    props.put("mail.smtp.host", "smtp.example.com")
    props.put("mail.smtp.port", "587")
    props.put("mail.smtp.auth", "true")

    let session = Session.getInstance(props)

    let message = MimeMessage(session)
    message.setFrom(InternetAddress("sender@example.com"))
    message.setRecipients(RecipientType.TO, InternetAddress.parse("recipient@example.com"))
    message.setSubject("带附件的邮件")

    // 创建多部分消息
    let multipart = MimeMultipart()

    // 文本部分
    let textPart = MimeBodyPart()
    textPart.setText("请查看附件。")
    multipart.addBodyPart(textPart)

    // 附件部分
    let attachPart = MimeBodyPart()
    attachPart.attachFile("./document.pdf")
    multipart.addBodyPart(attachPart)

    message.setContent(multipart)

    // 发送
    let transport = session.getTransport("smtp")
    transport.connect("smtp.example.com", "user", "password")
    transport.sendMessage(message, message.getAllRecipients())
    transport.close()
}
```

### 10.3 使用 DataHandler 处理附件

```cangjie
import mail.core.*
import mail.internet.*
import mail.activation.*

main() {
    let session = Session.getInstance(HashMap<String, String>())
    let message = MimeMessage(session)

    // 创建多部分消息
    let multipart = MimeMultipart()

    // 文本正文
    let textPart = MimeBodyPart()
    textPart.setText("这是邮件正文。")
    multipart.addBodyPart(textPart)

    // 使用 FileDataSource 添加文件附件
    let filePart = MimeBodyPart()
    let fileDataSource = FileDataSource("./report.pdf")
    filePart.setDataHandler(DataHandler(fileDataSource))
    filePart.setFileName("report.pdf")
    multipart.addBodyPart(filePart)

    // 使用 ByteArrayDataSource 添加内存数据作为附件
    let memoryPart = MimeBodyPart()
    let csvData = "Name,Age\nAlice,30\nBob,25"
    let byteDataSource = ByteArrayDataSource(csvData, "text/csv")
    byteDataSource.setName("data.csv")
    memoryPart.setDataHandler(DataHandler(byteDataSource))
    memoryPart.setFileName("data.csv")
    multipart.addBodyPart(memoryPart)

    message.setContent(multipart)
}
```

### 10.4 HTML 邮件与内嵌图片

```cangjie
import mail.core.*
import mail.internet.*
import mail.activation.*

main() {
    let session = Session.getInstance(HashMap<String, String>())
    let message = MimeMessage(session)

    message.setFrom(InternetAddress("sender@example.com"))
    message.setRecipients(RecipientType.TO, InternetAddress.parse("recipient@example.com"))
    message.setSubject("HTML 邮件示例")

    // 创建 related 类型的多部分消息（用于 HTML + 内嵌资源）
    let multipart = MimeMultipart("related")

    // HTML 正文（引用内嵌图片）
    let htmlPart = MimeBodyPart()
    let htmlContent = """
        <html>
        <body>
            <h1>欢迎！</h1>
            <p>这是一封 HTML 邮件。</p>
            <img src="cid:logo123" alt="Logo"/>
        </body>
        </html>
    """
    htmlPart.setContent(htmlContent, "text/html; charset=UTF-8")
    multipart.addBodyPart(htmlPart)

    // 内嵌图片
    let imagePart = MimeBodyPart()
    let imageDataSource = FileDataSource("./logo.png")
    imagePart.setDataHandler(DataHandler(imageDataSource))
    imagePart.setContentID("<logo123>")  // 对应 HTML 中的 cid:logo123
    imagePart.setDisposition("inline")
    multipart.addBodyPart(imagePart)

    message.setContent(multipart)
}
```

### 10.5 使用 MimeUtility 处理中文

```cangjie
import mail.internet.*

main() {
    // 编码中文邮件主题
    let subject = "会议通知：明天下午3点"
    let encodedSubject = MimeUtility.encodeText(subject, "UTF-8", "B")
    println("编码后: ${encodedSubject}")
    // 输出: =?UTF-8?B?5Lya6K6u6YCa55+l77ya5piO5aSp5LiL5Y2NM+eCuQ==?=

    // 解码
    let decodedSubject = MimeUtility.decodeText(encodedSubject)
    println("解码后: ${decodedSubject}")
    // 输出: 会议通知：明天下午3点

    // 编码发件人名称
    let senderName = "张三"
    let encodedName = MimeUtility.encodeWord(senderName, "UTF-8", "B")
    println("编码后的名称: ${encodedName}")
}
```

### 10.6 解析 Content-Type

```cangjie
import mail.internet.*

main() {
    // 解析 Content-Type 字符串
    let contentType = ContentType("text/plain; charset=UTF-8; name=\"文档.txt\"")

    println("主类型: ${contentType.getPrimaryType()}")      // text
    println("子类型: ${contentType.getSubType()}")          // plain
    println("基础类型: ${contentType.getBaseType()}")       // text/plain
    println("字符集: ${contentType.getParameter(\"charset\")}") // UTF-8
    println("文件名: ${contentType.getParameter(\"name\")}")    // 文档.txt

    // 构建 Content-Type
    let newContentType = ContentType("application", "pdf", None)
    newContentType.setParameter("name", "report.pdf")
    println("构建的 Content-Type: ${newContentType.toString()}")
    // 输出: application/pdf; name="report.pdf"

    // 类型匹配
    let textType = ContentType("text/html")
    println("匹配 text/*: ${textType.match(\"text/*\")}")  // true
}
```

### 10.7 异常处理

```cangjie
import mail.core.*
import mail.internet.*
import mail.smtp.*

main() {
    try {
        let props = HashMap<String, String>()
        props.put("mail.smtp.host", "smtp.example.com")

        let session = Session.getInstance(props)
        let message = MimeMessage(session)

        // 设置无效地址（触发 AddressException）
        message.setRecipients(RecipientType.TO, InternetAddress.parse("invalid-address"))

        Transport.send(message)

    } catch (e: AddressException) {
        println("地址格式错误: ${e.message}")
        println("错误位置: ${e.getPos()}")
        println("引用地址: ${e.getRef()}")

    } catch (e: AuthenticationFailedException) {
        println("认证失败: ${e.message}")

    } catch (e: MailConnectException) {
        println("连接失败: ${e.getHost()}:${e.getPort()}")

    } catch (e: SendFailedException) {
        println("发送失败: ${e.message}")
        println("成功发送: ${e.getValidSentAddresses()}")
        println("未发送: ${e.getValidUnsentAddresses()}")
        println("无效地址: ${e.getInvalidAddresses()}")

    } catch (e: MessagingException) {
        println("邮件异常: ${e.message}")
    }
}
```

---

## 11. TLS 实现（基于 openHiTLS）

### 11.1 TlsSocket 封装

```cangjie
// tls/tls_socket.cj

/**
 * TLS Socket 封装
 * 基于 openHiTLS 提供安全的 TLS 连接
 */
public class TlsSocket {
    private var sslCtx: UnsafePointer<HitlsCtx>
    private var ssl: UnsafePointer<HitlsSsl>
    private var socket: TcpSocket
    private var connected: Bool = false

    /**
     * 创建 TLS Socket
     * @param verifyCert 是否验证服务器证书
     * @param caCertPath 自定义 CA 证书路径（可选）
     */
    public init(verifyCert: Bool, caCertPath: ?String)

    /**
     * 连接到 TLS 服务器
     */
    public func connect(host: String, port: Int): Unit

    /**
     * 发送数据
     */
    public func write(data: Array<Byte>): Int

    /**
     * 接收数据
     */
    public func read(buffer: Array<Byte>): Int

    /**
     * 关闭连接
     */
    public func close(): Unit
}
```

### 11.2 TlsSMTPTransport 实现

```cangjie
// tls/tls_smtp_transport.cj

/**
 * 基于 TLS 的 SMTP 传输
 * 对标: org.eclipse.angus.mail.smtp.SMTPSSLTransport
 */
public class TlsSMTPTransport <: Transport {
    private var tlsSocket: ?TlsSocket
    private var useSSL: Bool
    private var verifyCert: Bool = false
    private var caCertPath: ?String = None

    public init(session: Session, useSSL: Bool)

    /**
     * 设置证书验证
     */
    public func setVerifyCert(verify: Bool): Unit

    /**
     * 设置自定义 CA 证书
     */
    public func setCACertPath(path: String): Unit

    protected override func protocolConnect(
        host: String,
        port: Int,
        user: String,
        password: String
    ): Bool
}
```

---

## 12. 企业级 Handler（Angus-Mail 风格）

### 12.1 EmailHandler 设计

```cangjie
// demo/src/handler.cj

/**
 * 企业级邮件处理器
 * 仿 Angus-Mail Handler，提供高级邮件发送功能
 */
public class EmailHandler {
    private var serverConfig: EmailServerConfig
    private var transport: ?TlsSMTPTransport
    private var debug: Bool = false
    private var retryTimes: Int = 0
    private var retryInterval: Int64 = 1000

    /**
     * 创建 Handler
     */
    public init(serverConfig: EmailServerConfig)

    /**
     * 发送邮件（高效模式：单次连接发送多封）
     */
    public func sendEmail(emailInfo: EmailInfo): ArrayList<EmailStatus>

    /**
     * 发送邮件（非高效模式：每封邮件单独连接）
     */
    public func sendEmailInefficient(emailInfo: EmailInfo): ArrayList<EmailStatus>

    /**
     * 设置重试次数
     */
    public func setRetryTimes(times: Int): Unit

    /**
     * 设置重试间隔（毫秒）
     */
    public func setRetryInterval(interval: Int64): Unit
}
```

### 12.2 EmailInfo 配置类

```cangjie
/**
 * 邮件信息配置
 * 支持 TO/CC/BCC 多种收件人类型
 */
public class EmailInfo {
    // 单独发送的收件人（每人收到独立邮件）
    private var recipients: ArrayList<String>

    // 群发收件人（所有人能看到彼此）
    private var massRecipients: ArrayList<String>

    // 抄送收件人
    private var ccRecipients: ArrayList<String>

    // 密送收件人（其他人不可见）
    private var bccRecipients: ArrayList<String>

    public var subject: String
    public var subjectPrefix: String
    public var subjectSuffix: String
    public var content: String
    public var contentType: String = "text/plain"
    public var charset: String = "UTF-8"
    public var signature: String = ""

    private var attachments: ArrayList<String>

    /**
     * 添加单独发送的收件人
     */
    public func addRecipient(email: String): Unit

    /**
     * 添加群发收件人
     */
    public func addMassRecipient(email: String): Unit

    /**
     * 添加抄送收件人
     */
    public func addCcRecipient(email: String): Unit

    /**
     * 添加密送收件人
     */
    public func addBccRecipient(email: String): Unit

    /**
     * 添加附件
     */
    public func addAttachment(filePath: String): Unit
}
```

---

## 13. 实现状态

### 已完成功能 ✅

**核心框架**
- ✅ Session 会话管理
- ✅ Transport 传输抽象
- ✅ Message/MimeMessage 消息实现
- ✅ Address/InternetAddress 地址实现
- ✅ 完整的异常体系

**Internet 邮件规范**
- ✅ MimeMessage 完整实现
- ✅ MimeMultipart/MimeBodyPart
- ✅ InternetHeaders 邮件头处理
- ✅ MimeUtility 编码工具
- ✅ 附件和内嵌图片支持

**TLS 支持**
- ✅ TlsSocket 基于 openHiTLS
- ✅ TlsSMTPTransport TLS 传输
- ✅ 证书验证（系统 CA + 自定义 CA）
- ✅ SSL/TLS 握手和加密通信

**SMTP 协议**
- ✅ SMTPTransport 基础实现
- ✅ EHLO/HELO/MAIL/RCPT/DATA 命令
- ✅ LOGIN/PLAIN 认证
- ✅ TLS 加密传输

**数据激活框架**
- ✅ DataSource 接口
- ✅ FileDataSource 文件数据源
- ✅ ByteArrayDataSource 内存数据源
- ✅ DataHandler 数据处理器

**工具模块**
- ✅ Base64 编解码
- ✅ MIME 编码/解码
- ✅ 邮件头折叠/展开

**演示程序**
- ✅ 完整的 Demo 程序
- ✅ EmailHandler（Angus-Mail 风格）
- ✅ 配置文件管理（.env）
- ✅ 自动构建脚本（build.sh）
- ✅ 多种发送模式演示

### 待实现功能 🚧

**SMTP 高级特性**
- 🚧 STARTTLS 支持
- 🚧 8BITMIME 扩展
- 🚧 DSN（Delivery Status Notification）
- 🚧 SIZE 扩展

**优化功能**
- 🚧 连接池
- 🚧 异步发送
- 🚧 批量发送优化

**其他协议**
- ⏳ IMAP 接收协议
- ⏳ POP3 接收协议

---

## 14. 实现计划

### ~~第一阶段：核心框架~~ ✅

1. ✅ 基础类型定义
2. ✅ Session 实现
3. ✅ Message 基础

### ~~第二阶段：SMTP 协议~~ ✅

1. ✅ SMTPTransport 核心
2. ✅ 认证实现
3. ✅ 消息发送

### ~~第三阶段：完善功能~~ ✅

1. ✅ MIME 支持
2. ✅ 编码支持
3. ✅ TLS 加密

### ~~第四阶段：Demo 与文档~~ ✅

1. ✅ 企业级 Handler
2. ✅ 完整演示程序
3. ✅ 使用文档

### 第五阶段：高级特性与优化（进行中）

1. 🚧 STARTTLS 支持
2. 🚧 性能优化
3. 🚧 更多 SMTP 扩展

---

## 12. 依赖库

仓颉标准库模块：
- `std.collection` - 集合类型
- `std.io` - 输入输出流
- `std.net` - 网络（TCP Socket）
- `std.crypto` - 加密（TLS/SSL、MD5）
- `std.encoding` - 编码（Base64）
- `std.time` - 时间日期

---

## 13. 与 angus-mail 的接口对照

### 13.1 核心模块

| angus-mail (Java) | cangjie-mail (仓颉) | 说明 |
|-------------------|---------------------|------|
| `jakarta.mail.Session` | `mail.core.Session` | 完全对标 |
| `jakarta.mail.Transport` | `mail.core.Transport` | 完全对标 |
| `jakarta.mail.Message` | `mail.core.Message` | 完全对标 |
| `jakarta.mail.Authenticator` | `mail.core.Authenticator` | 完全对标 |
| `jakarta.mail.PasswordAuthentication` | `mail.core.PasswordAuthentication` | 完全对标 |
| `jakarta.mail.Provider` | `mail.core.Provider` | 完全对标 |

### 13.2 异常体系

| angus-mail (Java) | cangjie-mail (仓颉) | 说明 |
|-------------------|---------------------|------|
| `jakarta.mail.MessagingException` | `mail.core.MessagingException` | 完全对标 |
| `jakarta.mail.internet.AddressException` | `mail.core.AddressException` | 完全对标 |
| `jakarta.mail.AuthenticationFailedException` | `mail.core.AuthenticationFailedException` | 完全对标 |
| `jakarta.mail.SendFailedException` | `mail.core.SendFailedException` | 完全对标 |
| `jakarta.mail.internet.ParseException` | `mail.core.ParseException` | 完全对标 |
| `o.e.a.mail.util.MailConnectException` | `mail.core.MailConnectException` | 完全对标 |

### 13.3 数据激活框架

| angus-mail (Java) | cangjie-mail (仓颉) | 说明 |
|-------------------|---------------------|------|
| `jakarta.activation.DataSource` | `mail.activation.DataSource` | 完全对标 |
| `jakarta.activation.DataHandler` | `mail.activation.DataHandler` | 完全对标 |
| `jakarta.activation.FileDataSource` | `mail.activation.FileDataSource` | 完全对标 |
| `jakarta.mail.util.ByteArrayDataSource` | `mail.activation.ByteArrayDataSource` | 完全对标 |

### 13.4 Internet 邮件规范

| angus-mail (Java) | cangjie-mail (仓颉) | 说明 |
|-------------------|---------------------|------|
| `jakarta.mail.internet.MimeMessage` | `mail.internet.MimeMessage` | 完全对标 |
| `jakarta.mail.internet.InternetAddress` | `mail.internet.InternetAddress` | 完全对标 |
| `jakarta.mail.internet.MimeMultipart` | `mail.internet.MimeMultipart` | 完全对标 |
| `jakarta.mail.internet.MimeBodyPart` | `mail.internet.MimeBodyPart` | 完全对标 |
| `jakarta.mail.internet.MimeUtility` | `mail.internet.MimeUtility` | 完全对标 |
| `jakarta.mail.internet.ContentType` | `mail.internet.ContentType` | 完全对标 |
| `jakarta.mail.internet.ContentDisposition` | `mail.internet.ContentDisposition` | 完全对标 |
| `jakarta.mail.internet.ParameterList` | `mail.util.ParameterList` | 完全对标 |
| `jakarta.mail.internet.HeaderTokenizer` | `mail.internet.HeaderTokenizer` | 完全对标 |

### 13.5 SMTP 协议

| angus-mail (Java) | cangjie-mail (仓颉) | 说明 |
|-------------------|---------------------|------|
| `o.e.a.mail.smtp.SMTPTransport` | `mail.smtp.SMTPTransport` | 完全对标 |
| `o.e.a.mail.smtp.SMTPSSLTransport` | `mail.smtp.SMTPSSLTransport` | 完全对标 |
| `o.e.a.mail.smtp.SMTPMessage` | `mail.smtp.SMTPMessage` | 完全对标 |
| `o.e.a.mail.smtp.SMTPProvider` | `mail.smtp.SMTPProvider` | 完全对标 |
| `o.e.a.mail.smtp.SMTPSendFailedException` | `mail.smtp.SMTPSendFailedException` | 完全对标 |
| `o.e.a.mail.smtp.SMTPAddressFailedException` | `mail.smtp.SMTPAddressFailedException` | 完全对标 |

---

## 14. 注意事项

1. **仓颉语言特性适配**
   - 使用 `?T` 替代 Java 的 `null`
   - 使用枚举替代 Java 的常量类
   - 使用接口替代 Java 的抽象类（视情况）

2. **线程安全**
   - SMTPTransport 的关键方法需要同步
   - Session 可以考虑做成线程安全的

3. **资源管理**
   - 正确关闭 Socket 连接
   - 使用 try-with-resources 模式（如果仓颉支持）

4. **错误处理**
   - 保持与 angus-mail 一致的异常层次
   - 提供详细的错误信息

---

## 15. 后续扩展

当前版本完成后，可以考虑：

1. **接收协议支持**
   - IMAP 协议
   - POP3 协议

2. **高级功能**
   - DKIM 签名
   - S/MIME 加密
   - 邮件模板

3. **性能优化**
   - 连接池
   - 异步发送
   - 批量发送
