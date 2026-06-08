#!/bin/bash
# RoboCup 2D 一键全装脚本
# Phase 0-5：依赖 + rcssserver + librcsc + helios-base 球队 + 监视器
# 用法: sudo bash 00_install_all.sh
# 用时: 30-50 分钟（取决于网速和 CPU）

set -euo pipefail

# 颜色
G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; N='\033[0m'
LOG=/tmp/robocup2d_install_$(date +%Y%m%d_%H%M%S).log
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# 可配置项（用于传承与迁移）
WORK_DIR="${ROBOCUP2D_WORK_DIR:-$USER_HOME/robocup2d}"
TEAM_NAME="${ROBOCUP2D_TEAM_NAME:-wxxychyzz}"
TEAM_DIR="${ROBOCUP2D_TEAM_DIR:-$USER_HOME/$TEAM_NAME}"
SETUP_VERSION="unknown"
if [ -f "$REPO_ROOT/VERSION" ]; then
    SETUP_VERSION="$(tr -d '\r\n' < "$REPO_ROOT/VERSION")"
fi

info "=========================================="
info "RoboCup 2D 一键安装开始"
info "用户: $ACTUAL_USER"
info "Home: $USER_HOME"
info "安装目录: $WORK_DIR"
info "球队目录: $TEAM_DIR"
info "脚本版本: $SETUP_VERSION"
info "日志: $LOG"
info "=========================================="

info "当前环境变量（可覆盖）:"
info "  ROBOCUP2D_WORK_DIR=${WORK_DIR}"
info "  ROBOCUP2D_TEAM_NAME=${TEAM_NAME}"
info "  ROBOCUP2D_TEAM_DIR=${TEAM_DIR}"
info ""

# Phase 1: 依赖
info "[1/5] 安装系统依赖..."
bash "$SCRIPT_DIR/01_install_deps.sh" 2>&1 | tee -a "$LOG" || error "依赖安装失败"

# 后续脚本以普通用户运行
sudo -u "$ACTUAL_USER" bash <<EOSU
set -e
export HOME="$USER_HOME"
export ROBOCUP2D_WORK_DIR="${WORK_DIR}"
export ROBOCUP2D_TEAM_NAME="${TEAM_NAME}"
export ROBOCUP2D_TEAM_DIR="${TEAM_DIR}"

cd "$HOME"
mkdir -p "$ROBOCUP2D_WORK_DIR"/{server,team,logs}

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
cp "$SCRIPT_DIR/06_run_match.sh" "$HOME/run_match.sh"
cp "$SCRIPT_DIR/07_test_match.sh" "$HOME/test_match.sh"
chmod +x "$HOME/run_match.sh" "$HOME/test_match.sh"

# 复制文档
mkdir -p "$HOME/robocup2d_setup/docs"
cp -r "$SCRIPT_DIR/../docs/"* "$HOME/robocup2d_setup/docs/" 2>/dev/null || true
cp "$SCRIPT_DIR/../README.md" "$HOME/robocup2d_setup/" 2>/dev/null || true
cp "$SCRIPT_DIR/../VERSION" "$HOME/robocup2d_setup/" 2>/dev/null || true
cp "$SCRIPT_DIR/../CHANGELOG.md" "$HOME/robocup2d_setup/" 2>/dev/null || true
EOSU

info "=========================================="
info "安装完成！"
info "=========================================="
info ""
info "测试命令："
info "  $TEAM_DIR/start.sh         # 启动球队"
info "  $TEAM_DIR/kill.sh          # 终止"
info "  $USER_HOME/run_match.sh    # 一键看比赛（弹出窗口）"
info ""
info "完整日志: $LOG"
