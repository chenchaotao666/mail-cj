# Cangjie Mail TLS 模块

基于 [openHiTLS](https://github.com/openHiTLS/openHiTLS) 的 TLS/SSL 支持模块。

## 当前状态

TLS 模块已完成与 openHiTLS 的集成，支持真正的 TLS 加密邮件发送。

## 前置条件

### 1. 安装 openHiTLS

```bash
# 克隆 openHiTLS
git clone https://gitcode.com/openhitls/openhitls.git
cd openhitls

# 下载 libboundscheck
git clone https://gitee.com/openeuler/libboundscheck.git platform/Secure_C/libboundscheck

# 构建
mkdir -p build && cd build
python3 ../configure.py
cmake ..
make -j$(nproc)

# 安装到指定目录（例如 ~/.local）
cmake --install . --prefix ~/.local
```

### 2. 配置 cjpm.toml

在项目的 `cjpm.toml` 中添加 FFI 配置：

```toml
[ffi.c]
hitls_tls = { path = "/path/to/hitls/lib" }
hitls_crypto = { path = "/path/to/hitls/lib" }
hitls_bsl = { path = "/path/to/hitls/lib" }
hitls_pki = { path = "/path/to/hitls/lib" }
hitls_auth = { path = "/path/to/hitls/lib" }
boundscheck = { path = "/path/to/hitls/lib" }
```

### 3. 设置运行时库路径

```bash
export LD_LIBRARY_PATH=/path/to/hitls/lib:$LD_LIBRARY_PATH
```

## 使用方法

### 直接 SSL 连接 (SMTPS, 端口 465)

```cangjie
import mail.tls.*
import mail.core.*
import mail.internet.*
import std.collection.*

// 创建会话
let props = HashMap<String, String>()
props["mail.smtps.host"] = "smtp.qq.com"
props["mail.smtps.port"] = "465"
props["mail.smtps.auth"] = "true"

let session = Session.getInstance(props)
session.setDebug(true)

// 创建 TLS SMTP 传输（true = 使用 SSL）
let transport = TlsSMTPTransport(session, true)
transport.connect("smtp.qq.com", 465, "user@qq.com", "auth_code")

// 创建并发送邮件
let message = MimeMessage(session)
message.setFrom(InternetAddress("user@qq.com"))
message.setRecipients(RecipientType.TO, InternetAddress.parse("recipient@example.com"))
message.setSubject("测试邮件")
message.setText("这是通过 TLS 发送的邮件")

transport.sendMessage(message, message.getAllRecipients())
transport.close()
```

### 底层 TLS Socket 使用

```cangjie
import mail.tls.*

// 创建配置
let config = TlsConfig(TLS_1_2)
    .setVerifyMode(VERIFY_NONE)
config.initialize()

// 创建 TLS Socket
let socket = TlsSocket(config)
socket.connect("smtp.qq.com", 465)

// 发送数据
socket.writeString("EHLO localhost\r\n")

// 读取响应
let response = socket.readLine()
println("响应: ${response}")

// 关闭
socket.close()
config.close()
```

### 检查 TLS 模式

```cangjie
import mail.tls.*

// 检查当前模式
if (isTlsMockMode()) {
    println("警告: TLS 处于模拟模式")
    println(getTlsModeDescription())
} else {
    println("TLS 模式: FFI (使用 openHiTLS)")
}
```

## 模块结构

```
src/tls/
├── main.cj              # 模块入口
├── hitls_ffi.cj         # openHiTLS FFI 绑定声明
├── tls_config.cj        # TLS 配置类
├── tls_socket.cj        # TLS Socket 封装
├── tls_exception.cj     # TLS 异常定义
├── tls_smtp_transport.cj # TLS SMTP 传输实现
└── README.md            # 本文档
```

## API 参考

### TlsConfig

| 方法 | 说明 |
|------|------|
| `init()` | 创建默认 TLS 1.2 配置 |
| `init(version: TlsVersion)` | 创建指定版本配置 |
| `initialize()` | 初始化配置（必须在使用前调用）|
| `setVersion(version)` | 设置 TLS 版本 |
| `setVerifyMode(mode)` | 设置证书验证模式 |
| `setCACertPath(path)` | 设置 CA 证书路径 |
| `setCertPath(path)` | 设置客户端证书路径 |
| `setKeyPath(path)` | 设置私钥路径 |
| `loadCertificates()` | 加载证书 |
| `close()` | 释放资源 |

### TlsSocket

| 方法 | 说明 |
|------|------|
| `init(config: TlsConfig)` | 使用配置创建 |
| `connect(host, port)` | 连接到服务器 |
| `connectWithFd(fd)` | 使用已有 fd 连接（STARTTLS）|
| `write(data)` | 写入数据 |
| `writeString(str)` | 写入字符串 |
| `read(buffer)` | 读取数据 |
| `readLine()` | 读取一行 |
| `isHandshakeDone()` | 检查握手是否完成 |
| `getNegotiatedVersion()` | 获取协商的 TLS 版本 |
| `close()` | 关闭连接 |

### TlsSMTPTransport

| 方法 | 说明 |
|------|------|
| `init(session, useSSL)` | 创建传输 |
| `connect(host, port, user, password)` | 连接并认证 |
| `sendMessage(message, addresses)` | 发送邮件 |
| `supportsExtension(ext)` | 检查扩展支持 |
| `close()` | 关闭连接 |

## FFI 函数列表

### 初始化函数

| 函数 | 说明 |
|------|------|
| `BSL_ERR_Init` | 初始化 BSL 错误处理 |
| `BSL_GLOBAL_Init` | 初始化 BSL 全局环境 |
| `CRYPT_EAL_Init` | 初始化加密库（包括随机数）|
| `HITLS_CryptMethodInit` | 注册加密方法 |
| `HITLS_CertMethodInit` | 注册证书方法 |

### 核心函数

| 函数 | 说明 |
|------|------|
| `HITLS_New` | 创建 TLS 上下文 |
| `HITLS_Free` | 释放 TLS 上下文 |
| `HITLS_Connect` | 客户端发起 TLS 握手 |
| `HITLS_Read` | 读取加密数据 |
| `HITLS_Write` | 写入加密数据 |
| `HITLS_Close` | 关闭 TLS 连接 |
| `HITLS_SetUio` | 设置 UIO |

### UIO 函数

| 函数 | 说明 |
|------|------|
| `BSL_UIO_TcpMethod` | 获取 TCP 方法 |
| `BSL_UIO_New` | 创建 UIO |
| `BSL_UIO_Free` | 释放 UIO |
| `BSL_UIO_Ctrl` | 控制 UIO（设置 fd 等）|

### 配置函数

| 函数 | 说明 |
|------|------|
| `HITLS_CFG_NewTLS12Config` | 创建 TLS 1.2 配置 |
| `HITLS_CFG_NewTLS13Config` | 创建 TLS 1.3 配置 |
| `HITLS_CFG_FreeConfig` | 释放配置 |
| `HITLS_CFG_SetClientVerifySupport` | 设置客户端验证 |
| `HITLS_CFG_SetVerifyNoneSupport` | 设置不验证模式 |

### 辅助函数

| 函数 | 说明 |
|------|------|
| `stringToCString(str)` | 将字符串转换为 C 字符串 |
| `freeCString(ptr)` | 释放 C 字符串 |
| `isTlsMockMode()` | 检查是否模拟模式 |
| `getTlsModeDescription()` | 获取模式描述 |
| `createTcpConnection(host, port)` | 创建 TCP 连接 |

## 备用方案

如果无法安装 openHiTLS，可以使用 **stunnel** 作为 SSL 代理：

```bash
# 安装 stunnel
sudo apt install stunnel4

# 创建配置文件 /etc/stunnel/smtp.conf
[smtp-tls]
client = yes
accept = 127.0.0.1:2525
connect = smtp.qq.com:465

# 启动 stunnel
sudo stunnel /etc/stunnel/smtp.conf
```

然后在应用中连接到 `127.0.0.1:2525`（明文 SMTP），stunnel 会自动进行 TLS 加密。

## 注意事项

1. **证书验证**: 默认配置不验证服务器证书（`VERIFY_NONE`），生产环境建议启用证书验证
2. **线程安全**: 每个连接应使用独立的 TLS 上下文
3. **资源释放**: 使用完毕后务必调用 `close()` 释放资源
4. **错误处理**: 所有 TLS 操作可能抛出 `TlsException`
5. **运行时库**: 确保 `LD_LIBRARY_PATH` 包含 openHiTLS 库路径

## 已实现功能

- [x] openHiTLS FFI 绑定
- [x] TLS 配置管理
- [x] TLS Socket 封装
- [x] TLS SMTP 传输 (SMTPS, 端口 465)
- [x] 不验证证书模式
- [x] TCP 连接（使用系统调用）

## 待实现功能

- [ ] STARTTLS 支持（升级现有连接）
- [ ] 客户端证书认证
- [ ] 会话恢复
- [ ] 证书验证（加载 CA 证书）
- [ ] TLS 1.3 专用功能
