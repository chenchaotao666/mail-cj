/**
 * openHiTLS FFI 绑定声明
 *
 * 本文件声明了 openHiTLS C 库的外部函数接口
 *
 * 已配置:
 * - openHiTLS 库安装路径: ~/.local/lib/hitls
 * - 头文件路径: ~/.local/include/hitls
 */
package mail.tls

// ============================================================================
// 编译模式开关
// ============================================================================
// 注意：openHiTLS需要正确初始化随机数生成器
// 当前暂时使用模拟模式 + stunnel代理方案
public let USE_MOCK_TLS: Bool = false  // 真实模式（使用 openHiTLS）

// ============================================================================
// openHiTLS 常量定义
// ============================================================================

/**
 * openHiTLS 返回码
 */
public let HITLS_SUCCESS: Int32 = 0
public let HITLS_ERROR: Int32 = -1

/**
 * TLS 版本常量
 */
public let HITLS_VERSION_TLS12: UInt32 = 0x0303
public let HITLS_VERSION_TLS13: UInt32 = 0x0304

/**
 * 证书格式
 */
public let TLS_PARSE_FORMAT_PEM: Int32 = 0
public let TLS_PARSE_FORMAT_ASN1: Int32 = 1

/**
 * UIO 类型
 */
public let BSL_UIO_TCP: Int32 = 0
public let BSL_UIO_SCTP: Int32 = 1

/**
 * 验证模式
 */
public let HITLS_CFG_VERIFY_NONE: UInt32 = 0
public let HITLS_CFG_VERIFY_PEER: UInt32 = 1
public let HITLS_CFG_VERIFY_FAIL_IF_NO_PEER_CERT: UInt32 = 2

/**
 * 握手状态返回值
 */
public let HITLS_RET_WANT_READ: Int32 = -2
public let HITLS_RET_WANT_WRITE: Int32 = -3

/**
 * UIO 控制命令
 * BSL_UIO_SET_PEER_IP_ADDR = 0x000
 * BSL_UIO_GET_PEER_IP_ADDR = 0x001
 * BSL_UIO_SET_FD = 0x002
 * BSL_UIO_GET_FD = 0x003
 */
public let BSL_UIO_SET_FD: Int32 = 2
public let BSL_UIO_GET_FD: Int32 = 3

// ============================================================================
// 不透明指针类型定义
// ============================================================================

/**
 * HITLS_Ctx 不透明指针类型
 */
public type HitlsCtx = CPointer<Unit>

/**
 * HITLS_Config 不透明指针类型
 */
public type HitlsConfig = CPointer<Unit>

/**
 * BSL_UIO 不透明指针类型（用于 I/O 操作）
 */
public type BslUio = CPointer<Unit>

/**
 * BSL_UIO_Method 不透明指针类型
 */
public type BslUioMethod = CPointer<Unit>

// ============================================================================
// FFI 外部函数声明
// ============================================================================

// BSL 初始化函数
@C
foreign func BSL_ERR_Init(): Int32

@C
foreign func BSL_GLOBAL_Init(): Int32

// TLS 加密和证书初始化
@C
foreign func HITLS_CryptMethodInit(): Unit

@C
foreign func HITLS_CertMethodInit(): Int32

// 错误获取函数
@C
foreign func BSL_ERR_GetLastError(): Int32

// 随机数初始化（启用真实TLS时需要先调用）
// CRYPT_EAL_RandInit(id, seedMeth, seedCtx, pers, persLen)
@C
foreign func CRYPT_EAL_RandInit(id: Int32, seedMeth: CPointer<Unit>, seedCtx: CPointer<Unit>, pers: CPointer<UInt8>, persLen: UInt32): Int32

@C
foreign func CRYPT_EAL_RandDeinit(): Unit

// 全局加密库初始化
// CRYPT_EAL_INIT_ALL = 0x01 | 0x02 | 0x04 | 0x08 | 0x20 | 0x10 = 0x3F
@C
foreign func CRYPT_EAL_Init(opts: UInt64): Int32

@C
foreign func CRYPT_EAL_Cleanup(opts: UInt64): Unit

// 初始化选项
public let CRYPT_EAL_INIT_ALL: UInt64 = 0x3F

// 随机数算法ID (来自 bsl_obj.h: BSL_CID_RAND_SHA256 = 2040)
public let CRYPT_RAND_SHA256: Int32 = 2040

