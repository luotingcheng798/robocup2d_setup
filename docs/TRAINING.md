# wxxychyzz 训练手册

## 训练目标：从 vv1（AHUTI 同级）超越 AHUTI

vv1 当前实力 = AHUTI 镜像 = 50/50 胜率
要稳定胜出需要 ≥55% 胜率，必须做训练。

---

## 训练前的环境准备

### 一次性安装

```bash
# 系统依赖（如果还没装）
echo "root" | sudo -S apt update && \
echo "root" | sudo -S apt install -y python3 python3-pip git build-essential cmake \
    libboost-all-dev libeigen3-dev

# Python ML 库
pip3 install --upgrade pip
pip3 install torch torchvision tensorflow keras numpy scipy h5py matplotlib pandas \
    stable-baselines3 ray[rllib] gymnasium pettingzoo

# 验证
python3 -c "import torch; print('PyTorch:', torch.__version__)"
python3 -c "import tensorflow; print('TF:', tensorflow.__version__)"
nvidia-smi  # 确认 GPU 可见
```

### 训练数据目录

```bash
mkdir -p ~/training_data/{rcg,rcl,extracted,models,logs}
```

---

## 路径 A：训练 Pass Prediction DNN（推荐，1-2 周）

### 阶段 1：数据收集（约 25 小时）

#### 1.1 用 Agent2D-DataExtractor

```bash
# 已部署位置
ls ~/robocup2d/team/Cyrus2DBase-cyrus2d/scripts/training_unmark/

# DataExtractor 仓库
cd ~/robocup2d/team
git clone https://github.com/Cyrus2D/Agent2D-DataExtractor.git
cd Agent2D-DataExtractor
mkdir build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

#### 1.2 自对战脚本

```bash
cat > ~/training_data/collect_data.sh <<'BASH'
#!/bin/bash
# 自对战 N 场，每场记录传球决策
N="${1:-3000}"
DATA_DIR=~/training_data/extracted
mkdir -p "$DATA_DIR"

