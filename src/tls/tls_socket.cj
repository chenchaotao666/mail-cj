/**
 * TLS 加密套接字
 */
package mail.tls

/**
 * TLS 加密套接字
 *
 * 封装 openHiTLS 提供 TLS 加密通信能力
 *
 * 使用示例：
 * ```
 * let config = createClientConfig()
 * config.initialize()
 *
 * let socket = TlsSocket(config)
 * socket.connect("smtp.qq.com", 465)
 * socket.write("EHLO localhost\r\n".toArray())
 *
 * let buffer = Array<Byte>(1024, repeat: 0)
 * let n = socket.read(buffer)
 *
 * socket.close()
 * config.close()
 * ```
 */
public class TlsSocket {
    private var _config: TlsConfig
    private var _ctx: HitlsCtx = CPointer<Unit>()
    private var _uio: BslUio = CPointer<Unit>()
    private var _fd: Int32 = -1
    private var _connected: Bool = false
    private var _host: String = ""
    private var _port: UInt16 = 0

    /**
     * 使用配置构造
     */
    public init(config: TlsConfig) {
        _config = config
    }

    /**
     * 连接到 TLS 服务器
     *
     * @param host 主机名或IP地址
     * @param port 端口号
     */
    public func connect(host: String, port: UInt16): Unit {
        if (_connected) {
            throw TlsException("已经连接")
        }

        _host = host
        _port = port

        // 确保配置已初始化
        if (!_config.isInitialized()) {
            _config.initialize()
        }

        // 创建 TCP 连接
        _fd = createTcpConnection(host, port)
        if (_fd < 0) {
            throw TlsException("创建 TCP 连接失败: ${host}:${port}")
        }

        unsafe {
            // 创建 TLS 上下文
            _ctx = HITLS_New(_config.getConfigPtr())
            if (_ctx.isNull()) {
                close(_fd)
                throw TlsException("创建 TLS 上下文失败")
            }

            // 创建 UIO 并设置 fd
            let tcpMethod = BSL_UIO_TcpMethod()
            _uio = BSL_UIO_New(tcpMethod)
            if (_uio.isNull()) {
                HITLS_Free(_ctx)
                close(_fd)
                throw TlsException("创建 BSL_UIO 失败")
            }

            // 设置 socket fd 到 UIO
            // larg = 4 (sizeof(int32_t)), parg = pointer to fd
            let fdPtr = malloc(4)  // sizeof(int32_t)
            let fdCPtr = CPointer<Int32>(fdPtr)
            fdCPtr.write(_fd)
            let setFdRet = BSL_UIO_Ctrl(_uio, BSL_UIO_SET_FD, 4, fdCPtr)
            free(fdPtr)

            if (setFdRet != HITLS_SUCCESS) {
                BSL_UIO_Free(_uio)
                HITLS_Free(_ctx)
                close(_fd)
                throw TlsException("设置 socket fd 到 UIO 失败", setFdRet)
            }

            // 将 UIO 设置到 TLS 上下文
            let setUioRet = HITLS_SetUio(_ctx, _uio)
            if (setUioRet != HITLS_SUCCESS) {
                BSL_UIO_Free(_uio)
                HITLS_Free(_ctx)
                close(_fd)
                throw TlsException("设置 UIO 到 TLS 上下文失败", setUioRet)
            }

            // 执行 TLS 握手
            let connectRet = doHandshake()
            if (connectRet != HITLS_SUCCESS) {
                BSL_UIO_Free(_uio)
                HITLS_Free(_ctx)
                close(_fd)
                throw TlsHandshakeException("TLS 握手失败", connectRet)
            }
        }

        _connected = true
    }

    /**
     * 执行 TLS 握手（支持非阻塞重试）
     */
    private func doHandshake(): Int32 {
        unsafe {
            var ret = HITLS_Connect(_ctx)

            // 处理非阻塞情况下的重试
            var retryCount = 0
            let maxRetries = 100

            while ((ret == HITLS_RET_WANT_READ || ret == HITLS_RET_WANT_WRITE) && retryCount < maxRetries) {
                retryCount++
                ret = HITLS_Connect(_ctx)
            }

            ret
        }
    }

