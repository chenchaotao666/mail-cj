/**
 * Cangjie Mail SMTP 模块
 *
 * 本模块包含 SMTP 协议实现：
 * - SMTPTransport（SMTP 协议通信）
 * - SMTP 特定异常
 */
package mail.smtp

import mail.core.{Session, Transport}

/**
 * 创建 SMTP 传输工厂
 */
func createSMTPTransport(session: Session, isSSL: Bool): Transport {
    SMTPTransport(session, isSSL)
}

/**
 * 初始化 SMTP 模块 - 注册传输工厂
 */
public func initSMTPModule(): Unit {
    Session.registerTransportFactory(createSMTPTransport)
}
