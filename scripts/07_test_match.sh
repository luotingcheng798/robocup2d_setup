#!/bin/bash
# 单场无界面测试（用于批量评估胜率）
# 用法: ./test_match.sh <opp_dir> [timeout_sec]
# 输出: "对手 wxxy:N opp:M cycle:C status:OK"

OPP_DIR="${1:?用法: $0 <opp_dir> [timeout_sec]}"
TIMEOUT="${2:-600}"

OPP_NAME=$(basename "$OPP_DIR")
OPP_SCRIPT=""
for f in start.sh start_team.sh quick_start_left.sh; do
    for sub in "" "bin/" "HfutEngine-release/" "agent2d/src/" \
               "Miracle2D_1_Day1/" "Miracle2D_2_Day1/" \
               "robocup-cyrus2d-binary_1.0.1_20250524_141653/bin/"; do
        if [ -f "$OPP_DIR/$sub$f" ]; then
            OPP_SCRIPT="$sub$f"
            break 2
        fi
    done
done

if [ -z "$OPP_SCRIPT" ]; then
    echo "$OPP_NAME wxxy:0 opp:0 cycle:0 status:NO_SCRIPT"
    exit 1
fi

# 清理
killall -9 rcssserver wxxychyzz_Player wxxychyzz_Coach 2>/dev/null
killall -9 sample_player sample_coach 2>/dev/null
for prog in masxy_player masxy_Coach AHUTI_Player AHUTI_Coach \
            MT_Player MT_Coach HfutEngine_Player HfutEngine_Coach \
            Miracle_Player Miracle_Coach; do
    killall -9 "$prog" 2>/dev/null
done
sleep 2
rm -f /tmp/incomplete.* /tmp/*.rcg /tmp/*.rcl /tmp/rcssserver.log /tmp/wxxy.log /tmp/opp.log

export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Server
cd /tmp && rcssserver server::auto_mode=true > /tmp/rcssserver.log 2>&1 &

for i in {1..20}; do
    grep -q "Waiting" /tmp/rcssserver.log 2>/dev/null && break
    sleep 0.5
done

# wxxychyzz 先连
~/wxxychyzz/start.sh > /tmp/wxxy.log 2>&1 &
sleep 8

# 对手
cd "$OPP_DIR" && bash "$OPP_SCRIPT" > /tmp/opp.log 2>&1 &
sleep 10

# 等比赛结束
START=$(date +%s)
LAST_CYCLE=0
LAST_CHANGE=$START
while pgrep -f rcssserver > /dev/null; do
    NOW=$(date +%s)
    [ $((NOW - START)) -gt $TIMEOUT ] && break
    CUR=$(awk -F',' '{print $1}' /tmp/incomplete.rcl 2>/dev/null | sort -un | tail -1)
    [ -z "$CUR" ] && CUR=0
    if [ "$CUR" != "$LAST_CYCLE" ]; then
        LAST_CYCLE=$CUR; LAST_CHANGE=$NOW
    elif [ $((NOW - LAST_CHANGE)) -gt 30 ]; then
        break
    fi
    sleep 5
done

WXXY_GOALS=$(grep -cE "referee goal_l_" /tmp/incomplete.rcl 2>/dev/null)
[ -z "$WXXY_GOALS" ] && WXXY_GOALS=0
OPP_GOALS=$(grep -cE "referee goal_r_" /tmp/incomplete.rcl 2>/dev/null)
[ -z "$OPP_GOALS" ] && OPP_GOALS=0

# 清理
killall -9 rcssserver wxxychyzz_Player wxxychyzz_Coach 2>/dev/null
sleep 2

echo "$OPP_NAME wxxy:$WXXY_GOALS opp:$OPP_GOALS cycle:$LAST_CYCLE status:OK"
