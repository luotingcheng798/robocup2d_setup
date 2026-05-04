#!/bin/bash
# 一键启动比赛 + 可视化监视器
# 用法:
#   ./run_match.sh                                  # 自对战（无对手）
#   ./run_match.sh -o /path/to/opponent_dir         # vs 指定对手
#   ./run_match.sh -o /path/to/opp -s start.sh      # 指定对手 start.sh 名

set -e

OPP_DIR=""
OPP_SCRIPT="start.sh"
NO_MONITOR=0

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--opponent) OPP_DIR="$2"; shift 2 ;;
        -s|--script)   OPP_SCRIPT="$2"; shift 2 ;;
        --no-monitor)  NO_MONITOR=1; shift ;;
        -h|--help)
            echo "用法: $0 [-o 对手目录] [-s 对手脚本名] [--no-monitor]"
            exit 0 ;;
        *) shift ;;
    esac
done

# 清理
killall -9 rcssserver wxxychyzz_Player wxxychyzz_Coach 2>/dev/null || true
killall -9 sample_player sample_coach 2>/dev/null || true
killall -9 rcssmonitor.AppImage 2>/dev/null || true
sleep 2
rm -f /tmp/incomplete.* /tmp/*.rcg /tmp/*.rcl /tmp/rcssserver.log /tmp/wxxy.log /tmp/opp.log

# 1. Server
echo "[1/4] 启动 rcssserver..."
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /tmp && rcssserver server::auto_mode=true > /tmp/rcssserver.log 2>&1 &

# 等 server 就绪
for i in {1..15}; do
    if grep -q "Waiting" /tmp/rcssserver.log 2>/dev/null; then break; fi
    sleep 1
done

# 2. Monitor
if [ "$NO_MONITOR" = "0" ]; then
    echo "[2/4] 启动监视器..."
    export DISPLAY=:0
    XAUTH_FILE=$(ls /run/user/$(id -u)/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
    if [ -n "$XAUTH_FILE" ]; then
        export XAUTHORITY="$XAUTH_FILE"
        ~/rcssmonitor.AppImage > /tmp/monitor.log 2>&1 &
        sleep 2
    else
        echo "  ⚠️ 未找到 X auth 文件，跳过监视器"
        echo "  请在桌面终端运行: ~/rcssmonitor.AppImage"
    fi
fi

# 3. wxxychyzz
echo "[3/4] 启动 wxxychyzz..."
~/wxxychyzz/start.sh > /tmp/wxxy.log 2>&1 &
sleep 8

# 4. 对手
if [ -n "$OPP_DIR" ] && [ -d "$OPP_DIR" ]; then
    if [ ! -f "$OPP_DIR/$OPP_SCRIPT" ]; then
        echo "  ⚠️ $OPP_DIR/$OPP_SCRIPT 不存在，自动查找..."
        for f in start.sh start_team.sh quick_start_left.sh; do
            for sub in "" "bin/" "HfutEngine-release/" "agent2d/src/"; do
                if [ -f "$OPP_DIR/$sub$f" ]; then
                    OPP_SCRIPT="$sub$f"
                    break 2
                fi
            done
        done
    fi
    echo "[4/4] 启动对手: $OPP_DIR/$OPP_SCRIPT"
    cd "$OPP_DIR" && bash "$OPP_SCRIPT" > /tmp/opp.log 2>&1 &
    sleep 5
else
    echo "[4/4] 无对手（仅 wxxychyzz 上场）"
fi

echo ""
echo "✅ 比赛已启动"
echo ""
echo "实时看比分:"
echo "  watch -n 5 'grep \"referee goal\" /tmp/incomplete.rcl 2>/dev/null | grep -v \"kick\\|catch\\|offside\" | tail -10'"
echo ""
echo "终止:"
echo "  ~/wxxychyzz/kill.sh && killall -9 rcssserver rcssmonitor.AppImage"
