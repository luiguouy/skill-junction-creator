---
name: sjc-scanner
description: >
  skill-junction-creator 的子 skill：三阶段智能推断扫描，发现新安装的 AI Agent 并自动定位其 skill 目录。
  当 skill-junction-creator 路由到"扫描 Agent""发现新 Agent""重新扫描"操作时加载此 skill。
version: 1.0.0
---

# SJC Scanner（Agent 智能扫描）

通过三阶段扫描发现新安装的 AI Agent，并自动推断其 skill 目录位置。

## 共享资源

- **Agent 缓存**：`D:\AI_Workspace\SKILL\skill-junction-creator\agent-cache.json`

## 缓存优先策略

1. 读取 `agent-cache.json`
2. 对缓存中每个 Agent，用 `Test-Path` 验证 `skill_dir` 是否仍存在（极低开销）
3. 有效缓存直接使用，无效条目标记待更新
4. 仅对缓存中没有的 Agent 执行完整扫描

## 三阶段扫描脚本

将以下内容保存为 `.ps1` 文件后执行（通过 `powershell -ExecutionPolicy Bypass -File`）：

```powershell
# ============================================================
# 阶段 1：白名单快速通道（检查已知路径，跳过缓存中已有的）
# ============================================================
$knownPaths = [ordered]@{
    'QoderWork'   = "$env:USERPROFILE\.qoderworkcn\skills"
    'WorkBuddy'   = "$env:USERPROFILE\.workbuddy\skills"
    'Marvis'      = "$env:APPDATA\Tencent\Marvis\User\default_user\skills\custom"
    'Copilot'     = "$env:USERPROFILE\.copilot"
    'Antigravity' = "$env:USERPROFILE\.gemini\config\skills"
    'QoderCN'     = "$env:USERPROFILE\.agents\skills"
}

$cache = Get-Content 'D:\AI_Workspace\SKILL\skill-junction-creator\agent-cache.json' | ConvertFrom-Json
$discovered = @{}

foreach ($name in $knownPaths.Keys) {
    if ($cache.known_agents.PSObject.Properties.Name -contains $name) { continue }
    $path = $knownPaths[$name]
    if (Test-Path $path) {
        $discovered[$name] = $path
        Write-Host "WHITELIST|$name|$path"
    }
}

# ============================================================
# 阶段 2：注册表扫描（始终执行，使用通用 AI 关键词匹配）
# ============================================================
$aiKeywords = 'AI|Copilot|Assistant|Code|Cursor|Windsurf|Trae|Continue|Cline|Roo|Codeium|Lingma|Augment|Qoder|Gemini|Antigravity|Marvis|WorkBuddy|Doubao|豆包|Tabnine|Supermaven|Sourcegraph|Aider|Codex|Claude|Devin|Replit|Bolt|v0|Lovable|Pieces|Amazon\sQ|JetBrains\sAI'

$uninstall = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$regApps = @{}
Get-ItemProperty $uninstall -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match $aiKeywords } |
    Where-Object {
        $dn = $_.DisplayName
        -not ($cache.known_agents.PSObject.Properties.Name | Where-Object { $dn -match $_ })
    } |
    ForEach-Object {
        $name = $_.DisplayName -replace '\s+', ''
        $installLoc = $_.InstallLocation
        if (-not $installLoc) { $installLoc = '(unknown)' }
        $regApps[$name] = $installLoc
        Write-Host "REG|$name|$installLoc"
    }

# ============================================================
# 阶段 3：智能推断 skill 目录（对每个新发现的 Agent）
# ============================================================
function Find-SkillDir {
    param([string]$AgentName, [string]$InstallLocation)

    $cleanName = $AgentName -replace '[^a-zA-Z0-9]', ''
    $lowerName = $cleanName.ToLower()

    $configRoots = @(
        "$env:USERPROFILE\.$lowerName",
        "$env:USERPROFILE\.$lowerName-cn",
        "$env:APPDATA\$cleanName",
        "$env:APPDATA\$AgentName",
        "$env:LOCALAPPDATA\$cleanName",
        "$env:LOCALAPPDATA\$AgentName"
    )

    $skillDirNames = @('skills', 'rules', 'prompts', 'custom', '.agents')
    $skillFileNames = @('SKILL.md', '.skill.md', 'skill.md')

    foreach ($root in $configRoots) {
        if (-not (Test-Path $root)) { continue }

        # 策略 A：查找名为 skills/rules/custom 的子目录（深度 1-3）
        foreach ($sd in $skillDirNames) {
            $found = Get-ChildItem -Path $root -Filter $sd -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                return @{ Path = $found.FullName; Method = 'name-match' }
            }
        }

        # 策略 B：查找包含 SKILL.md 的目录（深度 3）
        foreach ($sf in $skillFileNames) {
            $found = Get-ChildItem -Path $root -Filter $sf -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                return @{ Path = $found.DirectoryName; Method = 'file-match' }
            }
        }

        # 策略 C：配置根目录本身就是 skill 目录
        $baseName = Split-Path $root -Leaf
        if ($baseName -match '^(skills|rules|prompts|custom)$') {
            return @{ Path = $root; Method = 'root-match' }
        }
    }

    return $null
}

function Classify-Type {
    param([string]$DirPath)
    $hasSkillMd = Get-ChildItem -Path $DirPath -Filter 'SKILL.md' -Recurse -Depth 1 -ErrorAction SilentlyContinue
    if ($hasSkillMd) { return 'directory' }

    $hasSubDirs = (Get-ChildItem -Path $DirPath -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
    $hasFiles = (Get-ChildItem -Path $DirPath -File -ErrorAction SilentlyContinue | Measure-Object).Count

    if ($hasSubDirs -gt 0) { return 'directory' }
    if ($hasFiles -gt 5) { return 'data-only' }
    return 'unknown'
}

foreach ($appName in $regApps.Keys) {
    if ($discovered.ContainsKey($appName)) { continue }

    $result = Find-SkillDir -AgentName $appName -InstallLocation $regApps[$appName]
    if ($result) {
        $dirType = Classify-Type -DirPath $result.Path
        $compatible = $dirType -ne 'data-only'
        $discovered[$appName] = $result.Path
        Write-Host "INFER|$appName|$($result.Path)|$dirType|$($result.Method)|$compatible"
    } else {
        Write-Host "NO_SKILL_DIR|$appName|$($regApps[$appName])"
    }
}

Write-Host "SCAN_COMPLETE|discovered=$($discovered.Count)|registry=$($regApps.Count)"
```

## 输出格式

| 前缀 | 含义 |
|------|------|
| `WHITELIST\|name\|path` | 白名单快速通道命中 |
| `REG\|name\|installLocation` | 注册表发现的新 Agent |
| `INFER\|name\|skillDir\|type\|method\|compatible` | 智能推断成功 |
| `NO_SKILL_DIR\|name\|installLocation` | 未找到 skill 目录，需人工确认 |
| `SCAN_COMPLETE\|discovered=N\|registry=M` | 扫描完成汇总 |

**推断策略优先级：**
1. `name-match`：配置目录中找到名为 `skills`/`rules`/`custom` 的子目录
2. `file-match`：配置目录中找到包含 `SKILL.md` 的目录
3. `root-match`：配置根目录本身就是 skill 目录

## 扫描后处理

1. 将 `INFER` 结果写入 `agent-cache.json`（新增条目，更新 `last_scan`）
2. 对 `NO_SKILL_DIR` 的 Agent，提示用户手动指定路径
3. 用户说"重新扫描所有 Agent"时，忽略缓存，执行完整扫描并重建缓存
