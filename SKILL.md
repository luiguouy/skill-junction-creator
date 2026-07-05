---
name: skill-junction-creator
description: >
  扫描电脑上已安装的所有 AI Agent，自动为其 skill/rules 目录创建目录联接（Junction），
  将用户统一的 skill 仓库暴露给每个 AI Agent，实现一份 skill 多 Agent 共享。
  当用户提及"创建 junction""同步 skill""多 Agent 共享""让所有 AI 使用同一个 skill"时使用。
version: 1.2.1
---

# Skill Junction Creator

将用户统一 skill 仓库（默认 `D:\AI_Workspace\SKILL`）通过 Windows 目录联接（Junction）
映射到各个 AI Agent 的 skill 目录，使同一份 skill 被所有 Agent 共享。

## 核心概念

- **Junction 不占磁盘空间**：它只是文件系统的路径重定向，实际数据始终只在源目录
- **单向映射**：Agent 通过 junction 读取源目录 of skill，用户在源目录编辑后立即生效
- **缓存优先**：已确认的 Agent 路径记录在 `agent-cache.json` 中，避免重复扫描浪费 token

## 缓存机制

### 缓存文件

位置：`{skill_dir}/agent-cache.json`（即 `D:\AI_Workspace\SKILL\skill-junction-creator\agent-cache.json`）

格式：

```json
{
  "last_scan": "ISO-8601 时间戳",
  "known_agents": {
    "AgentName": {
      "skill_dir": "该 Agent 的 skill 存放路径（正斜杠）",
      "type": "directory | data-only | file-based | extension-storage",
      "compatible": true/false,
      "note": "不兼容时的原因（可选）",
      "confirmed_at": "ISO-8601 时间戳"
    }
  },
  "pending_agents": []
}
```

字段说明：

| 字段 | 含义 |
|------|------|
| `skill_dir` | 该 Agent 的 skill 存放路径 |
| `type` | `directory`（目录型 skill）/ `data-only`（纯数据）/ `file-based`（文件型如 .mdc）/ `extension-storage`（IDE 扩展） |
| `compatible` | 是否支持 junction 映射 |
| `note` | 不兼容时的原因说明 |
| `confirmed_at` | 该条目最后确认时间 |

### 执行策略（缓存优先）

1. **读取缓存**：加载 `agent-cache.json`
2. **验证缓存**：对缓存中每个 Agent，快速检查其 `skill_dir` 是否仍然存在（一个 `Test-Path` 调用即可，极低开销）
3. **直接使用有效缓存**：验证通过的 Agent 直接进入 junction 创建流程，无需重新扫描
4. **增量扫描**：仅对缓存中没有的 Agent 执行完整扫描（见下方"扫描未知 Agent"）
5. **更新缓存**：将新发现的 Agent 写入缓存，更新 `last_scan` 时间戳

这样，日常执行只需 N 次 `Test-Path`（N = 已知 Agent 数量），而非完整扫描。

### 扫描未知 Agent

当需要发现新安装的 Agent 时，执行以下检测（通过 `.ps1` 文件执行）：

```powershell
# 保存为 scan_new.ps1 后执行
# 已知 Agent 的候选路径（用于发现缓存中未记录的 Agent）
$candidates = [ordered]@{
    # === 已确认的 Agent（按兼容性分组） ===
    # 兼容 - 目录型 skill 系统
    'QoderWork'   = "$env:USERPROFILE\.qoderworkcn\skills"
    'WorkBuddy'   = "$env:USERPROFILE\.workbuddy\skills"
    'Marvis'      = "$env:APPDATA\Tencent\Marvis\User\default_user\skills\custom"
    'Copilot'     = "$env:USERPROFILE\.copilot"
    'Antigravity' = "$env:USERPROFILE\.gemini\config\skills"

    # 待发现 - 可能兼容但尚未确认
    'Cursor'      = "$env:USERPROFILE\.cursor\rules"
    'Windsurf'    = "$env:USERPROFILE\.windsurf\rules"
    'Trae'        = "$env:USERPROFILE\.trae\rules"
    'Continue'    = "$env:USERPROFILE\.continue"
    'Cline'       = "$env:USERPROFILE\.cline"
    'Roo-Cline'   = "$env:USERPROFILE\.roo-cline"
    'Codeium'     = "$env:USERPROFILE\.codeium"
    'Lingma'      = "$env:USERPROFILE\.lingma"
    'Augment'     = "$env:USERPROFILE\.augment"

    # === 已确认不兼容 ===
    'Doubao'      = "$env:USERPROFILE\.doubao"
}

# 排除缓存中已有的
$cache = Get-Content '{skill_dir}/agent-cache.json' | ConvertFrom-Json
$newFound = @()

foreach ($name in $candidates.Keys) {
    if ($cache.known_agents.PSObject.Properties.Name -contains $name) { continue }
    $path = $candidates[$name]
    if (Test-Path $path) {
        Write-Host "NEW|$name|$path"
        $newFound += $name
    }
}

# 注册表兜底：发现完全未知的 Agent
if ($newFound.Count -eq 0) {
    $uninstall = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $known = $cache.known_agents.PSObject.Properties.Name -join '|'
    Get-ItemProperty $uninstall -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'Cursor|Windsurf|Trae|Continue|Cline|Codeium|Copilot|Lingma|Augment|Qoder|Antigravity|Doubao|豆包|WorkBuddy|Marvis' } |
        Where-Object { -not ($_.DisplayName -match $known) } |
        ForEach-Object { Write-Host "REG|$($_.DisplayName)|$($_.InstallLocation)" }
}
```

发现新 Agent 后，判断其 `skill_dir` 类型（目录型 / 文件型 / 纯数据），写入缓存。

### 强制全量扫描

用户说"重新扫描所有 Agent"或"刷新 Agent 列表"时，忽略缓存，执行完整扫描并重建缓存。

## 完整执行流程

### 第一步：定位同步脚本并执行
当用户指示“同步 skill”或“创建 junction”时，Agent **绝不应**在本地通过读取源文件夹所有列表并在上下文中比对来同步（这极度消耗 Token）。

Agent 必须直接使用 `run_command` 工具，在 PowerShell 中执行以下命令以完成本地增量同步：
```powershell
powershell -ExecutionPolicy Bypass -File "D:\AI_Workspace\SKILL\skill-junction-creator\scripts\sync_skills.ps1"
```

### 第二步：输出报告
脚本执行完成后，Agent 接收到终端输出，直接将输出结果原样或简要总结展示给用户即可，无需再做额外的目录读取分析操作。

## 快速命令

| 用户指令 | 行为 |
|----------|------|
| `创建 junction` / `同步 skill` / `同步` | 直接在 PowerShell 中运行 `sync_skills.ps1` 脚本，显示同步结果 |
| `查看 Agent 缓存` | 读取并展示 `agent-cache.json` 的内容 |
