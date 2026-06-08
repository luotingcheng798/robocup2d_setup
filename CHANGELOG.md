# Changelog

## 1.1.0 (2026-06-08)
- `scripts/00_install_all.sh` 增加可配置项输出，支持自定义工作目录、队名与版本参数。
- `scripts/02_build_rcssserver.sh`/`03_build_librcsc.sh`/`04_build_team.sh`/`05_install_monitor.sh`/`06_run_match.sh`/`07_test_match.sh` 参数化目录与名称，减少环境绑定。
- `scripts/06_run_match.sh`/`07_test_match.sh` 用 `ROBOCUP2D_*` 环境变量替代固定 `wxxychyzz_*` 名称。
- README/文档准备：后续版本会继续补全版本记录与部署路径建议。