for i in $(seq 1 $N); do
    echo "=== Round $i/$N ==="
    
    # 清理
    killall -9 rcssserver wxxychyzz_Player wxxychyzz_Coach 2>/dev/null
    sleep 2
    rm -f /tmp/incomplete.* /tmp/*.rcg /tmp/*.rcl
    
    # 启动 server (synch_mode 加快)
    export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
    rcssserver server::auto_mode=true server::synch_mode=true \
        server::nr_normal_halfs=1 > /tmp/rcs.log 2>&1 &
    sleep 3
    
    # 双方都用 vv1（自对战）
    ~/vv1/start.sh > /tmp/wxxy_l.log 2>&1 &
    sleep 2
    ~/vv1/start.sh -t wxxy_R > /tmp/wxxy_r.log 2>&1 &
    
    # 等待结束
    while pgrep -f rcssserver > /dev/null; do sleep 5; done
    
    # 保存 rcl
    cp /tmp/incomplete.rcl "$DATA_DIR/match_$i.rcl"
done

echo "Done: $N matches collected"
BASH
chmod +x ~/training_data/collect_data.sh

# 后台运行（约 25 小时）
nohup ~/training_data/collect_data.sh 3000 > ~/training_data/collect.log 2>&1 &
```

#### 1.3 提取训练特征

```bash
# 用 Agent2D-DataExtractor 解析 rcl
~/robocup2d/team/Agent2D-DataExtractor/build/bin/extract_pass_data \
    -i ~/training_data/extracted/ \
    -o ~/training_data/pass_features.csv

# 输出预期 ~1.36M 行（每行一次传球决策的特征向量 + 标签）
wc -l ~/training_data/pass_features.csv
```

### 阶段 2：训练（约 24 小时 GPU）

```bash
cd ~/robocup2d/team/Cyrus2DBase-cyrus2d/scripts/training_unmark

# 修改输入路径
sed -i "s|/home/nader/workspace/robo/Cyrus2DBase/data/|$HOME/training_data/|" trainer.py

# 训练参数（根据 GPU 内存调整 batch_size）
python3 trainer.py 2>&1 | tee ~/training_data/logs/train.log

# 中间产物
# - res/cyrus2d_model_epoch_*.h5
# - res/cyrus2d_best_model.h5
```

#### 训练监控

```bash
# 实时看 loss
tail -f ~/training_data/logs/train.log | grep -E "epoch|loss|acc"

# Tensorboard（如果 trainer 写了日志）
tensorboard --logdir=~/training_data/logs/
```

### 阶段 3：部署到 wxxychyzz

#### 3.1 转换 Keras → CppDNN

```bash
# 用 CppDNN 提供的转换脚本
cd ~/robocup2d/team/CppDNN-develop/script
python3 keras_to_cpp.py \
    ~/training_data/models/cyrus2d_best_model.h5 \
    ~/vv2/wxxychyzz_dnn_weights.txt
```

#### 3.2 重编 Cyrus2D-base 含我们权重

```bash
# 复制 Cyrus2DBase 为 vv2 源码
cp -r ~/robocup2d/team/Cyrus2DBase-cyrus2d ~/wxxychyzz_versions/vv2_src
cd ~/wxxychyzz_versions/vv2_src

# 修改权重文件名为我们的
sed -i 's|unmark_dnn_weights.txt|wxxychyzz_dnn_weights.txt|g' \
    src/player/bhv_unmark.cpp

# 修改队名
sed -i 's|HELIOS_base|wxxychyzz|g' src/player.conf src/coach.conf

# 重编
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

#### 3.3 打包 vv2

```bash
mkdir -p ~/vv2/{lib,data}
cp ~/wxxychyzz_versions/vv2_src/build/bin/sample_player ~/vv2/wxxychyzz_Player
cp ~/wxxychyzz_versions/vv2_src/build/bin/sample_coach ~/vv2/wxxychyzz_Coach
strip ~/vv2/wxxychyzz_*
cp ~/wxxychyzz_versions/vv2_src/build/bin/player.conf ~/vv2/data/
cp ~/wxxychyzz_versions/vv2_src/build/bin/coach.conf ~/vv2/data/
cp -r ~/wxxychyzz_versions/vv2_src/build/bin/formations-dt ~/vv2/data/
# 关键：DNN 权重必须在 CWD（即 vv2/）
cp ~/training_data/models/wxxychyzz_dnn_weights.txt ~/vv2/
# 库
cp /usr/local/lib/librcsc.so.19 ~/vv2/lib/
cp /usr/local/lib/librcsc.so.19 ~/vv2/librcsc.so.19
# 启动脚本（参考 ~/vv1/start.sh，注意 cd 到 DIR 让 DNN 加载）
cp ~/vv1/start.sh ~/vv1/kill.sh ~/vv2/

# 测试
~/wxxychyzz_versions/test_one.sh ~/vv2 \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 600
```

### 阶段 4：评估和迭代

```bash
# 跑 10 场 vs AHUTI 取均值
~/repeated_test.sh ~/vv2 \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 10

# 期望：胜率提升至 55-65%
```

---

## 路径 B：MAPPO 多智能体强化学习（高级，2-4 周）

### 框架准备

```bash
cd ~/wxxychyzz_training/Pyrus2D
# 已下载好 Cyrus2D 的 Pyrus2D Python 底座

# 安装 MARL 框架
pip3 install pettingzoo[soccer] supersuit
pip3 install stable-baselines3[extra]
```

### 自定义 Env

```python
# ~/wxxychyzz_training/mappo_env.py
import gymnasium as gym
from gymnasium import spaces
import numpy as np
from pettingzoo import ParallelEnv
import subprocess
import socket
import struct

class RoboCup2DParallelEnv(ParallelEnv):
    """11 智能体并行环境（共享策略 MAPPO）"""
    
    metadata = {"render_modes": ["human"]}
    
    def __init__(self, opponent_dir):
        super().__init__()
        self.opponent_dir = opponent_dir
        self.agents = [f"player_{i+1}" for i in range(11)]
        
        # 状态：每个 agent 看到的局部 + 全局
        self.observation_spaces = {
            agent: spaces.Box(low=-100, high=100, shape=(96,), dtype=np.float32)
            for agent in self.agents
        }
        # 动作：8 个离散动作（dash/turn/kick/tackle 简化）
        self.action_spaces = {
            agent: spaces.Discrete(8)
            for agent in self.agents
        }
        
        self.server_proc = None
    
    def reset(self, seed=None, options=None):
        # 启动 rcssserver
        self._start_server()
        # 启动对手（vs vv1 自对战或 vs AHUTI）
        self._start_opponent()
        # 启动 11 个我们的 Python agents
        # 等所有连上后 kick-off
        return self._get_observations(), {}
    
    def step(self, actions):
        # 把 actions 转成 RCSS 协议命令发送
        for agent, act in actions.items():
            self._send_action(agent, act)
        
        # 等下一个 cycle 的 see message
        new_obs = self._receive_observations()
        rewards = self._compute_rewards()
        terminations = self._check_terminal()
        truncations = self._check_timeout()
        
        return new_obs, rewards, terminations, truncations, {}
    
    def _compute_rewards(self):
        """Reward shaping (用户描述)"""
        rewards = {agent: 0.0 for agent in self.agents}
        
        # 进球 +100
        if self.our_goal_just_scored:
            for agent in self.agents:
                rewards[agent] += 100.0
        if self.opp_goal_just_scored:
            for agent in self.agents:
                rewards[agent] -= 100.0
        
        # 控球时间 +0.1
        if self.we_have_ball:
            rewards[self.ball_holder] += 0.1
        
        # 切断对方传球路线 +0.5（局部奖励）
        for agent in self.agents:
            if self._cuts_opp_pass(agent):
                rewards[agent] += 0.5
        
        # 压缩对方控球空间 +0.2
        # ...
        
        return rewards
```

### 训练

```python
# ~/wxxychyzz_training/mappo_train.py
import torch
from ray.rllib.algorithms.ppo import PPOConfig
from ray.tune.registry import register_env
from mappo_env import RoboCup2DParallelEnv

def env_creator(config):
    return RoboCup2DParallelEnv(opponent_dir=config["opponent_dir"])

register_env("robocup2d", env_creator)

config = (
    PPOConfig()
    .environment("robocup2d", env_config={
        "opponent_dir": "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI"
    })
    .multi_agent(
        policies={"shared_policy": (None, obs_space, act_space, {})},
        policy_mapping_fn=lambda agent_id, *args, **kwargs: "shared_policy",
    )
    .training(
        train_batch_size=8192,
        sgd_minibatch_size=512,
        num_sgd_iter=10,
        lr=3e-4,
        clip_param=0.2,
        entropy_coeff=0.01,
    )
    .resources(num_gpus=1, num_cpus_per_worker=2)
    .rollouts(num_rollout_workers=4, rollout_fragment_length=200)
)

algo = config.build()
for i in range(50000):  # ~5000 万 step
    result = algo.train()
    if i % 100 == 0:
        print(f"Iter {i}: reward={result['episode_reward_mean']:.2f}")
        algo.save(f"~/training_data/checkpoints/mappo_iter_{i}")
```

### 部署

```python
# 训练完后从 checkpoint 导出 actor 网络
import torch
checkpoint = "~/training_data/checkpoints/mappo_iter_50000"
# 加载 → torch.save(actor.state_dict(), 'mappo_actor.pt')

# 在 wxxychyzz_Player C++ 中通过 libtorch 加载推理
# 或导出 ONNX → onnxruntime 推理
```

---

## 路径 C：针对性策略库（最快，1-2 天，无需 GPU）

### 1. 录制 vs AHUTI 比赛日志

```bash
# 跑 20 场 vv1 vs AHUTI
mkdir -p ~/training_data/ahuti_matches
for i in $(seq 1 20); do
    echo "Match $i/20"
    rm -f /tmp/incomplete.*
    ~/wxxychyzz_versions/test_one.sh ~/vv1 \
        "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 600
    cp /tmp/incomplete.rcg ~/training_data/ahuti_matches/match_$i.rcg
    cp /tmp/incomplete.rcl ~/training_data/ahuti_matches/match_$i.rcl
done
```

### 2. 分析 AHUTI 进攻路线

```python
# ~/wxxychyzz_training/analyze_opponent.py
import os
import re
from collections import defaultdict

def parse_rcl(path):
    """解析 .rcl 文本日志"""
    events = []
    with open(path) as f:
        for line in f:
            if "(referee goal" in line:
                events.append(("goal", line))
            if "Recv AHUTI_" in line and "(kick" in line:
                # 抽取 AHUTI 的踢球决策
                match = re.search(r'AHUTI_(\d+).*\(kick (\d+\.?\d*) (\-?\d+\.?\d*)\)', line)
                if match:
                    events.append(("kick", int(match.group(1)), 
                                  float(match.group(2)), float(match.group(3))))
    return events

# 统计 AHUTI 的踢球角度分布
angle_dist = defaultdict(int)
for f in os.listdir(os.path.expanduser('~/training_data/ahuti_matches')):
    if f.endswith('.rcl'):
        events = parse_rcl(f'~/training_data/ahuti_matches/{f}')
        for ev in events:
            if ev[0] == 'kick':
                angle_bin = int(ev[3] / 30) * 30  # 30° bin
                angle_dist[angle_bin] += 1

# 输出常用角度
print("AHUTI 常用进攻角度（前10）:")
for angle, cnt in sorted(angle_dist.items(), key=lambda x: -x[1])[:10]:
    print(f"  {angle}° : {cnt} 次")
```

### 3. 调整 wxxychyzz formations

根据分析结果（如 AHUTI 70% 通过左路），把防守球员往左路偏：

```bash
# vv2 = vv1 + 调整后的 formations
cp -r ~/vv1 ~/vv2

# 编辑防守阵型，让左后卫更靠左
nano ~/vv2/data/formations-dt/defense-formation.conf
# 找到 PLAYER 2 (左后卫) 的位置数据，y 坐标减少 5（更靠近边线）

# 测试
~/repeated_test.sh ~/vv2 \
    "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" 10
```

---

## 训练资源参考

### 公开数据
- **RoboCup 历届比赛 rcg**：https://archive.robocup.info/Soccer/Simulation/2D/RCG/
- **HELIOS 训练数据**：随 helios-base 的 NEWS.en 提供
- **Cyrus2D 自对战数据集**：~1.36M 样本（公开链接见 arXiv 2401.03410）

### 论文
- Pass Prediction DNN: https://arxiv.org/abs/2401.03410
- Pyrus Base: https://arxiv.org/abs/2307.16875
- 11v11 MARL: https://link.springer.com/article/10.1007/s10458-023-09603-y

### 开源代码
- Cyrus2DBase: https://github.com/Cyrus2D/Cyrus2DBase
- Pyrus2D: https://github.com/Cyrus2D/Pyrus2D
- CppDNN: https://github.com/Cyrus2D/CppDNN
- Agent2D-DataExtractor: https://github.com/Cyrus2D/Agent2D-DataExtractor

---

## 训练成本预估

| 路径 | 时间 | 硬件 | 预期胜率 vs AHUTI | 难度 |
|---|---|---|---|---|
| C 调参 | 1-2 天 | 普通 CPU | 50-55% | ⭐ |
| A DNN | 1-2 周 | 1 × 3090 | 55-65% | ⭐⭐⭐ |
| B MAPPO | 2-4 周 | 2-4 × 3090 | 60-75% | ⭐⭐⭐⭐⭐ |
| A+B+C 综合 | 1-2 月 | GPU 集群 | 70-85% | ⭐⭐⭐⭐⭐ |

---

## 训练完成后回测流程

```bash
# 1. 跑批量对战
~/batch_test_vv1.sh ~/vv2 > ~/vv2_results.log

# 2. 对比 vv1 和 vv2
diff <(grep "wxxy:" ~/vv1_results.log) <(grep "wxxy:" ~/vv2_results.log)

# 3. 回归测试（确保没变弱）
~/repeated_test.sh ~/vv2 "/home/ltc/2025可执行二进制/可执行二进制/5.24/MASXY1" 5
~/repeated_test.sh ~/vv2 "/home/ltc/2025可执行二进制/可执行二进制/5.24/MASXY2" 5

# 4. 替换为 vv2
cp -r ~/vv2/* ~/wxxychyzz/
```

---

## 预算建议

如果只有 1 周时间和 1 块 GPU：**优先做路径 A**

如果有 1 个月和多块 GPU：**A + B 同时做**

如果不想买 GPU：**只做路径 C**，预期胜率 50-55%
