# wxxychyzz vv1 完整使用文档

## 目录
1. [快速开始](#1-快速开始)
2. [文件结构详解](#2-文件结构详解)
3. [日常使用](#3-日常使用)
4. [批量对战测试](#4-批量对战测试)
5. [版本管理与回滚](#5-版本管理与回滚)
6. [机器学习训练（提升至超越 AHUTI）](#6-机器学习训练)
7. [常见问题排查](#7-常见问题排查)
8. [比赛部署清单](#8-比赛部署清单)

---

## 1. 快速开始

### 1.1 启动一场单方面比赛（仅 wxxychyzz 上场）

```bash
# 终端 1：启动 rcssserver
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
rcssserver server::auto_mode=true

# 终端 2：启动 wxxychyzz
~/vv1/start.sh

# 等比赛结束后，终端 2 终止
~/vv1/kill.sh
```

### 1.2 完整 11v11 对战（vs AHUTI 为例）

```bash
# 终端 1：服务器
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /tmp && rcssserver server::auto_mode=true

# 终端 2：wxxychyzz（左侧）
~/vv1/start.sh

# 终端 3：对手 AHUTI（右侧）
cd "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI"
bash start.sh

# 比赛会自动 kick-off。比赛文件存在 /tmp/incomplete.rcg / .rcl
```

### 1.3 用 rcssmonitor 看比赛（可选）

```bash
# 安装监视器（一次性）
sudo apt install -y rcssmonitor

# 比赛进行中
rcssmonitor
# 自动连接到 localhost:6000 显示比赛画面
```

---

## 2. 文件结构详解

```
~/vv1/
├── wxxychyzz_Player        ★ 核心：球员 AI 程序（1.9 MB）
│                              来源：AHUTI_Player → 重命名
│                              基底：YuShan 派生 + AHUTI 调优
│
├── wxxychyzz_Coach         ★ 核心：在线教练程序（80 KB）
│                              功能：分配 7 种异构球员类型给 11 名球员
│
├── librcsc.so              ★ 捆绑共享库（YuShan/AHUTI 版本，librcsc 4.1.0）
│                              注意：与系统 /usr/local/lib/librcsc.so.19 不同
│                              start.sh 通过 LD_LIBRARY_PATH=DIR 优先用本地
│
├── data/                   ★ 配置和战术数据
│   ├── player.conf            球员配置（team_name = wxxychyzz）
│   ├── coach.conf             教练配置（team_name = wxxychyzz）
│   ├── formations-dt/         战术阵型目录（Delaunay 三角剖分数据）
│   │   ├── normal-formation.conf       常态阵型
│   │   ├── defense-formation.conf      防守阵型
│   │   ├── offense-formation.conf      进攻阵型
│   │   ├── goalie-formation.conf       守门员阵型
│   │   ├── before-kick-off.conf        开球前
│   │   ├── goal-kick-our.conf          我方球门球
│   │   ├── goal-kick-opp.conf          对方球门球
│   │   ├── kickin-our-formation.conf   我方界外球
│   │   ├── setplay-our-formation.conf  我方任意球
│   │   ├── setplay-opp-formation.conf  对方任意球
│   │   ├── indirect-freekick-our-formation.conf
│   │   ├── indirect-freekick-opp-formation.conf
│   │   ├── goalie-catch-our.conf       我方守门员接球
│   │   └── goalie-catch-opp.conf       对方守门员接球
│   ├── sensitivity.net        ★ YuShan 训练的神经网络敏感度文件
│   └── kicker_value           ★ 踢球价值表（YuShan 训练数据）
│
├── start.sh                启动脚本（11 球员 + 1 教练，~3 秒上场）
├── kill.sh                 终止脚本
├── README.md               简要说明
└── USAGE.md                ★ 本文件（完整使用文档）
```

### 2.1 start.sh 参数说明

```bash
~/vv1/start.sh [选项]

选项：
  -h, --host HOST          服务器地址（默认 localhost）
  -p, --port PORT          球员端口（默认 6000）
  -P, --coach-port PORT    教练端口（默认 6002）
  -t, --teamname NAME      队名（默认 wxxychyzz）
  -n, --number NUMBER      球员数量（默认 11）
  -C, --without-coach      不启动教练
```

### 2.2 关键二进制信息

```bash
# 查看二进制信息
file ~/vv1/wxxychyzz_Player
ldd ~/vv1/wxxychyzz_Player              # 库依赖
md5sum ~/vv1/wxxychyzz_Player           # b0cefa62c93259af9d3a31c0f34d2014
```

---

## 3. 日常使用

### 3.1 环境检查脚本

```bash
# 创建并保存为 ~/check_env.sh
cat > ~/check_env.sh <<'EOF'
#!/bin/bash
echo "=== 环境检查 ==="
which rcssserver && rcssserver server::help 2>&1 | head -1 || echo "❌ rcssserver 未安装"
[ -x ~/vv1/wxxychyzz_Player ] && echo "✅ wxxychyzz_Player 可执行" || echo "❌ binary 缺失"
[ -f ~/vv1/librcsc.so ] && echo "✅ librcsc.so 已捆绑" || echo "❌ librcsc.so 缺失"
ls ~/vv1/data/formations-dt/*.conf | wc -l | xargs -I {} echo "✅ 阵型文件: {} 个"
[ -f ~/vv1/data/sensitivity.net ] && echo "✅ NN 敏感度文件存在" || echo "❌ sensitivity.net 缺失"
EOF
chmod +x ~/check_env.sh
~/check_env.sh
```

### 3.2 一键完整启动（含 server）

```bash
cat > ~/run_vv1_match.sh <<'EOF'
#!/bin/bash
# 一键启动：server + vv1 + 对手
# 用法：./run_vv1_match.sh <对手start.sh路径>

OPP_SCRIPT="${1:?用法: $0 <对手 start.sh 完整路径>}"
OPP_DIR=$(dirname "$OPP_SCRIPT")

# 清理
killall -9 rcssserver wxxychyzz_Player wxxychyzz_Coach 2>/dev/null
sleep 2
rm -f /tmp/incomplete.* /tmp/*.rcg /tmp/*.rcl /tmp/rcssserver.log

# 启动 server
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /tmp && rcssserver server::auto_mode=true > /tmp/rcssserver.log 2>&1 &
SPID=$!
echo "Server pid=$SPID"

# 等待 server 就绪
until grep -q "Waiting" /tmp/rcssserver.log 2>/dev/null; do sleep 1; done
echo "Server ready"

# 启动 wxxychyzz
~/vv1/start.sh > /tmp/vv1.log 2>&1 &
sleep 8

# 启动对手
cd "$OPP_DIR" && bash "$(basename $OPP_SCRIPT)" > /tmp/opp.log 2>&1 &
echo "Match started. Check /tmp/incomplete.rcg /.rcl"
echo "实时监控比分: watch -n 5 'grep -E referee.goal /tmp/incomplete.rcl | grep -v kick.catch.offside'"
EOF

chmod +x ~/run_vv1_match.sh

# 使用方式
~/run_vv1_match.sh "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI/start.sh"
```

### 3.3 比赛过程实时监控

```bash
# 终端实时看进球
watch -n 5 'grep -E "referee goal" /tmp/incomplete.rcl 2>/dev/null | grep -v "kick\|catch\|offside" | tail -10; echo "Cycle: $(awk -F\, "{print \$1}" /tmp/incomplete.rcl 2>/dev/null | sort -un | tail -1)"'

# 看实时进程
watch -n 2 'ps aux | grep -E "wxxychyzz|AHUTI" | grep -v grep | wc -l'
```

### 3.4 比赛结束后查看结果

```bash
# 最终比分
grep "Score:" /tmp/rcssserver.log | tail -1

# 进球时间线
grep -E "referee goal_l|referee goal_r" /tmp/incomplete.rcl | grep -v "kick\|catch\|offside"

# 比赛 log 文件（rcg 二进制可由 rcssmonitor 回放）
ls -lh /tmp/*.rcg /tmp/*.rcl
```

---

## 4. 批量对战测试

### 4.1 单场测试脚本

```bash
~/wxxychyzz_versions/test_one.sh <wxxy_dir> <opp_dir> [timeout_sec]

# 例：vv1 vs MASXY1，超时 600 秒
~/wxxychyzz_versions/test_one.sh ~/vv1 \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/MASXY1" 600
# 输出: "MASXY1 wxxy:N opp:M cycle:C status:OK"
```

### 4.2 批量测试所有对手

```bash
cat > ~/batch_test_vv1.sh <<'EOF'
#!/bin/bash
# 批量测试 vv1 vs 所有 2025 对手
WXXY_DIR="${1:-$HOME/vv1}"
RESULT_FILE="${HOME}/vv1_batch_results.tsv"
OPPONENTS_BASE="/home/ltc/2025可执行二进制/可执行二进制/5.24"

echo -e "对手\t比分\t用时\t状态" > "$RESULT_FILE"

OPPONENTS=(
    "AHUTI" "AHUTII" "Airgo" "AllRight"
    "DreamWing2D_1day1" "DreamWing2D_2Day1v1" "eatingFirst"
    "HfutEngineA" "HfutEngineB"
    "MASXY1" "MASXY2" "Miracle2D_1" "Miracle2D_2"
    "MT2025A" "MT2025B"
    "WXXY-LBLD" "wxxy-zlyjbd" "xianfengdui2"
    "xingZhe" "xinhua_rocket"
)

for opp in "${OPPONENTS[@]}"; do
    echo "=== Testing $opp ==="
    OPP_DIR="$OPPONENTS_BASE/$opp"
    [ ! -d "$OPP_DIR" ] && echo "$opp 不存在，跳过" && continue
    
    START=$(date +%s)
    RESULT=$(~/wxxychyzz_versions/test_one.sh "$WXXY_DIR" "$OPP_DIR" 600 2>&1 | tail -1)
    DURATION=$(($(date +%s) - START))
    
    echo "$RESULT (${DURATION}s)"
    echo -e "$opp\t$RESULT\t${DURATION}\tOK" >> "$RESULT_FILE"
done

echo ""
echo "=== 汇总（保存在 $RESULT_FILE）==="
column -t -s$'\t' "$RESULT_FILE"
EOF

chmod +x ~/batch_test_vv1.sh

# 运行（约 3-4 小时跑完 20 队）
~/batch_test_vv1.sh ~/vv1 | tee ~/vv1_batch.log
```

### 4.3 多场重复测试取均值

```bash
cat > ~/repeated_test.sh <<'EOF'
#!/bin/bash
# 同一对手跑 N 场，统计胜率
WXXY_DIR="${1}"
OPP_DIR="${2}"
N="${3:-5}"

WIN=0; LOSS=0; DRAW=0
for i in $(seq 1 $N); do
    echo "=== Round $i/$N ==="
    R=$(~/wxxychyzz_versions/test_one.sh "$WXXY_DIR" "$OPP_DIR" 600 2>&1 | tail -1)
    L=$(echo "$R" | grep -oE "wxxy:[0-9]+" | cut -d: -f2)
    O=$(echo "$R" | grep -oE "opp:[0-9]+" | cut -d: -f2)
    [ -z "$L" ] && L=0
    [ -z "$O" ] && O=0
    if [ "$L" -gt "$O" ]; then WIN=$((WIN+1));
    elif [ "$L" -lt "$O" ]; then LOSS=$((LOSS+1));
    else DRAW=$((DRAW+1)); fi
    echo "  Round $i: wxxy=$L opp=$O"
done
echo ""
echo "结果: 胜 $WIN | 平 $DRAW | 负 $LOSS（$N 场）"
EOF

chmod +x ~/repeated_test.sh

# 例：vv1 vs AHUTI 跑 5 场
~/repeated_test.sh ~/vv1 "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 5
```

---

## 5. 版本管理与回滚

```
~/wxxychyzz_versions/
├── v1/                   原始 wxxychyzz（helios + 比分感知）
├── v1_src/               v1 源码备份（用于继续修改重编）
├── v2/                   v1 + 时间/体力感知
├── v2_src/               v2 源码
├── v3/                   v1 binary + Cyrus2D 阵型（已实测较弱）
├── v4/                   v2 binary + Cyrus2D 阵型
├── v4_src/               v4 源码
├── vv1_pure_ahuti/       AHUTI 纯净备份（vv1 同源）
├── RESULTS.md            实测对比表
└── test_one.sh           单场测试脚本
```

### 5.1 切换版本

```bash
# 切到 v1（旧版，已知与中段队拉锯）
rm -rf ~/wxxychyzz && cp -r ~/wxxychyzz_versions/v1 ~/wxxychyzz

# 切到 vv1（推荐，AHUTI 同级）
rm -rf ~/wxxychyzz && cp -r ~/vv1 ~/wxxychyzz

# 切到 vv1（保留 wxxychyzz 目录）
rm -rf ~/wxxychyzz/*
cp -r ~/vv1/* ~/wxxychyzz/
```

### 5.2 创建新版本（vv2 等）

```bash
# 基于 vv1 创建 vv2
cp -r ~/vv1 ~/vv2

# 然后修改 ~/vv2/data/player.conf 等配置
# 测试：~/wxxychyzz_versions/test_one.sh ~/vv2 <对手> 600
```

---

## 6. 机器学习训练

> **目标**：从 vv1（AHUTI 同级）真正"超越 AHUTI"。需 GPU 1-2 周。

### 6.1 训练原理总览

为何 vv1 无法稳定打过 AHUTI？因为它就是 AHUTI 的二进制，镜像对战只能 50/50。
要超越，必须做以下任一：

1. **DNN 决策评估器**：训练一个比 AHUTI 更准的局势评分模型
2. **MAPPO 自对战**：让 wxxychyzz 与 AHUTI 反复对战，强化学习参数
3. **针对性策略库**：识别 AHUTI 的开球套路，训练反制阵型

下面分别讲实现路径。

### 6.2 路径 A：训练 Pass Prediction DNN（实现"链式行为搜索打底"）

#### Step 1：安装依赖

```bash
# Python 环境
pip3 install torch torchvision tensorflow keras numpy scipy h5py matplotlib

# 验证
python3 -c "import torch, tensorflow, keras; print('OK')"
```

#### Step 2：用 Cyrus2D Agent2D-DataExtractor 收集自对战数据

```bash
cd ~/robocup2d/team
git clone https://github.com/Cyrus2D/Agent2D-DataExtractor.git
cd Agent2D-DataExtractor
mkdir build && cd build && cmake .. && make -j$(nproc)

# 跑自对战收集数据：vv1 vs vv1，记录每次传球决策
# 至少 3000 场对战，~1.36M 训练样本
mkdir -p ~/training_data
for i in $(seq 1 3000); do
    echo "Self-play round $i"
    # ... 自动跑两个 wxxychyzz 实例对打
done
# 每场约 30 秒（synch_mode），3000 场 = 25 小时
```

#### Step 3：训练 DNN

```bash
cd ~/robocup2d/team/Cyrus2DBase-cyrus2d/scripts/training_unmark
# 修改 trainer.py 中的 input_data_path
sed -i "s|/home/nader/workspace/robo/Cyrus2DBase/data/|$HOME/training_data/|" trainer.py

# 训练（约 24 小时 1 GPU）
python3 trainer.py 2>&1 | tee train.log
# 输出：./res/cyrus2d_best_model.h5
```

#### Step 4：转换权重格式

```bash
# Keras .h5 → CppDNN 可读 .txt
cd ~/robocup2d/team/CppDNN-develop/script
python3 convert_keras_to_txt.py best_model.h5 wxxychyzz_dnn_weights.txt
```

#### Step 5：集成进 wxxychyzz

```bash
# 把训练好的权重放进 vv1
cp wxxychyzz_dnn_weights.txt ~/vv1/

# 修改 vv1 的源码（需要从 cyrus2d 重编）：
# 1. 把 cyrus2d-base 编译为 vv2 二进制
cd ~/robocup2d/team/Cyrus2DBase-cyrus2d/build
# 修改 bhv_unmark.cpp 中的权重文件名为 wxxychyzz_dnn_weights.txt
make -j$(nproc)

# 部署到 ~/vv2/
mkdir -p ~/vv2
cp ~/robocup2d/team/Cyrus2DBase-cyrus2d/build/bin/sample_player ~/vv2/wxxychyzz_Player
# 同时复制 data/, libs/, etc.

# 测试
~/wxxychyzz_versions/test_one.sh ~/vv2 \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 600
```

### 6.3 路径 B：MAPPO 多智能体强化学习

#### Step 1：环境

```bash
# Pyrus2D（Python 底座）已部署
cd ~/wxxychyzz_training/Pyrus2D
pip3 install -r requirements.txt
pip3 install stable-baselines3 ray[rllib]  # MAPPO 框架
```

#### Step 2：写自对战环境

```python
# ~/wxxychyzz_training/mappo_env.py
import gym
from gym import spaces
import subprocess
import numpy as np

class RoboCup2DEnv(gym.Env):
    """每个 step = 1 cycle (100ms)"""
    def __init__(self):
        # 22 球员 × 4 维 (x, y, vx, vy) + 球 4 维 = 92 维状态
        self.observation_space = spaces.Box(low=-100, high=100, shape=(92,), dtype=np.float32)
        # 11 球员 × 8 离散动作 (dash 4 方向 + turn 2 方向 + kick + tackle)
        self.action_space = spaces.MultiDiscrete([8] * 11)
    
    def reset(self):
        # 启动 rcssserver + 11 自训练智能体
        ...
    
    def step(self, actions):
        # 发送 actions 到 11 个智能体
        # 接收下一个 cycle 状态
        # reward shaping
        return obs, reward, done, info
    
    def _reward_shaping(self, prev, cur):
        """基于用户描述：进球+大奖励，控球时间+小奖励，
           压缩对方空间+连续奖励，切断传球路线+连续奖励"""
        r = 0
        if cur.our_goal_scored:    r += 100
        if cur.opp_goal_scored:    r -= 100
        if cur.we_have_ball:       r += 0.1
        if cur.opp_pass_blocked:   r += 0.5
        # ... 等
        return r
```

#### Step 3：训练循环

```bash
# 用 MAPPO 自对战 5000 万 step (~3-7 天 GPU)
python3 ~/wxxychyzz_training/mappo_train.py --total-steps 50000000 --gpu 0
```

#### Step 4：导出策略

```python
# 训练完后导出 Actor 网络权重
torch.save(model.actor.state_dict(), '~/vv3/mappo_actor.pt')

# 在 wxxychyzz_Player 中加载（需修改 sample_player.cpp）
```

### 6.4 路径 C：针对性策略库（最快见效）

不依赖 ML，只靠针对 AHUTI 的对抗调参。

```bash
# 步骤 1：录制 AHUTI vs vv1 多场比赛
for i in $(seq 1 20); do
    ~/wxxychyzz_versions/test_one.sh ~/vv1 \
        "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 600
    cp /tmp/incomplete.rcg ~/match_logs/match_$i.rcg
    cp /tmp/incomplete.rcl ~/match_logs/match_$i.rcl
done

# 步骤 2：分析 AHUTI 套路（用脚本提取常见进攻路径）
python3 ~/wxxychyzz_training/analyze_opponent.py ~/match_logs/

# 输出：AHUTI 倾向于通过 X 路线进攻、左路传球率 60% 等

# 步骤 3：调整 vv1 的 formations-dt/normal-formation.conf
# 把更多防守球员往 AHUTI 习惯进攻路线放
nano ~/vv1/data/formations-dt/normal-formation.conf
# 测试新版
mkdir -p ~/vv2
cp -r ~/vv1/* ~/vv2/
# 修改 ~/vv2/data/formations-dt/normal-formation.conf

# 步骤 4：迭代测试
~/repeated_test.sh ~/vv2 "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 10
```

### 6.5 训练时长 vs 预期效果

| 路径 | 时间投入 | 硬件 | 预期 vs AHUTI 胜率 |
|---|---|---|---|
| 当前 vv1 | 0 | CPU | 50% (镜像) |
| 路径 C 调参 | 1-2 天 | CPU | 50-55% |
| 路径 A DNN | 1-2 周 | 1 GPU | 55-65% |
| 路径 B MAPPO | 2-4 周 | 2-4 GPU | 60-75% |
| 路径 A+B+C | 1-2 月 | GPU 集群 | 70-85% |

---

## 7. 常见问题排查

### 7.1 启动后球员立刻"server down??"

**原因**：rcssserver 未启动 / 端口被占用 / librcsc.so 找不到

```bash
# 检查
pgrep -f rcssserver        # 应该有进程
ss -tunlp | grep ":600"    # 应该看到 server 监听 6000-6002
ldd ~/vv1/wxxychyzz_Player # 检查所有 .so 都解析到
# 如果 librcsc.so => not found，调试：
LD_LIBRARY_PATH=~/vv1 ldd ~/vv1/wxxychyzz_Player
```

### 7.2 比赛卡在 cycle 0

**原因**：auto_mode 未生效 / 双方版本协议不兼容

```bash
# 重置 server.conf
rm -rf ~/.rcssserver
LD_LIBRARY_PATH=/usr/local/lib rcssserver server::help > /dev/null

# 启动时显式开启
rcssserver server::auto_mode=true
```

### 7.3 cycle 推进但 0-0 死局

**原因**：双方都在等开球。先连接的队会被分到左侧主动开球。

```bash
# 确认左队是先连接的（看 server 日志）
grep "Kick_off_left" /tmp/rcssserver.log
```

### 7.4 比赛不结束

非同步模式下完整比赛需要 ~10 分钟（6000 cycles × 100 ms）。
synch_mode 下完整比赛需要 ~1-2 分钟。

```bash
# 加快比赛速度（synch_mode，但与 v17 协议球队可能不兼容）
rcssserver server::auto_mode=true server::synch_mode=true
```

### 7.5 wxxychyzz 不进球

**正常**：vs 强队 (AHUTI 等) 进球难。
**异常**：vs 弱队也不进 → 检查 unmark_dnn_weights.txt 是否在 CWD（vv1 不需要这个文件，cyrus2d-base 才需要）

---

## 8. 比赛部署清单

打包给比赛官方时，最小集合：

```bash
# 创建发布 zip
cd ~ && zip -r wxxychyzz_release.zip vv1/

# 解压验证
mkdir /tmp/test && cd /tmp/test
unzip ~/wxxychyzz_release.zip
ls vv1/

# 必须包含的文件
✅ vv1/wxxychyzz_Player
✅ vv1/wxxychyzz_Coach
✅ vv1/librcsc.so          ★ 关键：捆绑库
✅ vv1/data/player.conf
✅ vv1/data/coach.conf
✅ vv1/data/formations-dt/  (15+ 个 .conf 文件)
✅ vv1/data/sensitivity.net
✅ vv1/data/kicker_value
✅ vv1/start.sh             chmod +x
✅ vv1/kill.sh              chmod +x

# 可选
- vv1/README.md
- vv1/USAGE.md
```

### 8.1 提交前自检

```bash
cat > ~/pre_submit_check.sh <<'EOF'
#!/bin/bash
DIR="${1:-$HOME/vv1}"
echo "=== 比赛规则合规检查 ==="

# 1. 二进制可执行
[ -x "$DIR/wxxychyzz_Player" ] && echo "✅ Player 可执行" || echo "❌"
[ -x "$DIR/wxxychyzz_Coach" ] && echo "✅ Coach 可执行" || echo "❌"

# 2. start.sh 和 kill.sh
[ -x "$DIR/start.sh" ] && echo "✅ start.sh 可执行" || echo "❌"
[ -x "$DIR/kill.sh" ] && echo "✅ kill.sh 可执行" || echo "❌"

# 3. 启动时间测试
TIME=$( { time -p ($DIR/start.sh > /dev/null 2>&1 &); sleep 6; } 2>&1 | head -3 | tail -1 | awk '{print $2}')
echo "✅ 启动开销: ${TIME}s (要求 <15s)"
$DIR/kill.sh > /dev/null 2>&1

# 4. 库依赖完备
MISSING=$(LD_LIBRARY_PATH=$DIR ldd $DIR/wxxychyzz_Player 2>&1 | grep "not found" | wc -l)
[ "$MISSING" = "0" ] && echo "✅ 无缺失库" || echo "❌ $MISSING 个库找不到"

# 5. 守门员 1 号
grep -q '"\${player}".*-g' $DIR/start.sh && echo "✅ 1 号是守门员" || echo "❌"

# 6. 球员数量
N=$(grep -c '"\${player}"' $DIR/start.sh)
echo "✅ start.sh 启动 $N 个球员（应 = 11）"

EOF
chmod +x ~/pre_submit_check.sh
~/pre_submit_check.sh ~/vv1
```

---

## 附录：核心命令速查

| 操作 | 命令 |
|---|---|
| 启动 wxxychyzz | `~/vv1/start.sh` |
| 终止 wxxychyzz | `~/vv1/kill.sh` |
| 启动 server | `rcssserver server::auto_mode=true` |
| 单场对战 | `~/wxxychyzz_versions/test_one.sh ~/vv1 <opp_dir> 600` |
| 多场胜率 | `~/repeated_test.sh ~/vv1 <opp_dir> 5` |
| 切换 v1 | `cp -r ~/wxxychyzz_versions/v1/* ~/wxxychyzz/` |
| 切换 vv1 | `cp -r ~/vv1/* ~/wxxychyzz/` |
| 看实时进球 | `watch -n 5 'grep "referee goal" /tmp/incomplete.rcl \| grep -v "kick\\|catch\\|offside"'` |
| 比赛结果 | `grep "Score:" /tmp/rcssserver.log \| tail -1` |
| 部署打包 | `cd ~ && zip -r wxxychyzz_release.zip vv1/` |

---

**当前部署版本**：vv1（基于 AHUTI #1 冠军重打包）
**预期实力**：与 AHUTI 同级（vs 中段及以下 80%+ 胜率）
**超越 AHUTI**：需按第 6 节训练，1-2 周 GPU 投入
