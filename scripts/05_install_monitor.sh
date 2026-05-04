#!/bin/bash
# Phase 5: 安装 rcssmonitor 可视化（AppImage 方式）

set -e

echo "[Phase 5/5] 下载 rcssmonitor AppImage..."
cd "$HOME"

if [ ! -f rcssmonitor.AppImage ]; then
    wget -q --show-progress \
        https://github.com/rcsoccersim/rcssmonitor/releases/download/rcssmonitor-19.0.1/rcssmonitor-19.0.1-x86_64.AppImage \
        -O rcssmonitor.AppImage
fi
chmod +x rcssmonitor.AppImage

echo "[Phase 5/5] 验证..."
~/rcssmonitor.AppImage --version 2>&1 | head -2

echo "[Phase 5/5] 完成"
echo "提示：需要图形界面才能弹出窗口"
echo "  在桌面终端: ~/rcssmonitor.AppImage"
echo "  在 SSH 终端: DISPLAY=:0 XAUTHORITY=\$(ls /run/user/\$(id -u)/.mutter-Xwayland*) ~/rcssmonitor.AppImage"
