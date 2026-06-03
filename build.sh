#!/bin/bash
# 构建脚本 - 自动检测 openHiTLS 库路径并构建库
#
# 用法：
#   ./build.sh
#   HITLS_LIB=/custom/path ./build.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 检测 HiTLS 库路径 ──────────────────────────────────────────────────────
if [ -n "$HITLS_LIB" ]; then
    HITLS_PATH="$HITLS_LIB"
elif [ -d "$HOME/.local/lib/hitls" ]; then
    HITLS_PATH="$HOME/.local/lib/hitls"
elif [ -d "$SCRIPT_DIR/../openhitls/build" ]; then
    HITLS_PATH="$(cd "$SCRIPT_DIR/../openhitls/build" && pwd)"
    BOUNDSCHECK_PATH="$(cd "$SCRIPT_DIR/../openhitls/platform/Secure_C/lib" && pwd)"
elif [ -f "/usr/local/lib/libhitls_tls.so" ]; then
    HITLS_PATH="/usr/local/lib"
else
    echo "错误: 未找到 HiTLS 库！"
    echo "请通过以下任一方式指定："
    echo "  export HITLS_LIB=/path/to/hitls/lib"
    echo "  或将 HiTLS 安装到 ~/.local/lib/hitls"
    exit 1
fi
BOUNDSCHECK_PATH="${BOUNDSCHECK_PATH:-$HITLS_PATH}"

echo "HiTLS 路径: $HITLS_PATH"

# ── 更新 cjpm.toml ─────────────────────────────────────────────────────────
cat > "$SCRIPT_DIR/cjpm.toml" << EOF
[package]
name = "mail"
version = "0.1.0"
description = "Cangjie Mail - SMTP email sending library for Cangjie language"
cjc-version = "1.0.4"
output-type = "static"

[dependencies]

# openHiTLS FFI 配置 (由 build.sh 自动生成)
[ffi.c]
hitls_tls    = { path = "$HITLS_PATH" }
hitls_crypto = { path = "$HITLS_PATH" }
hitls_bsl    = { path = "$HITLS_PATH" }
hitls_pki    = { path = "$HITLS_PATH" }
hitls_auth   = { path = "$HITLS_PATH" }
boundscheck  = { path = "$BOUNDSCHECK_PATH" }
EOF

# ── 构建 ───────────────────────────────────────────────────────────────────
cd "$SCRIPT_DIR"
cjpm build
echo "构建完成。"
