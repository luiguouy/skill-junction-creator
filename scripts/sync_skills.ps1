# D:\AI_Workspace\SKILL\skill-junction-creator\scripts\sync_skills.ps1

$SkillDir = Split-Path -Parent $PSScriptRoot
$SourceDir = Split-Path -Parent $SkillDir
$CacheFile = Join-Path $SkillDir "agent-cache.json"

if (-not (Test-Path $CacheFile)) {
    Write-Error "Cache file not found at: $CacheFile"
    exit 1
}

# 1. 加载缓存
$Cache = Get-Content $CacheFile -Raw | ConvertFrom-Json
$KnownAgents = $Cache.known_agents

# 2. 获取源目录下所有的顶层 Skill 文件夹
$SourceSkills = Get-ChildItem -Path $SourceDir -Directory | Where-Object { $_.Name -ne ".git" }
$SourceSkillNames = [System.Collections.ArrayList]@($SourceSkills.Name)

# 3. 发现各顶层 Skill 内部的子 Skill（含 SKILL.md 的子目录，排除 scripts 等工具目录）
$SubSkills = @()
foreach ($Skill in $SourceSkills) {
    $subDirs = Get-ChildItem -Path $Skill.FullName -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "scripts" -and (Test-Path (Join-Path $_.FullName "SKILL.md")) }
    foreach ($sub in $subDirs) {
        $SubSkills += [PSCustomObject]@{
            Name     = $sub.Name
            FullName = $sub.FullName
            Parent   = $Skill.Name
        }
        if ($SourceSkillNames -notcontains $sub.Name) {
            [void]$SourceSkillNames.Add($sub.Name)
        }
    }
}

Write-Host "### 🔄 Skill 同步报告"
Write-Host "源仓库: ``$SourceDir``"
Write-Host ""

# 遍历每一个兼容的 Agent
foreach ($AgentName in $KnownAgents.PSObject.Properties.Name) {
    $Agent = $KnownAgents.$AgentName
    
    # 仅处理兼容的目录型 Agent
    if ($Agent.compatible -ne $true -or $Agent.type -ne "directory") {
        continue
    }

    $TargetDir = $Agent.skill_dir
    if (-not (Test-Path $TargetDir)) {
        Write-Host "#### ❌ $AgentName"
        Write-Host "- 目录不存在或无法访问: ``$TargetDir``"
        Write-Host ""
        continue
    }

    Write-Host "#### 🤖 $AgentName"
    
    # 获取目标目录下现有的所有项
    $TargetItems = Get-ChildItem -Path $TargetDir -Force
    $TargetSkillNames = $TargetItems.Name

    # 记录该 Agent 下所有 Skill 的同步状态
    $StatusList = @()

    # 4. 增量创建：顶层 Skill（源目录有，但目标目录没有的）
    $CreatedNames = @()
    foreach ($Skill in $SourceSkills) {
        $TargetPath = Join-Path $TargetDir $Skill.Name
        if (-not (Test-Path $TargetPath)) {
            try {
                New-Item -ItemType Junction -Path $TargetPath -Value $Skill.FullName -ErrorAction Stop | Out-Null
                $StatusList += "- 🟢 **[新增]** **$($Skill.Name)**: 联接创建成功"
                $CreatedNames += $Skill.Name
            } catch {
                $StatusList += "- 🔴 **[新增]** **$($Skill.Name)**: 联接创建失败 ($($_.Exception.Message))"
            }
        }
    }

    # 5. 增量创建：子 Skill（父 Skill 内部的独立子 skill）
    foreach ($Sub in $SubSkills) {
        $TargetPath = Join-Path $TargetDir $Sub.Name
        if (-not (Test-Path $TargetPath)) {
            try {
                New-Item -ItemType Junction -Path $TargetPath -Value $Sub.FullName -ErrorAction Stop | Out-Null
                $StatusList += "- 🟢 **[新增]** **$($Sub.Name)** (子 skill ← $($Sub.Parent)): 联接创建成功"
                $CreatedNames += $Sub.Name
            } catch {
                $StatusList += "- 🔴 **[新增]** **$($Sub.Name)** (子 skill ← $($Sub.Parent)): 联接创建失败 ($($_.Exception.Message))"
            }
        }
    }

    # 6. 清理已删除的 Skill：目标目录有（且是 Junction/重解析点），但源目录已经没有了
    foreach ($Item in $TargetItems) {
        # 确保只清理不是源目录 Skill 的项，且必须是 Link 或 ReparsePoint (防止误删用户自己创建的普通目录)
        if ($SourceSkillNames -notcontains $Item.Name) {
            # 检查是否为目录联接 (Junction/ReparsePoint)
            if ($Item.Attributes -match "ReparsePoint") {
                try {
                    Remove-Item -Path $Item.FullName -Force -ErrorAction Stop
                    $StatusList += "- 🟡 **[删除]** **$($Item.Name)**: 联接已自动清理"
                } catch {
                    $StatusList += "- 🔴 **[删除]** **$($Item.Name)**: 联接清理失败 ($($_.Exception.Message))"
                }
            }
        }
    }

    # 7. 保留未改变的 Skill：源目录有且目标目录已存在的（跳过本次新创建的，避免重复报告）
    foreach ($SkillName in $SourceSkillNames) {
        if ($CreatedNames -contains $SkillName) { continue }
        $TargetPath = Join-Path $TargetDir $SkillName
        if (Test-Path $TargetPath) {
            # 再次检查是否为 Junction 且指向正确
            $Item = Get-Item -Path $TargetPath
            if ($Item.Attributes -match "ReparsePoint") {
                $StatusList += "- ⚪ [保留] ${SkillName}: 已是最新"
            } else {
                $StatusList += "- ⚠️ [冲突] ${SkillName}: 目标路径存在同名普通目录，未做覆盖"
            }
        }
    }

    # 输出该 Agent 的同步状态
    if ($StatusList.Count -eq 0) {
        Write-Host "- 没有可同步的 Skill。"
    } else {
        # 排序输出，方便阅读
        $StatusList | Sort-Object | ForEach-Object { Write-Host $_ }
    }
    Write-Host ""
}
