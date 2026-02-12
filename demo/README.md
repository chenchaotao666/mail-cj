# Mail Demo 使用说明

这是 Cangjie Mail 库的演示项目。

## 快速开始

### 编译

**推荐方式（自动检测HiTLS路径）：**
```bash
./build.sh
```

**或直接编译：**
```bash
cjpm build
```
> 注意：直接编译需要先配置 `cjpm.toml` 中的HiTLS路径为你的实际路径

### 运行

```bash
cjpm run
```

## HiTLS 依赖

如果还未安装openHiTLS，参考：https://gitee.com/opengauss/openHiTLS

推荐安装到 `~/.local/lib/hitls`，构建脚本会自动检测。
