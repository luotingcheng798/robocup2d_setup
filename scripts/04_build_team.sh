#!/bin/bash
# Phase 4: 编译 helios-base 球队，重命名为目标队名并部署

set -euo pipefail

WORK_DIR="${ROBOCUP2D_WORK_DIR:-$HOME/robocup2d}"
SRC_DIR="${ROBOCUP2D_TEAM_SRC_DIR:-$WORK_DIR/team}"
TEAM_NAME="${ROBOCUP2D_TEAM_NAME:-wxxychyzz}"
DEPLOY_DIR="${ROBOCUP2D_TEAM_DIR:-$HOME/$TEAM_NAME}"
HELIOS_REPO="${ROBOCUP2D_HELIOS_REPO:-https://github.com/helios-base/helios-base.git}"
INSTALL_PREFIX="${ROBOCUP2D_INSTALL_PREFIX:-/usr/local}"
GIT_DEPTH="${ROBOCUP2D_GIT_DEPTH:-1}"

cd "$SRC_DIR"

echo "[Phase 4/5] 克隆/更新 helios-base..."
if [ ! -d "${TEAM_NAME}-src" ]; then
    git clone --depth="$GIT_DEPTH" "$HELIOS_REPO" "${TEAM_NAME}-src"
fi
cd "${TEAM_NAME}-src"

# 改队名
sed -i "s/HELIOS_base/${TEAM_NAME}/g" src/start.sh.in src/player.conf src/coach.conf 2>/dev/null || true

# 编译
mkdir -p build && cd build
echo "[Phase 4/5] 配置 cmake..."
cmake .. -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"

echo "[Phase 4/5] 编译球队（约 5-10 分钟）..."
make -j$(nproc)

# 部署
echo "[Phase 4/5] 部署到 $DEPLOY_DIR..."
mkdir -p "$DEPLOY_DIR"/{lib,data}

cp build/bin/sample_player "$DEPLOY_DIR/${TEAM_NAME}_Player"
cp build/bin/sample_coach "$DEPLOY_DIR/${TEAM_NAME}_Coach"
strip "$DEPLOY_DIR/${TEAM_NAME}_Player" "$DEPLOY_DIR/${TEAM_NAME}_Coach" 2>/dev/null || true

cp build/bin/player.conf "$DEPLOY_DIR/data/"
cp build/bin/coach.conf "$DEPLOY_DIR/data/"
cp -r build/bin/formations-dt "$DEPLOY_DIR/data/"
cp -r build/bin/formations-keeper "$DEPLOY_DIR/data/" 2>/dev/null || true
cp -r build/bin/formations-taker "$DEPLOY_DIR/data/" 2>/dev/null || true

# 捆绑 librcsc
if [ -f "$INSTALL_PREFIX/lib/librcsc.so.19" ]; then
    cp "$INSTALL_PREFIX/lib/librcsc.so.19" "$DEPLOY_DIR/lib/"
fi
if [ -f "$INSTALL_PREFIX/lib/librcsc.so.19.0.0" ]; then
    cp "$INSTALL_PREFIX/lib/librcsc.so.19.0.0" "$DEPLOY_DIR/lib/"
    cp "$INSTALL_PREFIX/lib/librcsc.so.19.0.0" "$DEPLOY_DIR/librcsc.so.19" 2>/dev/null || true
fi
if [ -f "$INSTALL_PREFIX/lib/librcsc.so.19" ] && [ ! -f "$DEPLOY_DIR/lib/librcsc.so.19" ]; then
    cp "$INSTALL_PREFIX/lib/librcsc.so.19" "$DEPLOY_DIR/librcsc.so.19"
fi

# 写 start.sh
cat > "$DEPLOY_DIR/start.sh" <<'STARTSH'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="${DIR}:${DIR}/lib:${LD_LIBRARY_PATH}"

team_name="${ROBOCUP2D_TEAM_NAME:-wxxychyzz}"
player="${DIR}/${team_name}_Player"
coach="${DIR}/${team_name}_Coach"
config="${DIR}/data/player.conf"
coach_config="${DIR}/data/coach.conf"
config_dir="${DIR}/data/formations-dt"

teamname="$team_name"
host="localhost"
port=6000
coach_port=6002
number=11
usecoach="true"

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--host)        host="$2"; shift 2 ;;
        -p|--port)        port="$2"; shift 2 ;;
        -P|--coach-port)  coach_port="$2"; shift 2 ;;
        -t|--teamname)    teamname="$2"; shift 2 ;;
        -n|--number)      number="$2"; shift 2 ;;
        -C|--without-coach) usecoach="false"; shift ;;
        *) shift ;;
    esac
done

opt="--player-config ${config} --config_dir ${config_dir} -h ${host} -p ${port} -t ${teamname}"
coachopt="--coach-config ${coach_config} --use_team_graphic off -h ${host} -p ${coach_port} -t ${teamname}"

cd "${DIR}"
"${player}" ${opt} -g &
sleep 0.4
i=2
while [ $i -le ${number} ]; do
    "${player}" ${opt} &
    sleep 0.25
    i=$((i + 1))
done
[ "${usecoach}" = "true" ] && "${coach}" ${coachopt} &

echo "[${teamname}] All ${number} players + coach launched."
STARTSH

# 写 kill.sh
cat > "$DEPLOY_DIR/kill.sh" <<'KILLSH'
#!/bin/bash
team_name="${ROBOCUP2D_TEAM_NAME:-wxxychyzz}"
echo "[${team_name}] Stopping..."
pkill -f "${team_name}_Player" 2>/dev/null
pkill -f "${team_name}_Coach" 2>/dev/null
sleep 1
pkill -9 -f "${team_name}_Player" 2>/dev/null
pkill -9 -f "${team_name}_Coach" 2>/dev/null
KILLSH

chmod +x "$DEPLOY_DIR/start.sh" "$DEPLOY_DIR/kill.sh"

echo "[Phase 4/5] 部署完成"
ls -lh "$DEPLOY_DIR/"

# 验证二进制可执行
LD_LIBRARY_PATH="$DEPLOY_DIR" "${DEPLOY_DIR}/${TEAM_NAME}_Player" --help 2>&1 | head -2
