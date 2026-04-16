# Changelog

## v0.1.1 - 2026-04-16

### 新增

- 无

### 修复

- 无

### 变更

- 调整 Windows 安装包右键菜单命令配置，优化从资源管理器触发分析时的调用方式。
- 项目版本从 `0.1.0` 升级为 `0.1.1`。

详细发布说明：[docs/release-notes/v0.1.1.md](docs/release-notes/v0.1.1.md)

## v0.1.0 - 2026-04-16

### 新增

- 首次发布城市分层统计工具，支持统计 Excel 和 CSV 文件中“归属地”列的城市分层数量及占比。
- 支持自定义归属地列名、自定义 `city_tiers.yaml` 分层配置，以及 CSV/XLSX 格式的逐行明细导出。
- 提供 Windows 安装包、macOS 安装包和 macOS Finder Quick Action 安装流程。
- 发布流程支持构建并发布 Windows 与 macOS arm64 安装包。

### 修复

- macOS 卸载流程会尝试删除当前用户的 Finder Quick Action、命令入口、安装目录和安装记录。
- Windows 卸载流程会清理安装时加入当前用户 `PATH` 的目录。

### 变更

- 项目加入 pytest 单元测试，覆盖核心解析、匹配、统计和导出逻辑。

详细发布说明：[docs/release-notes/v0.1.0.md](docs/release-notes/v0.1.0.md)
