# Windows 用户安装指南

## 你不能直接在 Windows 上跑 RoboCup 2D（rcssserver 仅 Linux）

你有三个选择：

## 方案 A：WSL2 + Ubuntu（推荐）⭐

可同时使用 Windows 文件系统和 Linux 仿真环境，且 RTX 4060 GPU 可直接 passthrough 给 WSL2。

### Step 1：装 WSL2

```powershell
# Windows PowerShell（管理员）
wsl --install -d Ubuntu-24.04
# 重启
```

### Step 2：进 Ubuntu 跑安装

```bash
# 把 robocup2d_setup 这个文件夹拷到 WSL2 中
# 例如把它放到 D:\robocup2d_setup
# WSL2 中访问：cd /mnt/d/robocup2d_setup

# 或直接拷贝到 Linux 内
cp -r /mnt/c/Users/luotingcheng/Desktop/robocup2d_setup ~/robocup2d_setup
cd ~/robocup2d_setup

# 一键装
sudo bash scripts/00_install_all.sh
```

### Step 3：CUDA passthrough（用于训练）

```bash
# 在 WSL2 中（Windows 端 NVIDIA driver 已装好的话，这里自动可见）
nvidia-smi
# 应输出 RTX 4060 Laptop GPU 8GB

# 装 CUDA Toolkit
sudo apt install -y nvidia-cuda-toolkit
# 或装更新版本：https://developer.nvidia.com/cuda-downloads → Linux WSL-Ubuntu

# 装 PyTorch + CUDA
pip3 install torch --index-url https://download.pytorch.org/whl/cu121
python3 -c "import torch; print('CUDA:', torch.cuda.is_available())"
# 应输出: CUDA: True
```

### Step 4：看比赛

WSL2 默认有 WSLg（自带 X11），rcssmonitor 直接弹 Windows 窗口：

```bash
~/rcssmonitor.AppImage    # Windows 桌面会出现绿色场地窗口
```

---

## 方案 B：双系统装 Ubuntu 24.04

最纯净最快，但要分区。

参考 https://ubuntu.com/tutorials/install-ubuntu-desktop

装好后照 `scripts/00_install_all.sh` 一键装。

---

## 方案 C：当前 VMware 虚拟机

你已经在用了。但虚拟机：
- 无 GPU（无法做训练，只能跑比赛）
- 性能损失 10-20%
- 主流方案

---

## 三种方案对比

| 方案 | 性能 | 训练支持 | 难度 | 推荐 |
|---|---|---|---|---|
| WSL2 | 高 | ✅ GPU 可用 | ⭐ | ⭐⭐⭐⭐⭐ |
| 双系统 | 最高 | ✅ GPU 可用 | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| VMware VM | 中 | ❌ 无 GPU | ⭐⭐ | ⭐⭐ |

---

## Windows 一键脚本（PowerShell）

把以下内容存为 `Setup-WSL2-RoboCup.ps1`，右键以管理员运行：

```powershell
# Setup-WSL2-RoboCup.ps1
# 一键装 WSL2 + Ubuntu 24.04 + CUDA + RoboCup 环境

Write-Host "[1/3] 启用 WSL2 ..." -ForegroundColor Green
wsl --install -d Ubuntu-24.04 --no-launch

Write-Host "[2/3] 等待 WSL2 启动（首次需重启）..." -ForegroundColor Yellow
Write-Host "如果未重启，请手动重启后再运行此脚本第二次"

Write-Host "[3/3] 在 WSL2 内执行 RoboCup 安装" -ForegroundColor Green
$installScript = @'
#!/bin/bash
set -e

# 拷贝 setup 包
if [ -d /mnt/c/Users/$USER/Desktop/robocup2d_setup ]; then
    cp -r /mnt/c/Users/$USER/Desktop/robocup2d_setup ~/
    cd ~/robocup2d_setup
    sudo bash scripts/00_install_all.sh
else
    echo "请先把 robocup2d_setup 放到 Windows 桌面"
fi
'@

$installScript | wsl -d Ubuntu-24.04 -- bash

Write-Host "✅ 完成！进 WSL2 用 ~/wxxychyzz/start.sh 启动球队" -ForegroundColor Green
```

---

## 训练流程（WSL2 + RTX 4060）

```bash
# 在 WSL2 内
cd ~/wxxychyzz
cat TRAINING.md           # 看完整训练手册

# 路径 A 第一步（自对战收集数据，约 8-12 小时）
nohup bash collect_selfplay.sh 3000 > collect.log 2>&1 &

# 路径 A 第二步（DNN 训练，约 24-48 小时 GPU）
cd ~/robocup2d/team/Cyrus2DBase-cyrus2d/scripts/training_unmark
python3 trainer.py
```

---

## 常见问题

### Q: WSL2 看不到 GPU
**A**: 升级 Windows NVIDIA driver 到最新版（>= 545.x），重启电脑

### Q: WSL2 网络访问不到主机
**A**: WSL2 默认是 NAT 模式，rcssserver 只 listen 127.0.0.1（自带），无问题

### Q: 文件路径中文乱码
**A**: WSL2 在 `/mnt/c/.../` 下访问 Windows 文件，UTF-8 默认支持

### Q: 我想看比赛但 WSL2 没图形界面
**A**: WSL2 自带 WSLg（Wayland gateway），任何 GUI 程序自动弹 Windows 窗口
