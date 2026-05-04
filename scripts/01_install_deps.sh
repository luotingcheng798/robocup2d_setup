#!/bin/bash
# Phase 1: 安装系统依赖
# 需要 sudo

set -e

echo "[Phase 1/5] 安装系统依赖..."

apt update

# 编译工具链
apt install -y gcc g++ make cmake git wget curl \
    autoconf automake libtool pkg-config

# 构建依赖
apt install -y \
    libboost-all-dev libboost-system-dev libboost-filesystem-dev \
    libboost-program-options-dev \
    flex bison libfl-dev \
    zlib1g-dev libssl-dev \
    libxt-dev libxrender-dev \
    libfontconfig1-dev libfreetype6-dev \
    libjpeg-dev libpng-dev libtiff-dev \
    qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
    libeigen3-dev \
    libfuse2t64 fuse

echo "[Phase 1/5] 依赖安装完成"
gcc --version | head -1
cmake --version | head -1
