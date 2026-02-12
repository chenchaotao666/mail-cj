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
     */
    private func guessContentType(): String {
        let name = getName().toAsciiLower()

        // 图片类型
        if (name.endsWith(".jpg") || name.endsWith(".jpeg")) {
            return "image/jpeg"
        }
        if (name.endsWith(".png")) {
            return "image/png"
        }
        if (name.endsWith(".gif")) {
            return "image/gif"
        }
        if (name.endsWith(".bmp")) {
            return "image/bmp"
        }
        if (name.endsWith(".webp")) {
            return "image/webp"
        }
        if (name.endsWith(".svg")) {
            return "image/svg+xml"
        }
        if (name.endsWith(".ico")) {
            return "image/x-icon"
        }

        // 文档类型
        if (name.endsWith(".pdf")) {
            return "application/pdf"
        }
        if (name.endsWith(".doc")) {
            return "application/msword"
        }
        if (name.endsWith(".docx")) {
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        }
        if (name.endsWith(".xls")) {
            return "application/vnd.ms-excel"
        }
        if (name.endsWith(".xlsx")) {
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        }
        if (name.endsWith(".ppt")) {
            return "application/vnd.ms-powerpoint"
        }
        if (name.endsWith(".pptx")) {
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        }

        // 文本类型
        if (name.endsWith(".txt")) {
            return "text/plain"
        }
        if (name.endsWith(".html") || name.endsWith(".htm")) {
            return "text/html"
        }
        if (name.endsWith(".css")) {
            return "text/css"
        }
        if (name.endsWith(".js")) {
            return "application/javascript"
        }
        if (name.endsWith(".json")) {
            return "application/json"
        }
        if (name.endsWith(".xml")) {
            return "application/xml"
        }
        if (name.endsWith(".csv")) {
            return "text/csv"
        }

        // 压缩文件
        if (name.endsWith(".zip")) {
            return "application/zip"
        }
        if (name.endsWith(".tar")) {
            return "application/x-tar"
        }
        if (name.endsWith(".gz") || name.endsWith(".gzip")) {
            return "application/gzip"
        }
        if (name.endsWith(".rar")) {
            return "application/vnd.rar"
        }
        if (name.endsWith(".7z")) {
            return "application/x-7z-compressed"
        }

        // 音频类型
        if (name.endsWith(".mp3")) {
            return "audio/mpeg"
        }
        if (name.endsWith(".wav")) {
            return "audio/wav"
        }
        if (name.endsWith(".ogg")) {
            return "audio/ogg"
        }

        // 视频类型
        if (name.endsWith(".mp4")) {
            return "video/mp4"
        }
        if (name.endsWith(".avi")) {
            return "video/x-msvideo"
        }
        if (name.endsWith(".mkv")) {
            return "video/x-matroska"
        }
        if (name.endsWith(".webm")) {
            return "video/webm"
        }

        // 默认
        "application/octet-stream"
    }
}

/**
 * 读取文件全部内容为字节数组
 */
public func readFileBytes(path: String): Array<Byte> {
    File.readFrom(path)
}
