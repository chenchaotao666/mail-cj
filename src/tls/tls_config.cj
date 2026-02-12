/**
 * TLS 配置类
 */
package mail.tls

/**
 * TLS 版本枚举
 */
public enum TlsVersion {
    | TLS_1_2
    | TLS_1_3
}

/**
 * TLS 验证模式枚举
 */
public enum TlsVerifyMode {
    | VERIFY_NONE        // 不验证对端证书
    | VERIFY_PEER        // 验证对端证书
    | VERIFY_REQUIRED    // 必须有对端证书
}

/**
 * TLS 配置
 *
 * 用于配置 TLS 连接参数
 */
public class TlsConfig {
    private var _configPtr: HitlsConfig = CPointer<Unit>()
    private var _version: TlsVersion = TLS_1_2
    private var _verifyMode: TlsVerifyMode = VERIFY_NONE
    private var _caCertPath: ?String = None
    private var _certPath: ?String = None
    private var _keyPath: ?String = None
    private var _initialized: Bool = false

    /**
     * 使用默认配置构造（TLS 1.2）
     */
    public init() {
        _version = TLS_1_2
    }

    /**
     * 使用指定版本构造
     */
    public init(version: TlsVersion) {
        _version = version
    }

    /**
     * 初始化配置
     * 必须在使用前调用
     */
    public func initialize(): Unit {
        if (_initialized) {
            return
        }

        unsafe {
            // 初始化 BSL 错误处理
            let errRet = BSL_ERR_Init()
            if (errRet != HITLS_SUCCESS) {
                throw TlsException("BSL_ERR_Init 失败", errRet)
            }

            // 初始化 BSL 全局环境
            let globalRet = BSL_GLOBAL_Init()
            if (globalRet != HITLS_SUCCESS) {
                throw TlsException("BSL_GLOBAL_Init 失败", globalRet)
            }

            // 使用 CRYPT_EAL_Init 初始化所有加密组件（包括随机数）
            let initRet = CRYPT_EAL_Init(CRYPT_EAL_INIT_ALL)
            if (initRet != HITLS_SUCCESS) {
                throw TlsException("CRYPT_EAL_Init 失败", initRet)
            }

            // 注册 TLS 加密和证书方法
            HITLS_CryptMethodInit()
            let certRet = HITLS_CertMethodInit()
            if (certRet != HITLS_SUCCESS) {
                throw TlsException("HITLS_CertMethodInit 失败", certRet)
            }

            // 创建配置
            _configPtr = match (_version) {
                case TLS_1_2 => HITLS_CFG_NewTLS12Config()
                case TLS_1_3 => HITLS_CFG_NewTLS13Config()
            }

            if (_configPtr.isNull()) {
                throw TlsException("创建 TLS 配置失败")
            }

            // 设置验证模式（客户端是否验证服务器证书）
            match (_verifyMode) {
                case VERIFY_NONE =>
                    // 不验证证书：启用 VerifyNone 支持，禁用 ClientVerify
                    HITLS_CFG_SetVerifyNoneSupport(_configPtr, true)
                    HITLS_CFG_SetClientVerifySupport(_configPtr, false)
                case VERIFY_PEER | VERIFY_REQUIRED =>
                    // 验证证书
                    HITLS_CFG_SetVerifyNoneSupport(_configPtr, false)
                    HITLS_CFG_SetClientVerifySupport(_configPtr, true)
            }
        }

        _initialized = true
    }

    /**
     * 设置 TLS 版本
     */
    public func setVersion(version: TlsVersion): TlsConfig {
        _version = version
        this
    }

    /**
     * 设置证书验证模式
     */
    public func setVerifyMode(mode: TlsVerifyMode): TlsConfig {
        _verifyMode = mode
        this
    }

    /**
     * 设置 CA 证书路径
     */
    public func setCACertPath(path: String): TlsConfig {
        _caCertPath = Some(path)
        this
    }

    /**
     * 设置客户端证书路径
     */
    public func setCertPath(path: String): TlsConfig {
        _certPath = Some(path)
        this
    }

    /**
     * 设置私钥路径
     */
    public func setKeyPath(path: String): TlsConfig {
        _keyPath = Some(path)
        this
    }

