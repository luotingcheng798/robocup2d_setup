#!/bin/bash
# Phase 2: 编译安装 rcssserver
# 普通用户运行（脚本内 sudo 提权安装）

set -euo pipefail

VERSION="${ROBOCUP2D_SERVER_VERSION:-19.0.0}"
WORK_DIR="${ROBOCUP2D_WORK_DIR:-$HOME/robocup2d}"
SERVER_DIR="${ROBOCUP2D_SERVER_DIR:-$WORK_DIR/server}"
INSTALL_PREFIX="${ROBOCUP2D_INSTALL_PREFIX:-/usr/local}"
CONF_FILE="${ROBOCUP2D_LD_CONF_FILE:-$INSTALL_PREFIX/etc/ld.so.conf.d/rcssserver.conf}"
SHARED_LIB_DIR="${INSTALL_PREFIX}/lib"

SRC_DIR="$SERVER_DIR"
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

ARCHIVE="rcssserver-${VERSION}.tar.gz"
EXTRACTED="rcssserver-${VERSION}"
URL="https://github.com/rcsoccersim/rcssserver/releases/download/rcssserver-${VERSION}/rcssserver-${VERSION}.tar.gz"

echo "[Phase 2/5] 下载 rcssserver-$VERSION ..."
if [ ! -f "$ARCHIVE" ]; then
    wget -q --show-progress "$URL"
fi

if [ ! -d "$EXTRACTED" ]; then
    tar xzf "$ARCHIVE"
fi

cd "$EXTRACTED"
mkdir -p build && cd build

echo "[Phase 2/5] 配置 cmake..."
cmake .. -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"

echo "[Phase 2/5] 编译（约 5-10 分钟）..."
make -j$(nproc)

echo "[Phase 2/5] 安装..."
sudo make install

# 配置共享库路径
if [ ! -d "$(dirname "$CONF_FILE")" ]; then
    mkdir -p "$(dirname "$CONF_FILE")"
fi
if ! grep -q "$SHARED_LIB_DIR" "$CONF_FILE" 2>/dev/null; then
    echo "$SHARED_LIB_DIR" | sudo tee "$CONF_FILE" > /dev/null
fi
sudo ldconfig

# 加 LD_LIBRARY_PATH 到 .bashrc（不重复添加）
if ! grep -q "LD_LIBRARY_PATH=$SHARED_LIB_DIR" ~/.bashrc; then
    echo "export LD_LIBRARY_PATH=$SHARED_LIB_DIR:\$LD_LIBRARY_PATH" >> ~/.bashrc
fi

# 验证
export LD_LIBRARY_PATH="$SHARED_LIB_DIR:$LD_LIBRARY_PATH"
VER=$(rcssserver server::help 2>&1 | head -1)
echo "[Phase 2/5] 完成: $VER"

# 生成默认 server.conf 并启用 auto_mode
rcssserver server::help > /dev/null 2>&1 || true
if [ -f ~/.rcssserver/server.conf ]; then
    sed -i 's/server::auto_mode = false/server::auto_mode = true/' ~/.rcssserver/server.conf
    echo "[Phase 2/5] auto_mode=true 已设置"
fi
