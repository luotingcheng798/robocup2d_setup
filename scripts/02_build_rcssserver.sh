#!/bin/bash
# Phase 2: 编译安装 rcssserver-19.0.0
# 普通用户运行（脚本内 sudo 提权安装）

set -e

VERSION="19.0.0"
SRC_DIR="$HOME/robocup2d/server"
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

echo "[Phase 2/5] 下载 rcssserver-$VERSION ..."
if [ ! -f "rcssserver-${VERSION}.tar.gz" ]; then
    wget -q --show-progress \
        "https://github.com/rcsoccersim/rcssserver/releases/download/rcssserver-${VERSION}/rcssserver-${VERSION}.tar.gz"
fi

if [ ! -d "rcssserver-${VERSION}" ]; then
    tar xzf "rcssserver-${VERSION}.tar.gz"
fi

cd "rcssserver-${VERSION}"
mkdir -p build && cd build

echo "[Phase 2/5] 配置 cmake..."
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local

echo "[Phase 2/5] 编译（约 5-10 分钟）..."
make -j$(nproc)

echo "[Phase 2/5] 安装..."
sudo make install

# 配置共享库路径
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/rcssserver.conf > /dev/null
sudo ldconfig

# 加 LD_LIBRARY_PATH 到 .bashrc（不重复添加）
if ! grep -q "LD_LIBRARY_PATH=/usr/local/lib" ~/.bashrc; then
    echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
fi

# 验证
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
VER=$(rcssserver server::help 2>&1 | head -1)
echo "[Phase 2/5] 完成: $VER"

# 生成默认 server.conf 并启用 auto_mode
rcssserver server::help > /dev/null 2>&1 || true
if [ -f ~/.rcssserver/server.conf ]; then
    sed -i 's/server::auto_mode = false/server::auto_mode = true/' ~/.rcssserver/server.conf
    echo "[Phase 2/5] auto_mode=true 已设置"
fi
