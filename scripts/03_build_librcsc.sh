#!/bin/bash
# Phase 3: 编译安装 librcsc（含 GCC 13 兼容修复）

set -e

SRC_DIR="$HOME/robocup2d/team"
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

echo "[Phase 3/5] 克隆 librcsc..."
if [ ! -d "librcsc" ]; then
    git clone --depth=1 https://github.com/helios-base/librcsc.git
fi
cd librcsc

# ---- GCC 13 兼容性修复 ----
echo "[Phase 3/5] 应用 GCC 13 兼容性补丁..."

# 修复 1：host_address.h
if grep -q "^struct sockaddr_in;$" rcsc/net/host_address.h; then
    sed -i 's|^struct sockaddr_in;$|#include <netinet/in.h>|' rcsc/net/host_address.h
    echo "  ✓ rcsc/net/host_address.h 已修复"
fi

# 修复 2：相关 cpp 文件添加 arpa/inet.h
for f in rcsc/common/player_param.cpp src/rcg2txt.cpp rcsc/net/udp_socket.cpp; do
    if [ -f "$f" ] && ! grep -q "arpa/inet" "$f"; then
        # 在第一次出现 #include <netinet/in.h> 后插入
        python3 -c "
import re
with open('$f') as fp:
    content = fp.read()
content = re.sub(
    r'(#include <netinet/in\.h>)',
    r'\1\n#include <arpa/inet.h>',
    content, count=1)
with open('$f', 'w') as fp:
    fp.write(content)
"
        echo "  ✓ $f 已修复"
    fi
done

# 编译
mkdir -p build && cd build
echo "[Phase 3/5] 配置 cmake..."
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local

# 修复 3：config.h 中 HAVE_NETINET_IN_H
if [ -f config.h ] && grep -q "/\* #undef HAVE_NETINET_IN_H \*/" config.h; then
    sed -i 's|/\* #undef HAVE_NETINET_IN_H \*/|#define HAVE_NETINET_IN_H|' config.h
    echo "  ✓ config.h: HAVE_NETINET_IN_H 启用"
fi

echo "[Phase 3/5] 编译 librcsc（约 5-10 分钟）..."
make -j$(nproc)

echo "[Phase 3/5] 安装..."
sudo make install
sudo ldconfig

# 验证
ls /usr/local/lib/librcsc.so.19* | head -3
echo "[Phase 3/5] 完成"
