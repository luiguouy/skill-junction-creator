---
name: sjc-sync
description: >
  skill-junction-creator 的子 skill：执行 junction 增量同步。
  将统一 skill 仓库中的所有 skill 通过 NTFS Junction 映射到各兼容 Agent 的 skill 目录。
  当 skill-junction-creator 路由到"同步"操作时加载此 skill。
version: 1.0.0
---

# SJC Sync（Junction 同步）

将 `D:\AI_Workspace\SKILL` 下的所有 skill 同步（创建 Junction）到各兼容 Agent 的 skill 目录。

## 执行方式

Agent **绝不应**在本地通过读取源文件夹列表并在上下文中比对来同步（极度消耗 Token）。

必须直接执行同步脚本：

```powershell
powershell -ExecutionPolicy Bypass -File "D:\AI_Workspace\SKILL\skill-junction-creator\scripts\sync_skills.ps1"
```

## 脚本行为

sync_skills.ps1 会自动完成：

1. 加载 `agent-cache.json`，筛选 `compatible=true` 且 `type=directory` 的 Agent
2. 遍历源仓库 `D:\AI_Workspace\SKILL` 下的所有 skill 目录
3. 对每个 Agent：创建缺失的 Junction、清理已删除 skill 的残留 Junction、保留已有的
4. 输出 Markdown 格式的同步报告（新增/删除/保留/冲突）

## 输出处理

脚本执行完成后，直接将终端输出原样或简要总结展示给用户即可，无需再做额外的目录读取分析操作。

## 注意事项

- 脚本只处理兼容的目录型 Agent（`compatible=true, type=directory`）
- Junction 创建失败时会输出错误信息，不影响其他 Agent 的同步
- 如果 `agent-cache.json` 不存在，脚本会报错退出
