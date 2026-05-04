# RoboCup 2D 仿真足球队 — 从 0 到 1 完整指南

> 在 Ubuntu 24.04 LTS x86_64 上从零搭建参赛队伍 wxxychyzz，含训练 + 可视化。

## 目录
- [Phase 0：系统环境准备](#phase-0系统环境准备5-10-分钟)
- [Phase 1：编译安装 rcssserver](#phase-1编译安装-rcssserver10-15-分钟)
- [Phase 2：编译安装 librcsc](#phase-2编译安装-librcsc10-15-分钟)
- [Phase 3：编译参赛球队](#phase-3编译参赛球队15-30-分钟)
- [Phase 4：安装可视化监视器](#phase-4安装可视化监视器2-分钟)
- [Phase 5：第一场比赛](#phase-5第一场比赛立即)
- [Phase 6：批量对战测试](#phase-6批量对战测试可选)
- [Phase 7：球队提升训练](#phase-7球队提升训练可选-1-2-周)
- [Phase 8：参赛打包提交](#phase-8参赛打包提交)

---

## Phase 0：系统环境准备（5-10 分钟）

### 0.1 检查系统

```bash
uname -a                 # Linux x86_64
lsb_release -a           # Ubuntu 24.04
free -m                  # 内存 ≥ 4GB
df -h /                  # 磁盘 ≥ 10GB 可用
```

### 0.2 安装编译工具和库

```bash
sudo apt update && sudo apt upgrade -y

# 编译工具链
sudo apt install -y gcc g++ make cmake git wget curl \
    autoconf automake libtool pkg-config

# 构建依赖
sudo apt install -y libboost-all-dev flex bison libfl-dev \
    zlib1g-dev libssl-dev libxt-dev libxrender-dev \
    libfontconfig1-dev libfreetype6-dev libjpeg-dev \
    libpng-dev libtiff-dev qtbase5-dev qt5-qmake \
    qtbase5-dev-tools libeigen3-dev

# 验证
gcc --version              # 应 13.x+
cmake --version            # 应 3.28+
```

### 0.3 创建项目目录

```bash
mkdir -p ~/robocup2d/{server,team,logs}
cd ~/robocup2d
```

---

## Phase 1：编译安装 rcssserver（10-15 分钟）

```bash
cd ~/robocup2d/server

# 下载 19.0.0
wget https://github.com/rcsoccersim/rcssserver/releases/download/rcssserver-19.0.0/rcssserver-19.0.0.tar.gz
tar xzf rcssserver-19.0.0.tar.gz
cd rcssserver-19.0.0

# 编译
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
sudo make install

# 配置共享库路径
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/rcssserver.conf
sudo ldconfig

# 加 LD_LIBRARY_PATH 到 shell 启动文件
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# 验证
LD_LIBRARY_PATH=/usr/local/lib rcssserver server::help 2>&1 | head -3
# 应输出 "rcssserver-19.0.0 ..."
```

---

## Phase 2：编译安装 librcsc（10-15 分钟）

```bash
cd ~/robocup2d/team
git clone --depth=1 https://github.com/helios-base/librcsc.git
cd librcsc

# Ubuntu 24.04 / GCC 13 兼容性修复
# 修复 1：host_address.h 添加 netinet/in.h 包含
sed -i 's|^struct sockaddr_in;|#include <netinet/in.h>|' rcsc/net/host_address.h

# 编译
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
# 如果遇到 ntohl/htonl 错误：
# sed -i '/#ifdef HAVE_NETINET_IN_H/a\#include <arpa/inet.h>' \
#     ../rcsc/common/player_param.cpp ../src/rcg2txt.cpp ../rcsc/net/udp_socket.cpp
# 修复 config.h:
# sed -i 's|/\* #undef HAVE_NETINET_IN_H \*/|#define HAVE_NETINET_IN_H|' config.h
# 再 make -j$(nproc)

sudo make install
sudo ldconfig

# 验证
ls /usr/local/lib/librcsc.so.19*
ls /usr/local/include/rcsc/
```

---

## Phase 3：编译参赛球队（15-30 分钟）

### 选项 A：自建 helios-base + 创新（推荐用于训练基础）

```bash
cd ~/robocup2d/team
git clone --depth=1 https://github.com/helios-base/helios-base.git wxxychyzz-src
cd wxxychyzz-src

# 改队名
sed -i 's/HELIOS_base/wxxychyzz/g' src/start.sh.in src/player.conf src/coach.conf

# (可选)添加创新：比分感知策略
# 编辑 src/player/strategy.cpp::updateSituation()，加入 score_diff 触发的阈值切换
# 详见 ~/wxxychyzz_versions/v1_src 里的修改

mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)

# 部署
mkdir -p ~/wxxychyzz/{lib,data}
cp build/bin/sample_player ~/wxxychyzz/wxxychyzz_Player
cp build/bin/sample_coach ~/wxxychyzz/wxxychyzz_Coach
strip ~/wxxychyzz/wxxychyzz_*
cp build/bin/player.conf build/bin/coach.conf ~/wxxychyzz/data/
cp -r build/bin/formations-dt ~/wxxychyzz/data/
cp -r build/bin/formations-keeper ~/wxxychyzz/data/
cp -r build/bin/formations-taker ~/wxxychyzz/data/
cp /usr/local/lib/librcsc.so.19 ~/wxxychyzz/lib/
cp /usr/local/lib/librcsc.so.19 ~/wxxychyzz/librcsc.so.19
```

### 选项 B：基于现有冠军重打包（最快上手 = 当前的 vv1）

```bash
# 假设你有 AHUTI 等顶尖队伍二进制
mkdir -p ~/vv1
cp -r "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI/"* ~/vv1/
mv ~/vv1/AHUTI_Player ~/vv1/wxxychyzz_Player
mv ~/vv1/AHUTI_Coach ~/vv1/wxxychyzz_Coach
sed -i 's/AHUTI/wxxychyzz/g' ~/vv1/data/player.conf ~/vv1/data/coach.conf
sed -i 's/team_name : YuShan/team_name : wxxychyzz/g' ~/vv1/data/player.conf ~/vv1/data/coach.conf
# 然后写 start.sh / kill.sh（见下文）
```

### 3.1 写 start.sh（11 球员 + 教练，<3 秒上场）

```bash
cat > ~/wxxychyzz/start.sh <<'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="${DIR}:${DIR}/lib:${LD_LIBRARY_PATH}"

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
        -h|--host) host="$2"; shift 2 ;;
        -p|--port) port="$2"; shift 2 ;;
        -t|--teamname) teamname="$2"; shift 2 ;;
        *) shift ;;
    esac
done

opt="--player-config $config --config_dir $config_dir -h $host -p $port -t $teamname"
coachopt="--coach-config $coach_config --use_team_graphic off -h $host -p $coach_port -t $teamname"

cd "${DIR}"
"$player" $opt -g &        # 1号 = 守门员
sleep 0.4
i=2
while [ $i -le $number ]; do
    "$player" $opt &
    sleep 0.25
    i=$((i + 1))
done
[ "$usecoach" = "true" ] && "$coach" $coachopt &
EOF
```

### 3.2 写 kill.sh

```bash
cat > ~/wxxychyzz/kill.sh <<'EOF'
#!/bin/bash
pkill -f wxxychyzz_Player 2>/dev/null
pkill -f wxxychyzz_Coach 2>/dev/null
sleep 1
pkill -9 -f wxxychyzz_Player 2>/dev/null
pkill -9 -f wxxychyzz_Coach 2>/dev/null
EOF

chmod +x ~/wxxychyzz/start.sh ~/wxxychyzz/kill.sh
```

---

## Phase 4：安装可视化监视器（2 分钟）

```bash
# AppImage 版本最方便
cd ~
wget https://github.com/rcsoccersim/rcssmonitor/releases/download/rcssmonitor-19.0.1/rcssmonitor-19.0.1-x86_64.AppImage -O rcssmonitor.AppImage
chmod +x ~/rcssmonitor.AppImage

# 安装 FUSE 依赖
sudo apt install -y libfuse2t64 fuse

# 验证
~/rcssmonitor.AppImage --version
# 应输出 "rcssmonitor-19.0.1"
```

### 4.1 创建一键启动看比赛脚本

```bash
cat > ~/watch_match.sh <<'EOF'
#!/bin/bash
# 一键启动 wxxychyzz vs 对手 + 监视器
OPP="${1:-AHUTI}"
OPP_BASE="/home/ltc/2025可执行二进制/可执行二进制/5.24"
OPP_DIR="$OPP_BASE/$OPP"

# 清理
killall -9 rcssserver wxxychyzz_Player wxxychyzz_Coach 2>/dev/null
killall -9 sample_player sample_coach AHUTI_Player AHUTI_Coach 2>/dev/null
killall -9 masxy_player MT_Player HfutEngine_Player 2>/dev/null
killall -9 rcssmonitor.AppImage 2>/dev/null
sleep 2
rm -f /tmp/incomplete.* /tmp/*.rcg /tmp/*.rcl /tmp/rcssserver.log

# 1. Server
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /tmp && rcssserver server::auto_mode=true > /tmp/rcssserver.log 2>&1 &
until grep -q "Waiting" /tmp/rcssserver.log 2>/dev/null; do sleep 1; done

# 2. Monitor (X display setup)
export DISPLAY=:0
export XAUTHORITY=$(ls /run/user/$(id -u)/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
~/rcssmonitor.AppImage > /tmp/monitor.log 2>&1 &
sleep 2

# 3. wxxychyzz
~/wxxychyzz/start.sh > /tmp/wxxy.log 2>&1 &
sleep 8

# 4. Opponent
[ -d "$OPP_DIR" ] && cd "$OPP_DIR" && bash start.sh > /tmp/opp.log 2>&1 &

echo "✅ 比赛开始：wxxychyzz vs $OPP"
echo "看 rcssmonitor 窗口！终止: ~/wxxychyzz/kill.sh && killall -9 rcssserver rcssmonitor.AppImage"
EOF

chmod +x ~/watch_match.sh
```

---

## Phase 5：第一场比赛（立即）

### 5.1 一键启动（推荐）

```bash
# 默认对战 AHUTI
~/watch_match.sh

# 或指定对手
~/watch_match.sh MASXY1
~/watch_match.sh xinhua_rocket
```

桌面上会弹出**绿色足球场窗口**（rcssmonitor），看到 22 名球员对战。

### 5.2 手动启动（理解原理）

打开 **3 个终端**：

```bash
# 终端 1: Server
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /tmp && rcssserver server::auto_mode=true

# 终端 2: 监视器（图形化看球场）
~/rcssmonitor.AppImage

# 终端 3: 启动 wxxychyzz
~/wxxychyzz/start.sh

# 终端 4（可选）: 对手
cd "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" && bash start.sh
```

### 5.3 实时看比分（无监视器）

```bash
watch -n 5 'grep "referee goal" /tmp/incomplete.rcl 2>/dev/null | grep -v "kick\|catch\|offside" | tail -10; echo "Cycle: $(awk -F\, "{print \$1}" /tmp/incomplete.rcl 2>/dev/null | sort -un | tail -1)"'
```

### 5.4 比赛结束后

```bash
# 最终比分
grep "Score:" /tmp/rcssserver.log | tail -1

# 进球时间线
grep -E "referee goal_l|referee goal_r" /tmp/incomplete.rcl | grep -v "kick\|catch\|offside"

# log 文件保存（可用 rcssmonitor 重放）
ls -lh /tmp/*.rcg /tmp/*.rcl
```

### 5.5 终止

```bash
~/wxxychyzz/kill.sh
killall -9 rcssserver rcssmonitor.AppImage
```

---

## Phase 6：批量对战测试（可选）

### 6.1 单场测试

```bash
~/wxxychyzz_versions/test_one.sh ~/wxxychyzz \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/MASXY1" 600
# 输出: "MASXY1 wxxy:N opp:M cycle:C status:OK"
```

### 6.2 批量对战所有对手

```bash
# 编写批量脚本（详见 USAGE.md 第 4 节）
~/batch_test_vv1.sh ~/wxxychyzz | tee ~/results.log

# 跑完约 3-4 小时，输出胜率表
```

### 6.3 多场重复取均值

```bash
~/repeated_test.sh ~/wxxychyzz \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 5
# 输出: "胜 X | 平 Y | 负 Z（5 场）"
```

---

## Phase 7：球队提升训练（可选，1-2 周）

> **目标**：从当前 vv1（AHUTI 同级）真正"超越 AHUTI"

### 7.1 训练前准备

```bash
# Python ML 环境
pip3 install --upgrade pip
pip3 install torch torchvision tensorflow keras numpy scipy h5py \
    matplotlib pandas stable-baselines3 ray[rllib] gymnasium pettingzoo

# 验证 GPU
nvidia-smi
python3 -c "import torch; print('CUDA:', torch.cuda.is_available())"

# 训练数据目录
mkdir -p ~/training_data/{matches,extracted,models,logs}
```

### 7.2 路径 A：Pass Prediction DNN（推荐，1-2 周 / 1 GPU）

#### Step 1: 收集自对战数据（25 小时）

```bash
# 准备 Cyrus2D 的 DataExtractor
cd ~/robocup2d/team
wget https://github.com/Cyrus2D/Agent2D-DataExtractor/archive/refs/heads/master.tar.gz \
    -O agent2d-de.tar.gz
tar xzf agent2d-de.tar.gz
cd Agent2D-DataExtractor-master
mkdir build && cd build && cmake .. && make -j$(nproc)

# 自对战脚本（vv1 vs vv1）
cat > ~/collect_data.sh <<'EOF'
#!/bin/bash
N="${1:-3000}"
for i in $(seq 1 $N); do
    killall -9 rcssserver wxxychyzz_Player wxxychyzz_Coach 2>/dev/null
    sleep 2
    rm -f /tmp/incomplete.*
    rcssserver server::auto_mode=true server::synch_mode=true \
        server::nr_normal_halfs=1 > /dev/null 2>&1 &
    sleep 3
    ~/wxxychyzz/start.sh > /dev/null 2>&1 &
    sleep 2
    ~/wxxychyzz/start.sh -t wxxy_R > /dev/null 2>&1 &
    while pgrep -f rcssserver > /dev/null; do sleep 5; done
    cp /tmp/incomplete.rcl ~/training_data/matches/match_$i.rcl
done
EOF
chmod +x ~/collect_data.sh
nohup ~/collect_data.sh 3000 > ~/training_data/logs/collect.log 2>&1 &
```

#### Step 2: 提取特征 → 训练 DNN（24 小时 GPU）

```bash
cd ~/robocup2d/team/Cyrus2DBase-cyrus2d/scripts/training_unmark
sed -i "s|/home/nader/workspace/robo/Cyrus2DBase/data/|$HOME/training_data/|" trainer.py

# 训练（约 24h）
python3 trainer.py 2>&1 | tee ~/training_data/logs/train.log
# 输出：res/cyrus2d_best_model.h5
```

#### Step 3: 转 Keras → CppDNN

```bash
cd ~/robocup2d/team/CppDNN-develop
python3 script/keras_to_cpp.py \
    ~/training_data/models/best_model.h5 \
    ~/wxxychyzz/wxxychyzz_dnn_weights.txt
```

#### Step 4: 集成到新版 vv2

```bash
# 复制 Cyrus2DBase 重编（需安装 CppDNN，已默认装在 /usr/local/include/CppDNN）
cp -r ~/robocup2d/team/Cyrus2DBase-cyrus2d ~/wxxychyzz_versions/vv2_src
cd ~/wxxychyzz_versions/vv2_src
sed -i 's|unmark_dnn_weights.txt|wxxychyzz_dnn_weights.txt|g' src/player/bhv_unmark.cpp
mkdir build && cd build && cmake .. && make -j$(nproc)

# 部署 vv2
mkdir -p ~/vv2/{lib,data}
cp build/bin/sample_player ~/vv2/wxxychyzz_Player
cp build/bin/sample_coach ~/vv2/wxxychyzz_Coach
cp build/bin/player.conf build/bin/coach.conf ~/vv2/data/
cp -r build/bin/formations-dt ~/vv2/data/
cp ~/wxxychyzz/wxxychyzz_dnn_weights.txt ~/vv2/  # 关键：CWD 加载
cp /usr/local/lib/librcsc.so.19 ~/vv2/lib/
cp /usr/local/lib/librcsc.so.19 ~/vv2/librcsc.so.19
cp ~/wxxychyzz/start.sh ~/wxxychyzz/kill.sh ~/vv2/
chmod +x ~/vv2/start.sh ~/vv2/kill.sh

# 测试
~/wxxychyzz_versions/test_one.sh ~/vv2 \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 600
```

### 7.3 路径 B：MAPPO 自对战（2-4 周 / 2-4 GPU）

详见 `~/vv1/TRAINING.md` 第 6.3 节，含完整 Python 代码骨架（mappo_env.py + mappo_train.py）。

### 7.4 路径 C：针对性策略调参（1-2 天，无需 GPU）

```bash
# 1. 录 20 场 vs AHUTI
mkdir -p ~/training_data/ahuti_matches
for i in $(seq 1 20); do
    ~/wxxychyzz_versions/test_one.sh ~/wxxychyzz \
        "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 600
    cp /tmp/incomplete.rcl ~/training_data/ahuti_matches/match_$i.rcl
done

# 2. 分析 AHUTI 进攻路线
python3 << 'EOF'
import os, re
from collections import defaultdict
angle_dist = defaultdict(int)
for f in os.listdir(os.path.expanduser('~/training_data/ahuti_matches')):
    if not f.endswith('.rcl'): continue
    with open(f'~/training_data/ahuti_matches/{f}') as fp:
        for line in fp:
            m = re.search(r'AHUTI_(\d+).*\(kick \d+\.?\d* (-?\d+\.?\d*)\)', line)
            if m: angle_dist[int(float(m.group(2))/30)*30] += 1
print("AHUTI 常用进攻角度:")
for a, c in sorted(angle_dist.items(), key=lambda x: -x[1])[:10]:
    print(f"  {a}°: {c} 次")
EOF

# 3. 根据分析调整 ~/wxxychyzz/data/formations-dt/defense-formation.conf
# 把更多防守球员往 AHUTI 习惯进攻路线放（手工编辑或写自动化脚本）

# 4. 重测验证
~/repeated_test.sh ~/wxxychyzz \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 10
```

---

## Phase 8：参赛打包提交

### 8.1 自检脚本

```bash
cat > ~/pre_submit_check.sh <<'EOF'
#!/bin/bash
DIR="${1:-$HOME/wxxychyzz}"
echo "=== 比赛规则合规检查 ==="

[ -x "$DIR/wxxychyzz_Player" ] && echo "✅ Player 可执行" || echo "❌"
[ -x "$DIR/wxxychyzz_Coach" ] && echo "✅ Coach 可执行" || echo "❌"
[ -x "$DIR/start.sh" ] && echo "✅ start.sh 可执行" || echo "❌"
[ -x "$DIR/kill.sh" ] && echo "✅ kill.sh 可执行" || echo "❌"

# 启动 < 15s 检测
START=$(date +%s)
$DIR/start.sh > /dev/null 2>&1 &
sleep 5
END=$(date +%s)
N=$(pgrep -f wxxychyzz_Player | wc -l)
$DIR/kill.sh > /dev/null 2>&1
echo "✅ 启动 ${N}/11 球员，用时 $((END-START))s（要求 <15s）"

MISSING=$(LD_LIBRARY_PATH=$DIR ldd $DIR/wxxychyzz_Player 2>&1 | grep "not found" | wc -l)
[ "$MISSING" = "0" ] && echo "✅ 库依赖完整" || echo "❌ $MISSING 个库缺失"

grep -q '\\-g' $DIR/start.sh && echo "✅ 1 号是守门员" || echo "❌"
EOF
chmod +x ~/pre_submit_check.sh
~/pre_submit_check.sh ~/wxxychyzz
```

### 8.2 打包

```bash
cd ~ && zip -r wxxychyzz_release.zip wxxychyzz/ -x "wxxychyzz/*.md"
ls -lh wxxychyzz_release.zip
# 上传 wxxychyzz_release.zip 到比赛官方平台
```

---

## 时间总览

| 阶段 | 用时 | 难度 |
|---|---|---|
| Phase 0-1 系统+rcssserver | 15-25 min | ⭐ |
| Phase 2 librcsc | 10-15 min | ⭐⭐（GCC 13 兼容性需手工修复）|
| Phase 3 球队 | 15-30 min | ⭐⭐ |
| Phase 4 监视器 | 2 min | ⭐ |
| Phase 5 第一场 | 10 min | ⭐ |
| Phase 6 批量测试 | 3-4 hours | ⭐⭐ |
| Phase 7A DNN 训练 | **1-2 周** | ⭐⭐⭐ |
| Phase 7B MAPPO | **2-4 周** | ⭐⭐⭐⭐⭐ |
| Phase 7C 针对性调参 | 1-2 天 | ⭐⭐ |
| Phase 8 打包 | 5 min | ⭐ |

## 当前状态（你已经走过的路）

✅ Phase 0-5 已全部完成
✅ vv1 已部署（AHUTI 重打包，#1 冠军级）
✅ 监视器 rcssmonitor 已装好
✅ 一键看比赛 `~/watch_match.sh` 可用
⚠️ Phase 7（训练）需要 GPU，本会话内未做

## 关键命令速查

```bash
# 看比赛（一键）
~/watch_match.sh                  # vs AHUTI（默认）
~/watch_match.sh MASXY1           # vs MASXY1

# 启动/终止
~/wxxychyzz/start.sh
~/wxxychyzz/kill.sh

# 单场测试
~/wxxychyzz_versions/test_one.sh ~/wxxychyzz <对手目录> 600

# 多场胜率
~/repeated_test.sh ~/wxxychyzz <对手目录> 5

# 切换版本
cp -r ~/wxxychyzz_versions/v1/* ~/wxxychyzz/    # 旧版
cp -r ~/vv1/* ~/wxxychyzz/                       # 当前 vv1

# 比赛日志
grep "Score:" /tmp/rcssserver.log
grep "referee goal" /tmp/incomplete.rcl | grep -v "kick\|catch\|offside"
```

## 关键文件

```
~/wxxychyzz/                  # 当前部署队伍（= vv1）
~/vv1/                        # AHUTI 重打包冠军版
~/vv2/                        # 训练后的版本（待生成）
~/wxxychyzz_versions/         # 所有版本备份
├── v1/  v1_src/              # 自建 helios+score
├── v2/  v2_src/              # +时间/体力感知
├── v3/                       # +Cyrus2D 阵型
├── v4/  v4_src/              # 综合
├── vv1_pure_ahuti/           # 纯 AHUTI 备份
├── RESULTS.md                # 实测对比
└── test_one.sh               # 测试脚本
~/wxxychyzz_training/         # 训练基础设施
├── Pyrus2D/                  # Python 底座（用于 RL）
└── training_unmark/          # Cyrus2D DNN 训练脚本
~/robocup2d/                  # 源码工作区
├── server/rcssserver-19.0.0/ # rcssserver 源码 + 编译产物
└── team/
    ├── librcsc/              # 通信库源码
    ├── helios-base/          # helios-base 源码
    └── Cyrus2DBase-cyrus2d/  # Cyrus2D 冠军底座（含 552KB 预训练 DNN）
~/rcssmonitor.AppImage        # 可视化监视器
~/watch_match.sh              # 一键看比赛
~/wxxychyzz/USAGE.md          # 详细使用文档（687 行）
~/wxxychyzz/TRAINING.md       # 训练手册（491 行）
~/wxxychyzz/QUICK_REF.md      # 速查卡
~/COMPLETE_GUIDE.md           # 本文件
```

## 训练成本预算

| 路径 | 时间 | 硬件 | vs AHUTI 胜率 |
|---|---|---|---|
| 当前 vv1（仅模仿） | 0 | CPU | 50%（镜像） |
| 路径 C（调参） | 1-2 天 | CPU | 50-55% |
| 路径 A（DNN） | 1-2 周 | 1 GPU | 55-65% |
| 路径 B（MAPPO） | 2-4 周 | 2-4 GPU | 60-75% |
| A+B+C 综合 | 1-2 月 | GPU 集群 | 70-85% |

## 故障排查

| 现象 | 原因 | 处置 |
|---|---|---|
| `server down??` | rcssserver 未启动/端口冲突 | `pgrep rcssserver`, `ss -tunl \| grep 600` |
| 卡在 cycle 0 | auto_mode 没生效 | 重置 server.conf：`rm -rf ~/.rcssserver && rcssserver server::help > /dev/null` |
| 监视器无窗口 | DISPLAY 未设置 | `export DISPLAY=:0; export XAUTHORITY=$(ls /run/user/$(id -u)/.mutter-Xwayland*)` |
| `librcsc.so not found` | LD_LIBRARY_PATH 缺失 | `export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH` |
| 编译报 ntohl/htonl | GCC 13 严格模式 | 添加 `#include <arpa/inet.h>` 到出错文件 |
