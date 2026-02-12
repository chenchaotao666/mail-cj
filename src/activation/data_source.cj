/**
 * 数据源接口和实现
 */
package mail.activation

import std.io.*

/**
 * 数据源接口
 * 对应：jakarta.activation.DataSource
 */
public interface DataSource {
    /**
     * 获取用于读取数据的输入流
     */
    func getInputStream(): InputStream

    /**
     * 获取用于写入数据的输出流
     */
    func getOutputStream(): OutputStream

    /**
     * 获取 MIME 内容类型
     */
    func getContentType(): String

    /**
     * 获取名称（通常是文件名）
     */
    func getName(): String
}