    /**
     * 使用已有的 socket fd 进行 TLS 握手
     *
     * @param fd socket 文件描述符
     */
    public func connectWithFd(fd: Int32): Unit {
        if (_connected) {
            throw TlsException("已经连接")
        }

        _fd = fd

        // 确保配置已初始化
        if (!_config.isInitialized()) {
            _config.initialize()
        }

        unsafe {
            // 创建 TLS 上下文
            _ctx = HITLS_New(_config.getConfigPtr())
            if (_ctx.isNull()) {
                throw TlsException("创建 TLS 上下文失败")
            }

            // 创建 UIO 并设置 fd
            let tcpMethod = BSL_UIO_TcpMethod()
            _uio = BSL_UIO_New(tcpMethod)
            if (_uio.isNull()) {
                HITLS_Free(_ctx)
                throw TlsException("创建 BSL_UIO 失败")
            }

            // 设置 socket fd 到 UIO
            // larg = 4 (sizeof(int32_t)), parg = pointer to fd
            let fdPtr = malloc(4)
            let fdCPtr = CPointer<Int32>(fdPtr)
            fdCPtr.write(_fd)
            let setFdRet = BSL_UIO_Ctrl(_uio, BSL_UIO_SET_FD, 4, fdCPtr)
            free(fdPtr)

            if (setFdRet != HITLS_SUCCESS) {
                BSL_UIO_Free(_uio)
                HITLS_Free(_ctx)
                throw TlsException("设置 socket fd 失败", setFdRet)
            }

            // 将 UIO 设置到 TLS 上下文
            let setUioRet = HITLS_SetUio(_ctx, _uio)
            if (setUioRet != HITLS_SUCCESS) {
                BSL_UIO_Free(_uio)
                HITLS_Free(_ctx)
                throw TlsException("设置 UIO 失败", setUioRet)
            }

            // 执行 TLS 握手
            let connectRet = doHandshake()
            if (connectRet != HITLS_SUCCESS) {
                BSL_UIO_Free(_uio)
                HITLS_Free(_ctx)
                throw TlsHandshakeException("TLS 握手失败", connectRet)
            }
        }

        _connected = true
    }

    /**
     * 写入数据
     *
     * @param data 要发送的数据
     * @return 实际发送的字节数
     */
    public func write(data: Array<Byte>): Int64 {
        if (!_connected) {
            throw TlsException("未连接")
        }

        if (data.isEmpty()) {
            return 0
        }

        unsafe {
            // 分配缓冲区并复制数据
            let ptr = malloc(UInt64(data.size))
            let dataPtr = CPointer<UInt8>(ptr)
            for (i in 0..data.size) {
                (dataPtr + i).write(UInt8(data[i]))
            }

            // 分配写入长度返回值
            let writeLenPtr = malloc(4)
            let writeLenCPtr = CPointer<UInt32>(writeLenPtr)
            writeLenCPtr.write(0u32)

            let ret = HITLS_Write(
                _ctx,
                dataPtr,
                UInt32(data.size),
                writeLenCPtr
            )

            let writeLen = writeLenCPtr.read()

            free(ptr)
            free(writeLenPtr)

            if (ret != HITLS_SUCCESS) {
                throw TlsException("写入数据失败", ret)
            }

            Int64(writeLen)
        }
    }

    /**
     * 写入字符串
     *
     * @param str 要发送的字符串
     * @return 实际发送的字节数
     */
    public func writeString(str: String): Int64 {
        write(str.toArray())
    }

