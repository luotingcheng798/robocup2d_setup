#!/bin/bash
# RoboCup 2D 一键全装脚本
# Phase 0-5：依赖 + rcssserver + librcsc + helios-base 球队 + 监视器
# 用法: sudo bash 00_install_all.sh
# 用时: 30-50 分钟（取决于网速和 CPU）

set -e

# 颜色
G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; N='\033[0m'
LOG=/tmp/robocup2d_install_$(date +%Y%m%d_%H%M%S).log
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "${G}[INFO]${N} $1" | tee -a "$LOG"; }
warn()  { echo -e "${Y}[WARN]${N} $1" | tee -a "$LOG"; }
error() { echo -e "${R}[ERROR]${N} $1" | tee -a "$LOG"; exit 1; }

# 检查 Ubuntu 24.04
if ! grep -q "Ubuntu 24" /etc/os-release; then
    error "本脚本仅支持 Ubuntu 24.04 LTS"
fi

# 检查 sudo
if [ "$EUID" -ne 0 ]; then
    error "请用 sudo 运行: sudo bash $0"
fi

# 用户主目录（脚本可能 sudo 运行）
USER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
ACTUAL_USER="${SUDO_USER:-$USER}"

info "=========================================="
info "RoboCup 2D 一键安装开始"
info "用户: $ACTUAL_USER"
info "Home: $USER_HOME"
info "日志: $LOG"
info "=========================================="

# Phase 1: 依赖
info "[1/5] 安装系统依赖..."
bash "$SCRIPT_DIR/01_install_deps.sh" 2>&1 | tee -a "$LOG" || error "依赖安装失败"

# 后续脚本以普通用户运行
sudo -u "$ACTUAL_USER" bash <<EOSU
set -e
export HOME="$USER_HOME"
cd "\$HOME"
mkdir -p robocup2d/{server,team,logs}

# Phase 2
echo "[2/5] 编译 rcssserver..."
bash "$SCRIPT_DIR/02_build_rcssserver.sh"

# Phase 3
echo "[3/5] 编译 librcsc..."
bash "$SCRIPT_DIR/03_build_librcsc.sh"

# Phase 4
echo "[4/5] 编译球队..."
bash "$SCRIPT_DIR/04_build_team.sh"

# Phase 5
echo "[5/5] 安装监视器..."
bash "$SCRIPT_DIR/05_install_monitor.sh"

# 安装一键启动脚本
cp "$SCRIPT_DIR/06_run_match.sh" "\$HOME/run_match.sh"
cp "$SCRIPT_DIR/07_test_match.sh" "\$HOME/test_match.sh"
chmod +x "\$HOME/run_match.sh" "\$HOME/test_match.sh"

# 复制文档
mkdir -p "\$HOME/robocup2d_setup/docs"
cp -r "$SCRIPT_DIR/../docs/"* "\$HOME/robocup2d_setup/docs/" 2>/dev/null || true
cp "$SCRIPT_DIR/../README.md" "\$HOME/robocup2d_setup/" 2>/dev/null || true

EOSU

info "=========================================="
info "安装完成！"
info "=========================================="
info ""
info "测试命令："
info "  $USER_HOME/wxxychyzz/start.sh         # 启动球队"
info "  $USER_HOME/wxxychyzz/kill.sh          # 终止"
info "  $USER_HOME/run_match.sh               # 一键看比赛（弹出窗口）"
info ""
info "完整日志: $LOG"
