#!/bin/bash
# 构建脚本 - 自动检测HiTLS库位置并编译

# 检测HiTLS库位置的优先级：
# 1. HITLS_LIB 环境变量
# 2. 用户本地安装 ~/.local/lib/hitls
# 3. 项目相对路径 ../../openhitls/build
# 4. 系统标准路径 /usr/local/lib

if [ -n "$HITLS_LIB" ]; then
    HITLS_PATH="$HITLS_LIB"
elif [ -d "$HOME/.local/lib/hitls" ]; then
    HITLS_PATH="$HOME/.local/lib/hitls"
elif [ -d "../../openhitls/build" ]; then
    HITLS_PATH="$(cd ../../openhitls/build && pwd)"
    BOUNDSCHECK_PATH="$(cd ../../openhitls/platform/Secure_C/lib && pwd)"
elif [ -d "/usr/local/lib" ] && [ -f "/usr/local/lib/libhitls_tls.so" ]; then
    HITLS_PATH="/usr/local/lib"
else
    echo "错误: 无法找到HiTLS库！"
    echo "请设置 HITLS_LIB 环境变量或将HiTLS安装到以下位置之一："
    echo "  - ~/.local/lib/hitls"
    echo "  - ../../openhitls/build (相对于demo目录)"
    echo "  - /usr/local/lib"
    exit 1
fi

echo "使用HiTLS库路径: $HITLS_PATH"

# 生成临时配置文件
cat > cjpm.toml.tmp << EOF
[package]
name = "mail_demo"
version = "0.1.0"
description = "Demo for Cangjie Mail library"
cjc-version = "1.0.4"
output-type = "executable"
c-arguments = ["-Woff", "unused"]

[dependencies]
mail = { path = ".." }

# openHiTLS FFI 配置 (由 build.sh 自动生成)
[ffi.c]
hitls_tls = { path = "$HITLS_PATH" }
hitls_crypto = { path = "$HITLS_PATH" }
hitls_bsl = { path = "$HITLS_PATH" }
hitls_pki = { path = "$HITLS_PATH" }
hitls_auth = { path = "$HITLS_PATH" }
boundscheck = { path = "${BOUNDSCHECK_PATH:-$HITLS_PATH}" }
EOF

# 备份原配置并使用临时配置
mv cjpm.toml cjpm.toml.bak
mv cjpm.toml.tmp cjpm.toml

# 编译
cjpm build
BUILD_RESULT=$?

# 恢复原配置
mv cjpm.toml.bak cjpm.toml

exit $BUILD_RESULT