    /**
     * 加载 CA 证书（在 initialize 之后调用）
     * 用于验证服务器证书
     */
    public func loadCertificates(): Unit {
        if (!_initialized) {
            throw TlsException("配置未初始化，请先调用 initialize()")
        }

        // 如果是 VERIFY_NONE 模式，不需要加载证书
        match (_verifyMode) {
            case VERIFY_NONE => return
            case _ => ()
        }

        unsafe {
            // 加载 CA 证书文件
            match (_caCertPath) {
                case Some(path) =>
                    let pathCStr = stringToCString(path)
                    let caRet = HITLS_CFG_LoadVerifyFile(_configPtr, pathCStr)
                    freeCString(pathCStr)
                    if (caRet != HITLS_SUCCESS) {
                        throw TlsException("加载 CA 证书失败: ${path}", caRet)
                    }
                case None =>
                    // 尝试常见的 CA 证书路径
                    let defaultPaths = [
                        "/etc/ssl/certs/ca-certificates.crt",      // Debian/Ubuntu
                        "/etc/pki/tls/certs/ca-bundle.crt",        // RHEL/CentOS
                        "/etc/ssl/ca-bundle.pem",                   // OpenSUSE
                        "/etc/pki/tls/cacert.pem",                  // Fedora
                        "/etc/ssl/cert.pem"                         // macOS/FreeBSD
                    ]
                    var loaded = false
                    for (path in defaultPaths) {
                        let pathCStr = stringToCString(path)
                        let caRet = HITLS_CFG_LoadVerifyFile(_configPtr, pathCStr)
                        freeCString(pathCStr)
                        if (caRet == HITLS_SUCCESS) {
                            loaded = true
                            break
                        }
                    }
                    if (!loaded) {
                        // 尝试加载系统默认 CA 证书目录
                        let defaultRet = HITLS_CFG_LoadDefaultCAPath(_configPtr)
                        if (defaultRet == HITLS_SUCCESS) {
                            loaded = true
                        }
                    }
                    if (!loaded) {
                        throw TlsException("无法加载系统 CA 证书，请手动指定 CA 证书路径")
                    }
            }

            // 加载客户端证书（如果有）
            match (_certPath) {
                case Some(path) =>
                    let pathCStr = stringToCString(path)
                    let certRet = HITLS_CFG_LoadCertFile(_configPtr, pathCStr, TLS_PARSE_FORMAT_PEM)
                    freeCString(pathCStr)
                    if (certRet != HITLS_SUCCESS) {
                        throw TlsException("加载客户端证书失败: ${path}", certRet)
                    }
                case None => ()
            }

            // 加载客户端私钥（如果有）
            match (_keyPath) {
                case Some(path) =>
                    let pathCStr = stringToCString(path)
                    let keyRet = HITLS_CFG_LoadKeyFile(_configPtr, pathCStr, TLS_PARSE_FORMAT_PEM)
                    freeCString(pathCStr)
                    if (keyRet != HITLS_SUCCESS) {
                        throw TlsException("加载私钥失败: ${path}", keyRet)
                    }
                case None => ()
            }
        }
    }

    /**
     * 启用证书验证（便捷方法）
     */
    public func enableCertVerification(): TlsConfig {
        _verifyMode = VERIFY_PEER
        this
    }

    /**
     * 禁用证书验证（便捷方法）
     */
    public func disableCertVerification(): TlsConfig {
        _verifyMode = VERIFY_NONE
        this
    }

    /**
     * 获取底层配置指针
     */
    public func getConfigPtr(): HitlsConfig {
        if (!_initialized) {
            throw TlsException("配置未初始化，请先调用 initialize()")
        }
        _configPtr
    }

    /**
     * 释放资源
     */
    public func close(): Unit {
        if (_initialized) {
            unsafe {
                if (!_configPtr.isNull()) {
                    HITLS_CFG_FreeConfig(_configPtr)
                    _configPtr = CPointer<Unit>()
                }
            }
            _initialized = false
        }
    }

    /**
     * 是否已初始化
     */
    public func isInitialized(): Bool {
        _initialized
    }
}

/**
 * 创建默认的客户端配置（不验证服务器证书）
 */
public func createClientConfig(): TlsConfig {
    TlsConfig(TLS_1_2)
        .setVerifyMode(VERIFY_NONE)
}

/**
 * 创建安全的客户端配置（验证服务器证书）
 */
public func createSecureClientConfig(caCertPath: String): TlsConfig {
    TlsConfig(TLS_1_2)
        .setVerifyMode(VERIFY_PEER)
        .setCACertPath(caCertPath)
}