    /**
     * 读取数据
     *
     * @param buffer 接收缓冲区
     * @return 实际读取的字节数，0 表示连接关闭
     */
    public func read(buffer: Array<Byte>): Int64 {
        if (!_connected) {
            throw TlsException("未连接")
        }

        if (buffer.isEmpty()) {
            return 0
        }

        unsafe {
            // 分配读取缓冲区
            let ptr = malloc(UInt64(buffer.size))
            let dataPtr = CPointer<UInt8>(ptr)

            // 分配读取长度返回值
            let readLenPtr = malloc(4)
            let readLenCPtr = CPointer<UInt32>(readLenPtr)
            readLenCPtr.write(0u32)

            let ret = HITLS_Read(
                _ctx,
                dataPtr,
                UInt32(buffer.size),
                readLenCPtr
            )

            if (ret != HITLS_SUCCESS && ret != HITLS_RET_WANT_READ) {
                free(ptr)
                free(readLenPtr)
                throw TlsException("读取数据失败", ret)
            }

            let readLen = readLenCPtr.read()

            // 复制数据到缓冲区
            for (i in 0..Int64(readLen)) {
                buffer[i] = (dataPtr + i).read()
            }

            free(ptr)
            free(readLenPtr)

            Int64(readLen)
        }
    }

    /**
     * 读取一行（以 \n 结尾）
     *
     * @return 读取的行内容（不包含换行符）
     */
    public func readLine(): String {
        var result = ""
        let buffer = Array<Byte>(1, repeat: 0)

        while (true) {
            let n = read(buffer)
            if (n <= 0) {
                break
            }

            let ch = Rune(buffer[0])
            if (ch == r'\n') {
                break
            } else if (ch != r'\r') {
                result += String([ch])
            }
        }

        result
    }

    /**
     * 检查握手是否完成
     */
    public func isHandshakeDone(): Bool {
        if (!_connected) {
            return false
        }

        unsafe {
            let isDonePtr = malloc(1)
            let isDoneCPtr = CPointer<UInt8>(isDonePtr)
            isDoneCPtr.write(0u8)

            let ret = HITLS_IsHandShakeDone(_ctx, isDoneCPtr)
            let isDone = isDoneCPtr.read()

            free(isDonePtr)

            ret == HITLS_SUCCESS && isDone == 1u8
        }
    }

    /**
     * 获取协商的 TLS 版本
     */
    public func getNegotiatedVersion(): TlsVersion {
        if (!_connected) {
            throw TlsException("未连接")
        }

        unsafe {
            let versionPtr = malloc(4)
            let versionCPtr = CPointer<UInt32>(versionPtr)
            versionCPtr.write(0u32)

            HITLS_GetVersionSupport(_ctx, versionCPtr)
            let version = versionCPtr.read()

            free(versionPtr)

            match (version) {
                case _ where version == HITLS_VERSION_TLS13 => TLS_1_3
                case _ => TLS_1_2
            }
        }
    }

    /**
     * 关闭连接
     */
    public func close(): Unit {
        if (_connected) {
            unsafe {
                // 发送 close_notify
                HITLS_Close(_ctx)

                // 释放 TLS 上下文（这也会释放 UIO）
                if (!_ctx.isNull()) {
                    HITLS_Free(_ctx)
                    _ctx = CPointer<Unit>()
                }

                // 关闭底层 socket
                if (_fd >= 0) {
                    close(_fd)
                    _fd = -1
                }
            }

            _connected = false
        }
    }

    /**
     * 是否已连接
     */
    public func isConnected(): Bool {
        _connected
    }

    /**
     * 获取主机名
     */
    public func getHost(): String {
        _host
    }

    /**
     * 获取端口
     */
    public func getPort(): UInt16 {
        _port
    }
}

/**
 * 在现有 socket fd 上启用 TLS（STARTTLS）
 *
 * @param fd 已连接的 socket 文件描述符
 * @param config TLS 配置
 * @return TLS socket
 */
public func startTLSWithFd(fd: Int32, config: TlsConfig): TlsSocket {
    let tlsSocket = TlsSocket(config)
    tlsSocket.connectWithFd(fd)
    tlsSocket
}
