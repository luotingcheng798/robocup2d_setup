#!/bin/bash
# Phase 5: 安装 rcssmonitor 可视化（AppImage 方式）

set -euo pipefail

MONITOR_VERSION="${ROBOCUP2D_MONITOR_VERSION:-19.0.1}"
INSTALL_DIR="${HOME}"
MONITOR_APP="${ROBOCUP2D_MONITOR_APP:-$INSTALL_DIR/rcssmonitor.AppImage}"

echo "[Phase 5/5] 下载 rcssmonitor AppImage..."
cd "$INSTALL_DIR"

if [ ! -f "$MONITOR_APP" ]; then
    wget -q --show-progress \
        "https://github.com/rcsoccersim/rcssmonitor/releases/download/rcssmonitor-${MONITOR_VERSION}/rcssmonitor-${MONITOR_VERSION}-x86_64.AppImage" \
        -O "$MONITOR_APP"
fi
chmod +x "$MONITOR_APP"

echo "[Phase 5/5] 验证..."
"$MONITOR_APP" --version 2>&1 | head -2

echo "[Phase 5/5] 完成"
echo "提示：需要图形界面才能弹出窗口"
echo "  在桌面终端: $MONITOR_APP"
echo "  在 SSH 终端: DISPLAY=:0 XAUTHORITY=\$(ls /run/user/\$(id -u)/.mutter-Xwayland*) $MONITOR_APP"
