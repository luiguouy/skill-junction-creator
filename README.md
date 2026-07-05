# Skill Junction Creator 🔗

这是一个用于在多个 AI 编程助手（如 **QoderWork**, **WorkBuddy**, **Marvis**, **Copilot**, **Antigravity** 等）之间**共享和同步自定义 AI 技能（Skills / Rules）**的自动化工具。

它通过 Windows 的 **NTFS 目录联接（Directory Junction）** 技术，实现“一份 Skill，多端共享”——您只需在统一的本地文件夹（如 `D:\AI_Workspace\SKILL`）中维护 Skill 源码，所有 Agent 均可实时读取，且修改立即生效。

---

## 🌟 核心特性
- **零拷贝，省空间**：利用 NTFS Junction，文件只在源目录占用物理空间，其他 Agent 目录下仅是底层重定向快捷方式。
- **自动增量同步**：新增的 Skill 文件夹会自动为所有兼容 Agent 创建 Junction；已删除 of Skill 自动清理过期 Junction。
- **极致性能与省 Token**：通过内置 PowerShell 脚本在本地极速完成扫描与比对，AI 引擎仅需调用一次命令，避免将大量目录树读入 AI 上下文，节省 Token 消耗。
- **防止误删保护**：自动清理过期 Junction 时，脚本会严格校验其属性是否为 Junction，绝不会损坏或覆盖您原有的普通本地目录。

---

## 📂 项目结构
```text
skill-junction-creator/
├── SKILL.md                 # 供 AI Agent 识别和加载此技能的说明文件
├── agent-cache.json         # 记录和配置各 Agent 的技能目录路径与兼容状态
├── README.md                # 本说明文档
└── scripts/
    └── sync_skills.ps1      # 自动扫描与创建 Junction 的本地 PowerShell 脚本
```

---

## ⚙️ 快速开始

### 1. 准备您的 Skill 仓库
在您的电脑上创建一个统一存放 Skill 的文件夹（例如 `D:\AI_Workspace\SKILL`），并在此文件夹下放置您的各个自定义技能：
```text
D:\AI_Workspace\SKILL/
├── skill-junction-creator/      # 本仓库
├── project-structure-tracker/   # 您的其他自定义技能
└── my-new-awesome-skill/        # 您的其他自定义技能
```

### 2. 配置 Agent 路径 (`agent-cache.json`)
根据您电脑上已安装的 AI Agent，在 `agent-cache.json` 中配置或确认它们的技能扫描路径：
```json
{
  "known_agents": {
    "QoderWork": {
      "skill_dir": "C:/Users/您的用户名/.qoderworkcn/skills",
      "type": "directory",
      "compatible": true
    },
    "WorkBuddy": {
      "skill_dir": "C:/Users/您的用户名/.workbuddy/skills",
      "type": "directory",
      "compatible": true
    },
    "Antigravity": {
      "skill_dir": "C:/Users/您的用户名/.gemini/config/skills",
      "type": "directory",
      "compatible": true
    }
  }
}
```

### 3. 让您的 Agent 加载本技能
为了让 Agent 能够“学会”自动同步，需要手动为本技能创建第一个 Junction（或者直接把本技能复制到 Agent 的技能目录下）：

**以 Antigravity 为例 (以管理员权限运行 PowerShell)：**
```powershell
New-Item -ItemType Junction -Path "C:\Users\您的用户名\.gemini\config\skills\skill-junction-creator" -Value "D:\AI_Workspace\SKILL\skill-junction-creator"
```

---

## 🚀 使用方法

本技能提供了两种同步操作方式：

### 方式一：交给 AI 智能同步 (推荐 🤖)
一旦 Agent 成功加载了本技能，在日常对话中您只需要对 AI 说一句：
> **“同步 skill”** 或 **“同步”**

Agent 将自动识别该指令，在后台静默执行 `scripts/sync_skills.ps1` 脚本，并在对话框中为您呈现清晰的 Markdown 同步报告，展示每一个 Agent 的同步状态。

### 方式二：本地手动执行 (💻)
您也可以不通过 AI，自己在命令行中直接运行同步脚本：
```powershell
powershell -ExecutionPolicy Bypass -File "D:\AI_Workspace\SKILL\skill-junction-creator\scripts\sync_skills.ps1"
```
运行后会在控制台输出每个 Agent 目录下的增删改状态。

---

## 📊 同步报告说明
同步报告将包含以下几种状态标识：
- 🟢 **`[新增]`** **`SkillName`** - 发现新 Skill 并已成功为该 Agent 创建 Junction 联接。
- 🟡 **`[删除]`** **`SkillName`** - 该 Skill 已在源目录被您删除，Junction 已自动被安全清理。
- ⚪ **`[保留]`** `SkillName` - 该 Skill 已是最新状态，无须改动。
- 🔴 **`[失败]`** **`SkillName`** - 创建或删除联接失败（通常由于权限不足，请使用管理员权限重新运行）。
- ⚠️ **`[冲突]`** `SkillName` - 目标 Agent 目录中已存在同名的真实文件夹，脚本为了保护数据不会进行覆盖。
