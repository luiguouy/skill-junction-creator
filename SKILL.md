---
name: skill-junction-creator
description: >
  扫描电脑上已安装的所有 AI Agent，自动为其 skill/rules 目录创建目录联接（Junction），
  将用户统一的 skill 仓库暴露给每个 AI Agent，实现一份 skill 多 Agent 共享。
  当用户提及"创建 junction""同步 skill""多 Agent 共享""让所有 AI 使用同一个 skill"时使用。
version: 2.0.0
---

# Skill Junction Creator（路由入口）

将统一 skill 仓库（`D:\AI_Workspace\SKILL`）通过 Windows 目录联接（Junction）映射到各 AI Agent 的 skill 目录。

本 skill 是路由入口，根据用户意图调用对应的子 skill 执行具体操作。

## 共享资源

- **Skill 仓库**：`D:\AI_Workspace\SKILL`（所有 skill 的源目录）
- **Agent 缓存**：`D:\AI_Workspace\SKILL\skill-junction-creator\agent-cache.json`
  - 记录所有已知 Agent 的 skill 路径、类型、兼容性
  - 字段：`skill_dir`（路径）、`type`（directory/data-only/file-based/extension-storage）、`compatible`（bool）、`note`（可选说明）

## 子 Skill 路径

| 子 Skill | 路径 |
|----------|------|
| sjc-sync | `D:\AI_Workspace\SKILL\skill-junction-creator\sjc-sync\SKILL.md` |
| sjc-scanner | `D:\AI_Workspace\SKILL\skill-junction-creator\sjc-scanner\SKILL.md` |

## 命令分发

| 用户指令 | 调用子 Skill | 说明 |
|----------|-------------|------|
| `同步 skill` / `创建 junction` / `同步` | **sjc-sync** | 执行 junction 增量同步 |
| `扫描 Agent` / `发现新 Agent` / `重新扫描` | **sjc-scanner** | 执行三阶段智能推断扫描 |
| `查看 Agent 缓存` / `Agent 列表` | 本 skill 直接处理 | 读取 agent-cache.json 并展示 |

### 执行规则

1. 收到用户指令后，先匹配上表，加载对应子 skill 的 SKILL.md 执行
2. "查看缓存"不需要加载子 skill，直接读取 `agent-cache.json` 展示即可
3. 子 skill 执行完毕后，如有新发现，应更新 `agent-cache.json`
