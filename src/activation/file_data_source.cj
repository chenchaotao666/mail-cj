/**
 * 文件数据源实现
 */
package mail.activation

import std.io.*
import std.fs.*

/**
 * 文件数据源
 * 对应：jakarta.activation.FileDataSource
 */
public class FileDataSource <: DataSource {
    private var _path: String
    private var _contentType: ?String = None

    /**
     * 从文件路径构造
     */
    public init(path: String) {
        _path = path
    }


    /**
     * 获取输入流
     */
    public func getInputStream(): InputStream {
        File(_path, OpenMode.Read)
    }

    /**
     * 获取输出流
     */
    public func getOutputStream(): OutputStream {
        File(_path, OpenMode.Write)
    }

    /**
     * 获取内容类型
     */
    public func getContentType(): String {
        match (_contentType) {
            case Some(ct) => ct
            case None => guessContentType()
        }
    }

    /**
     * 设置内容类型
     */
    public func setContentType(contentType: String): Unit {
        _contentType = Some(contentType)
    }

    /**
     * 获取文件名
     */
    public func getName(): String {
        let parts = _path.split("/")
        if (parts.size > 0) {
            parts[parts.size - 1]
        } else {
            _path
        }
    }

    /**
     * 获取文件路径
     */
    public func getPath(): String {
        _path
    }

    /**
     * 根据文件扩展名猜测 MIME 类型
     * 使用 FileTypeMap 进行查找
     */
    private func guessContentType(): String {
        FileTypeMap.getDefaultFileTypeMap().getContentType(_path)
    }
}

/**
 * 读取文件全部内容为字节数组
 */
public func readFileBytes(path: String): Array<Byte> {
    File.readFrom(path)
}
