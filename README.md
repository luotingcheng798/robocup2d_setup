# RoboCup 2D 仿真足球队 — 完整安装包

> 从零到一在 Ubuntu 24.04 LTS 上搭建 RoboCup 2D 比赛队伍 wxxychyzz
> 含一键安装脚本、踩坑经验、训练流程

---

## 📦 安装包内容

```
robocup2d_setup/
├── README.md                         本文件（核心说明）
├── scripts/                          一键脚本
│   ├── 00_install_all.sh             ⭐ 一键全装（Phase 0-5）
│   ├── 01_install_deps.sh            装系统依赖
│   ├── 02_build_rcssserver.sh        编译 rcssserver
│   ├── 03_build_librcsc.sh           编译 librcsc（含 GCC 13 修复）
│   ├── 04_build_team.sh              编译 helios-base 球队
│   ├── 05_install_monitor.sh         装可视化监视器
│   ├── 06_run_match.sh               一键启动比赛 + 监视器
│   ├── 07_test_match.sh              单场测试脚本
│   └── 08_repackage_ahuti.sh         (可选) 重打包 AHUTI 为 wxxychyzz
├── docs/                             详细文档
│   ├── COMPLETE_GUIDE.md             8 阶段全流程
│   ├── USAGE.md                      日常操作
│   ├── TRAINING.md                   3 条训练路径
│   └── QUICK_REF.md                  速查卡
└── backup/                           可选备份内容
    └── (放置 librcsc 修复补丁等)
```

---

## 🚀 一键安装（最快上手）

```bash
# 装到 Ubuntu 24.04 LTS（必须是这个版本）
chmod +x scripts/*.sh
sudo bash scripts/00_install_all.sh
```

**用时**：30-50 分钟（含编译时间）

**完成后**：
- `~/wxxychyzz/` 部署完成
- `~/rcssmonitor.AppImage` 监视器
- `~/run_match.sh` 一键启动
- 文档全部放在 `~/robocup2d_setup/docs/`

---

## ⚙️ 分步执行（如果一键脚本失败）

按顺序运行：

```bash
sudo bash scripts/01_install_deps.sh        # 装依赖（5 min）
bash scripts/02_build_rcssserver.sh         # 编译 server（10-15 min）
bash scripts/03_build_librcsc.sh            # 编译 librcsc（10-15 min）
bash scripts/04_build_team.sh               # 编译球队（5-10 min）
bash scripts/05_install_monitor.sh          # 装监视器（2 min）
```

---

## 🎬 一键看比赛

装完后，直接：

```bash
~/run_match.sh                               # vs 默认对手 (helios-base 自对战)
~/run_match.sh -o /path/to/opponent          # vs 指定对手
```

**桌面会弹出绿色足球场窗口**（rcssmonitor），看比赛实时画面。

---

## 💡 安装过程踩坑经验（必读！）

我装这套环境踩了很多坑，全部总结如下：

### 坑 1：Ubuntu 24.04 没有 `qt5-default` 包
**症状**：`apt install qt5-default` 报"无可安装候选"
**原因**：Ubuntu 24.04 已废弃此元包
**解决**：直接装 `qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools`

### 坑 2：librcsc 在 GCC 13 下编译失败
**症状**：
- `error: 'ntohl' was not declared in this scope`
- `error: 'sizeof' to incomplete type 'sockaddr_in'`

**原因**：GCC 13 严格模式 + librcsc 头文件缺包含

**解决**：3 处修复
```bash
# 修复 1：host_address.h 用具体 include 替代前向声明
sed -i 's|^struct sockaddr_in;|#include <netinet/in.h>|' rcsc/net/host_address.h

# 修复 2：相关 cpp 文件加 arpa/inet.h
for f in rcsc/common/player_param.cpp src/rcg2txt.cpp rcsc/net/udp_socket.cpp; do
    grep -q "arpa/inet" "$f" || sed -i '/#ifdef HAVE_NETINET_IN_H/a\#include <arpa/inet.h>' "$f"
done

# 修复 3：CMake 没检测到 HAVE_NETINET_IN_H，手动开
cd build && sed -i 's|/\* #undef HAVE_NETINET_IN_H \*/|#define HAVE_NETINET_IN_H|' config.h
make -j$(nproc)
```