// TLS 配置函数
@C
foreign func HITLS_CFG_NewTLS12Config(): HitlsConfig

@C
foreign func HITLS_CFG_NewTLS13Config(): HitlsConfig

@C
foreign func HITLS_CFG_FreeConfig(config: HitlsConfig): Unit

@C
foreign func HITLS_CFG_SetClientVerifySupport(config: HitlsConfig, support: Bool): Int32

// 设置是否跳过证书验证（重要：用于不验证服务器证书的场景）
@C
foreign func HITLS_CFG_SetVerifyNoneSupport(config: HitlsConfig, support: Bool): Int32

// 证书验证相关函数
// 加载 CA 证书文件用于验证对端证书
@C
foreign func HITLS_CFG_LoadVerifyFile(config: HitlsConfig, caFile: CPointer<UInt8>): Int32

// 加载 CA 证书目录
@C
foreign func HITLS_CFG_LoadVerifyDir(config: HitlsConfig, caPath: CPointer<UInt8>): Int32

// 加载默认系统 CA 证书路径
@C
foreign func HITLS_CFG_LoadDefaultCAPath(config: HitlsConfig): Int32

// 加载客户端证书文件
@C
foreign func HITLS_CFG_LoadCertFile(config: HitlsConfig, certFile: CPointer<UInt8>, format: Int32): Int32

// 加载客户端私钥文件
@C
foreign func HITLS_CFG_LoadKeyFile(config: HitlsConfig, keyFile: CPointer<UInt8>, format: Int32): Int32

// TLS 上下文函数
@C
foreign func HITLS_New(config: HitlsConfig): HitlsCtx

@C
foreign func HITLS_Free(ctx: HitlsCtx): Unit

// UIO 函数
@C
foreign func BSL_UIO_TcpMethod(): BslUioMethod

@C
foreign func BSL_UIO_New(method: BslUioMethod): BslUio

@C
foreign func BSL_UIO_Free(uio: BslUio): Unit

@C
foreign func BSL_UIO_Ctrl(uio: BslUio, cmd: Int32, larg: Int32, parg: CPointer<Int32>): Int32

// 设置 UIO 到 TLS 上下文
@C
foreign func HITLS_SetUio(ctx: HitlsCtx, uio: BslUio): Int32

// TLS 握手函数
@C
foreign func HITLS_Connect(ctx: HitlsCtx): Int32

// TLS 数据传输函数
@C
foreign func HITLS_Read(ctx: HitlsCtx, data: CPointer<UInt8>, bufSize: UInt32, readLen: CPointer<UInt32>): Int32

@C
foreign func HITLS_Write(ctx: HitlsCtx, data: CPointer<UInt8>, dataLen: UInt32, writeLen: CPointer<UInt32>): Int32

// TLS 连接管理函数
@C
foreign func HITLS_Close(ctx: HitlsCtx): Int32

@C
foreign func HITLS_GetVersionSupport(ctx: HitlsCtx, version: CPointer<UInt32>): Int32

@C
foreign func HITLS_IsHandShakeDone(ctx: HitlsCtx, isDone: CPointer<UInt8>): Int32

// LibC 函数
@C
foreign func malloc(size: UInt64): CPointer<Unit>

@C
foreign func free(ptr: CPointer<Unit>): Unit

@C
foreign func memcpy(dest: CPointer<Unit>, src: CPointer<Unit>, n: UInt64): CPointer<Unit>

// Socket 函数
@C
foreign func socket(domain: Int32, sockType: Int32, protocol: Int32): Int32

@C
foreign func connect(sockfd: Int32, addr: CPointer<Unit>, addrlen: UInt32): Int32

@C
foreign func close(fd: Int32): Int32

@C
foreign func htons(hostshort: UInt16): UInt16

@C
foreign func inet_pton(af: Int32, src: CPointer<UInt8>, dst: CPointer<Unit>): Int32

@C
foreign func getaddrinfo(
    node: CPointer<UInt8>,
    service: CPointer<UInt8>,
    hints: CPointer<Unit>,
    res: CPointer<CPointer<Unit>>
): Int32

@C
foreign func freeaddrinfo(res: CPointer<Unit>): Unit

// 常量
public let AF_INET: Int32 = 2
public let SOCK_STREAM: Int32 = 1

// ============================================================================
// 辅助函数
// ============================================================================

/**
 * 将 Cangjie 字符串转换为 C 字符串指针
 */
