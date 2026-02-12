# Mail Demo 使用说明

这是 Cangjie Mail 库的演示项目。

## 编译方法

### 方法1：使用构建脚本（推荐，跨平台）

```bash
./build.sh
```

**优点：**
- 自动检测HiTLS库位置，无需修改配置文件
- 支持多个可能的安装路径
- 其他开发者可以直接使用

构建脚本会按以下优先级查找HiTLS库：
1. `$HITLS_LIB` 环境变量
2. `~/.local/lib/hitls` (用户本地安装)
3. `../../openhitls/build` (项目相对路径)
4. `/usr/local/lib` (系统标准路径)

如果你的HiTLS在其他位置：
```bash
export HITLS_LIB=/path/to/your/hitls/lib
./build.sh
```

### 方法2：直接使用 cjpm build

如果你的HiTLS已安装到标准位置（如 `~/.local/lib/hitls`），可以直接编译：

```bash
cjpm build
```

**注意：** 如果HiTLS不在默认位置，需要修改 `cjpm.toml` 中的路径：

```toml
[ffi.c]
hitls_tls = { path = "/your/absolute/path/to/hitls" }
hitls_crypto = { path = "/your/absolute/path/to/hitls" }
# ... 其他库配置
```

**重要：** cjpm不支持 `~` 符号，必须使用绝对路径（如 `/home/username/.local/lib/hitls`）。

## 运行

编译成功后，可执行文件位于：
```bash
./target/release/bin/main
```

## HiTLS 安装

如果还没有安装 openHiTLS，请参考：
https://gitee.com/opengauss/openHiTLS

推荐安装到 `~/.local/lib/hitls` 目录，这样构建脚本可以自动检测到。

## 配置文件说明

- `cjpm.toml` - 当前配置文件（包含本机路径）
- `cjpm.toml.example` - 配置模板（供其他开发者参考）

如果要分享代码给其他人，建议使用 `build.sh` 脚本，避免路径配置问题。
