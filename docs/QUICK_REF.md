# wxxychyzz vv1 速查卡

## 一行启动
```bash
# Server
LD_LIBRARY_PATH=/usr/local/lib rcssserver server::auto_mode=true &

# 我方
~/vv1/start.sh

# 对手（举例：AHUTI）
cd "/home/ltc/2025可执行二进制/可执行二进制/5.24/AHUTI" && bash start.sh

# 看比分
grep "referee goal_l\|referee goal_r" /tmp/incomplete.rcl | grep -v "kick\|catch\|offside"

# 终止
~/vv1/kill.sh && killall -9 rcssserver
```

## 训练（提升至超越 AHUTI）
详见 `USAGE.md` 第 6 节。最快路径：
1. **路径 C 调参**（1-2 天 CPU，胜率 +5%）：录 20 场 vs AHUTI，分析其进攻路线，调整 formations
2. **路径 A DNN**（1-2 周 GPU，胜率 +10-15%）：用 Cyrus2D 数据提取器收集自对战数据，训练 pass-prediction DNN
3. **路径 B MAPPO**（2-4 周 GPU，胜率 +15-25%）：Pyrus2D + 自对战强化学习

## 当前实力
- vs MASXY1（#6）: 2-1 领先（28% 比赛已超 v1 全场）
- vs AHUTI（#1）: 镜像 RNG，理论 50/50

## 文件
- `~/vv1/`：当前部署
- `~/wxxychyzz_versions/`：所有版本备份
- `~/wxxychyzz_training/Pyrus2D/`：训练框架