public func stringToCString(str: String): CPointer<UInt8> {
    let bytes = str.toArray()
    unsafe {
        let ptr = malloc(UInt64(bytes.size + 1))
        let cstr = CPointer<UInt8>(ptr)
        for (i in 0..bytes.size) {
            (cstr + i).write(UInt8(bytes[i]))
        }
        (cstr + bytes.size).write(0u8)  // null terminator
        cstr
    }
}

/**
 * 释放 C 字符串指针
 */
public func freeCString(ptr: CPointer<UInt8>): Unit {
    unsafe {
        free(CPointer<Unit>(ptr))
    }
}

/**
 * 初始化加密提供者（兼容旧接口）
 */
public func CRYPT_EAL_RegDefaultProvider(): Int32 {
    unsafe {
        HITLS_CryptMethodInit()
        HITLS_CertMethodInit()
    }
}

/**
 * 检查 TLS 是否处于模拟模式
 */
public func isTlsMockMode(): Bool {
    USE_MOCK_TLS
}

/**
 * 获取 TLS 模式描述
 */
public func getTlsModeDescription(): String {
    "FFI 模式 (使用 openHiTLS)"
}

// LibC 辅助类
public class LibC {
    public static func mallocBytes(size: UInt64): CPointer<Unit> {
        unsafe { malloc(size) }
    }

    public static func freePtr(ptr: CPointer<Unit>): Unit {
        unsafe { free(ptr) }
    }
}

// addrinfo结构体大小（近似值，实际可能因平台而异）
let ADDRINFO_SIZE: Int64 = 48

// addrinfo结构体字段偏移
let AI_FAMILY_OFFSET: Int64 = 4
let AI_SOCKTYPE_OFFSET: Int64 = 8
let AI_ADDR_OFFSET: Int64 = 24
let AI_ADDRLEN_OFFSET: Int64 = 16

/**
 * 创建 TCP socket 并连接到指定主机和端口
 * 支持主机名和IP地址
 */
public func createTcpConnection(host: String, port: UInt16): Int32 {
    unsafe {
        // 准备 hints
        let hintsPtr = malloc(UInt64(ADDRINFO_SIZE))
        let hintsBytes = CPointer<UInt8>(hintsPtr)
        // 清零
        for (i in 0..ADDRINFO_SIZE) {
            (hintsBytes + i).write(0u8)
        }
        // 设置 ai_family = AF_INET
        let familyPtr = CPointer<Int32>(CPointer<Unit>(hintsBytes + AI_FAMILY_OFFSET))
        familyPtr.write(AF_INET)
        // 设置 ai_socktype = SOCK_STREAM
        let socktypePtr = CPointer<Int32>(CPointer<Unit>(hintsBytes + AI_SOCKTYPE_OFFSET))
        socktypePtr.write(SOCK_STREAM)

        // 准备结果指针
        let resPtr = malloc(8)  // sizeof(pointer)
        let resCPtr = CPointer<CPointer<Unit>>(resPtr)

        let hostCStr = stringToCString(host)
        let portStr = port.toString()
        let portCStr = stringToCString(portStr)

        let gaiRet = getaddrinfo(hostCStr, portCStr, hintsPtr, resCPtr)

        freeCString(hostCStr)
        freeCString(portCStr)
        free(hintsPtr)

        if (gaiRet != 0) {
            free(resPtr)
            return -1
        }

        let addrInfo = resCPtr.read()
        if (addrInfo.isNull()) {
            free(resPtr)
            return -1
        }

        // 从addrinfo获取地址信息
        let aiBytes = CPointer<UInt8>(addrInfo)

        // 获取 ai_addr 和 ai_addrlen
        let aiAddrPtr = CPointer<CPointer<Unit>>(CPointer<Unit>(aiBytes + AI_ADDR_OFFSET))
        let aiAddrLenPtr = CPointer<UInt32>(CPointer<Unit>(aiBytes + AI_ADDRLEN_OFFSET))

        let sockAddr = aiAddrPtr.read()
        let addrLen = aiAddrLenPtr.read()

        // 创建 socket
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        if (sockfd < 0) {
            freeaddrinfo(addrInfo)
            free(resPtr)
            return -1
        }

        // 连接
        let connectRet = connect(sockfd, sockAddr, addrLen)

        freeaddrinfo(addrInfo)
        free(resPtr)

        if (connectRet < 0) {
            close(sockfd)
            return -1
        }

        sockfd
    }
}