### 坑 3：rcssserver 装完后 `error while loading shared libraries: librcssclangparser.so.18`
**原因**：`/usr/local/lib` 不在 ldconfig 路径
**解决**：
```bash
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/rcssserver.conf
sudo ldconfig
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

### 坑 4：比赛启动后卡在 cycle 0 不动
**原因 A**：`~/.rcssserver/server.conf` 配置错误（手工改坏了）
**解决**：`rm -rf ~/.rcssserver` 让 server 重建

**原因 B**：rcssserver 启动尚未完全就绪，球队就连了上去
**解决**：start.sh 等待 "Waiting for players to connect" 出现再启队伍：
```bash
until grep -q "Waiting" /tmp/rcssserver.log 2>/dev/null; do sleep 1; done
```

### 坑 5：rcssmonitor 报 "could not connect to display"
**原因**：从 SSH/远程 shell 无法访问 X 显示
**解决**：
```bash
export DISPLAY=:0
export XAUTHORITY=$(ls /run/user/$(id -u)/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
~/rcssmonitor.AppImage
```

### 坑 6：rcssmonitor.AppImage 报 "AppImages require FUSE to run"
**解决**：`sudo apt install -y libfuse2t64 fuse`

### 坑 7：双方球队连接但比赛不开始
**原因**：`auto_mode` 默认 false
**解决**：启动 server 时显式开启：
```bash
rcssserver server::auto_mode=true
```

### 坑 8：cyrus2d-base 的 DNN 权重加载失败
**原因**：`unmark_dnn_weights.txt` 必须在 CWD（当前工作目录）
**解决**：start.sh 必须 `cd "${DIR}"` 后再启动 player

### 坑 9：本地球队和对手协议版本不同（v17 vs v18）
**现象**：对战可正常进行，但 synch_mode 下偶发卡死
**解决**：默认用非同步模式（rcssserver 默认）兼容性最好

### 坑 10：killall 偶尔留 zombie
**解决**：`killall -9 -f xxx`，等 2-3 秒，再 `pkill -9 -f xxx`

### 坑 11：Cyrus2DBase 编译报 PenaltyKickState API 错
**症状**：`cannot convert 'const PenaltyKickState' to 'const PenaltyKickState*'`
**原因**：新版 librcsc 把 `wm.penaltyKickState()` 返回类型改成引用
**解决**：
```bash
sed -i 's|wm.penaltyKickState();|\&wm.penaltyKickState();|g' src/player/bhv_penalty_kick.cpp
```

### 坑 12：Cyrus2DBase 报 `createXpmTiles` API 不存在
**解决**：注释掉那行（团队 logo 不重要）

---

## 🔧 比赛规则合规清单

| 项 | 实现 |
|---|---|
| Ubuntu 24.04 64 位 | ✅ 本脚本仅支持此系统 |
| rcssserver-19.0.x | ✅ 自动装 19.0.0 |
| 11 vs 11 | ✅ start.sh 启动 11 球员 |
| 100ms 周期 | ✅ rcssserver 默认 |
| 15 秒内全员上场 | ✅ ~3 秒完成 |
| 守门员 = 1 号 | ✅ start.sh 用 -g 标志 |
| 球员类型 ≥3 种 | ✅ 教练自动分配 7 种异构类型 |
| 单类型 ≤7 人 | ✅ 实测 ≤2 人/类 |
| 库依赖打包 | ✅ librcsc.so 已捆绑 |

---

## 🎓 训练（提升至超越 AHUTI）

详见 `docs/TRAINING.md`，三条路径：

| 路径 | 用时 | 硬件 | vs AHUTI 胜率 |
|---|---|---|---|
| C 调参 | 1-2 天 | CPU 即可 | 50-55% |
| **A DNN（推荐）** | **1-2 周** | **1 张 GPU（≥8GB）** | **55-65%** |
| B MAPPO | 2-4 周 | 2-4 张 GPU | 60-75% |

**Windows + RTX 4060 用户**：装 WSL2 + Ubuntu 24.04，CUDA 自动 passthrough。

---

## 📞 故障排查

```bash
# 服务器没起来
pgrep -f rcssserver         # 应有进程
ss -tunlp | grep ":600"     # 应监听 6000-6002

# 库找不到
ldd ~/wxxychyzz/wxxychyzz_Player | grep "not found"

# 监视器无法显示
echo $DISPLAY               # 应为 :0
echo $XAUTHORITY            # 应非空

# 重置 server 配置
rm -rf ~/.rcssserver
LD_LIBRARY_PATH=/usr/local/lib rcssserver server::help > /dev/null
```

---

## 📚 文档地图

| 文档 | 用途 |
|---|---|
| **本 README** | 快速上手 + 踩坑清单 |
| `docs/COMPLETE_GUIDE.md` | 详细 Phase 0-8 流程 |
| `docs/USAGE.md` | 日常操作（启停、批量测试、版本管理）|
| `docs/TRAINING.md` | 三条训练路径技术细节 |
| `docs/QUICK_REF.md` | 一行命令速查 |

---

## ✅ 验证安装成功

```bash
# 1. 二进制都在
ls -lh ~/wxxychyzz/{wxxychyzz_Player,wxxychyzz_Coach,start.sh,kill.sh}

# 2. 启动球队 5 秒后看进程数
~/wxxychyzz/start.sh && sleep 5
pgrep -c -f wxxychyzz_Player    # 应输出 11
~/wxxychyzz/kill.sh

# 3. 跑一场快速比赛
~/run_match.sh
# 桌面应弹出绿色场地窗口
```

如果以上 3 步都通过，恭喜，安装成功！
