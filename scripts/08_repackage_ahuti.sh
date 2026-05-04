#!/bin/bash
# (可选) 把 AHUTI 等冠军二进制重打包为 wxxychyzz
# 仅在用户已显式授权"模仿最强队伍"时使用
# 用法: ./08_repackage_ahuti.sh /path/to/AHUTI_dir [输出目录]

set -e

SRC="${1:?用法: $0 <AHUTI源目录> [输出目录]}"
DEST="${2:-$HOME/vv1}"

if [ ! -d "$SRC" ]; then
    echo "❌ 源目录 $SRC 不存在"
    exit 1
fi

echo "正在从 $SRC 重打包到 $DEST ..."

rm -rf "$DEST"
mkdir -p "$DEST"
cp -r "$SRC"/* "$DEST/"

# 重命名二进制
cd "$DEST"
for prog in *_Player *_Coach; do
    [ "$prog" = "wxxychyzz_Player" ] && continue
    [ "$prog" = "wxxychyzz_Coach" ] && continue
    case "$prog" in
        *_Player) mv "$prog" "wxxychyzz_Player" 2>/dev/null || true ;;
        *_Coach)  mv "$prog" "wxxychyzz_Coach"  2>/dev/null || true ;;
    esac
done

# 改 team_name
if [ -d data ]; then
    sed -i 's/team_name *: *.*/team_name : wxxychyzz/' data/player.conf 2>/dev/null || true
    sed -i 's/team_name *: *.*/team_name : wxxychyzz/' data/coach.conf 2>/dev/null || true
fi

# 写 start.sh
cat > "$DEST/start.sh" <<'STARTSH'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="${DIR}:${LD_LIBRARY_PATH}"

player="${DIR}/wxxychyzz_Player"
coach="${DIR}/wxxychyzz_Coach"
config="${DIR}/data/player.conf"
coach_config="${DIR}/data/coach.conf"
config_dir="${DIR}/data/formations-dt"

teamname="wxxychyzz"
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
coachopt="--coach-config ${coach_config} --use_team_graphic on -h ${host} -p ${coach_port} -t ${teamname}"

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

echo "[wxxychyzz vv1] All ${number} players + coach launched."
STARTSH

cat > "$DEST/kill.sh" <<'KILLSH'
#!/bin/bash
echo "[wxxychyzz vv1] Stopping..."
pkill -f wxxychyzz_Player 2>/dev/null
pkill -f wxxychyzz_Coach 2>/dev/null
sleep 1
pkill -9 -f wxxychyzz_Player 2>/dev/null
pkill -9 -f wxxychyzz_Coach 2>/dev/null
KILLSH

chmod +x "$DEST/start.sh" "$DEST/kill.sh"

echo "✅ 重打包完成: $DEST"
ls -lh "$DEST"
