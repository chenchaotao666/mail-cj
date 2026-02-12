/**
 * Cangjie Mail TLS 模块
 *
 * 本模块提供基于 openHiTLS 的 TLS/SSL 支持：
 * - TlsConfig TLS 配置
 * - TlsSocket TLS 加密套接字
 * - TlsSMTPTransport 支持 TLS 的 SMTP 传输
 * - FFI 绑定到 openHiTLS C 库
 *
 * 使用前需要：
 * 1. 安装 openHiTLS 库
 * 2. 在 cjpm.toml 中配置 FFI 链接
 */
package mail.tls
