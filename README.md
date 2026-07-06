# Skill Junction Creator 🔗

这是一个用于在多个 AI 编程助手（如 **QoderWork**, **WorkBuddy**, **Marvis**, **Copilot**, **Antigravity**, **Qoder CN** 等）之间**共享和同步自定义 AI 技能（Skills / Rules）**的自动化工具。

它通过 Windows 的 **NTFS 目录联接（Directory Junction）** 技术，实现"一份 Skill，多端共享"——您只需在统一的本地文件夹（如 `D:\AI_Workspace\SKILL`）中维护 Skill 源码，所有 Agent 均可实时读取，且修改立即生效。

---

## 🌟 核心特性
- **零拷贝，省空间**：利用 NTFS Junction，文件只在源目录占用物理空间，其他 Agent 目录下仅是底层重定向快捷方式。
- **自动增量同步**：新增的 Skill 文件夹会自动为所有兼容 Agent 创建 Junction；已删除的 Skill 自动清理过期 Junction。
- **模块化架构，极致省 Token**：主 skill 仅作为路由入口（~37 行），按需加载子 skill——同步操作仅加载 `sjc-sync`，扫描操作仅加载 `sjc-scanner`，避免一次性加载全部逻辑。
- **智能推断新 Agent**：内置三阶段扫描引擎，通过注册表 + 常见配置路径自动发现新安装的 AI Agent，并智能推断其 skill 目录位置，无需手动维护白名单。
- **防止误删保护**：自动清理过期 Junction 时，脚本会严格校验其属性是否为 Junction，绝不会损坏或覆盖您原有的普通本地目录。

---

## 📂 项目结构
```text
D:\AI_Workspace\SKILL/
├── skill-junction-creator/          # 本仓库（路由入口）
│   ├── SKILL.md                     # 路由入口：命令分发与共享资源说明
│   ├── agent-cache.json             # 记录和配置各 Agent 的技能目录路径与兼容状态
│   ├── README.md                    # 本说明文档
│   └── scripts/
│       └── sync_skills.ps1          # 自动扫描与创建 Junction 的 PowerShell 脚本
├── sjc-sync/                        # 子 skill：Junction 增量同步
│   └── SKILL.md                     # 同步执行指令
├── sjc-scanner/                     # 子 skill：智能 Agent 扫描
│   └── SKILL.md                     # 三阶段智能推断扫描逻辑
├── project-structure-tracker/       # 您的其他自定义技能
└── my-new-awesome-skill/            # 您的其他自定义技能
```

---

## 🧩 模块化设计

本工具采用 **路由 + 子 skill** 的模块化架构：

| 模块 | 职责 | 何时加载 |
|------|------|----------|
| **skill-junction-creator** | 路由入口，命令分发，缓存查看 | 用户提及"同步""扫描""junction"等关键词时 |
| **sjc-sync** | 执行 junction 增量同步 | 用户说"同步 skill""创建 junction"时 |
| **sjc-scanner** | 三阶段智能扫描，发现新 Agent | 用户说"扫描 Agent""发现新 Agent""重新扫描"时 |

这样设计的好处是：日常最常用的"同步"操作只需加载路由 + sjc-sync（约 79 行），而非完整加载全部 250+ 行逻辑，显著节省 Token 消耗。

---

## ⚙️ 快速开始

### 1. 准备您的 Skill 仓库
在您的电脑上创建一个统一存放 Skill 的文件夹（例如 `D:\AI_Workspace\SKILL`），并在此文件夹下放置您的各个自定义技能：
```text
D:\AI_Workspace\SKILL/
├── skill-junction-creator/      # 本仓库
├── sjc-sync/                    # 子 skill：同步
├── sjc-scanner/                 # 子 skill：扫描
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
    },
    "QoderCN": {
      "skill_dir": "C:/Users/您的用户名/.agents/skills",
      "type": "directory",
      "compatible": true
    }
  }
}
```

> 💡 **提示**：您也可以让 Agent 执行"扫描 Agent"来自动发现新安装的 AI 助手并推断其 skill 目录，无需手动编辑此文件。

### 3. 让您的 Agent 加载本技能
为了让 Agent 能够"学会"自动同步，需要手动为本技能（及其子 skill）创建 Junction（或者直接把技能文件夹复制到 Agent 的技能目录下）：

**以 Antigravity 为例 (以管理员权限运行 PowerShell)：**
```powershell
New-Item -ItemType Junction -Path "C:\Users\您的用户名\.gemini\config\skills\skill-junction-creator" -Value "D:\AI_Workspace\SKILL\skill-junction-creator"
New-Item -ItemType Junction -Path "C:\Users\您的用户名\.gemini\config\skills\sjc-sync" -Value "D:\AI_Workspace\SKILL\sjc-sync"
New-Item -ItemType Junction -Path "C:\Users\您的用户名\.gemini\config\skills\sjc-scanner" -Value "D:\AI_Workspace\SKILL\sjc-scanner"
```

---

## 🚀 使用方法

### 方式一：交给 AI 智能同步 (推荐 🤖)
一旦 Agent 成功加载了本技能，在日常对话中您只需要对 AI 说一句：
> **"同步 skill"** 或 **"同步"**

Agent 将自动加载 `sjc-sync` 子 skill，在后台静默执行 `scripts/sync_skills.ps1` 脚本，并在对话框中为您呈现清晰的 Markdown 同步报告。

### 方式二：智能扫描新 Agent (🔍)
当您安装了新的 AI Agent，只需说：
> **"扫描 Agent"** 或 **"重新扫描"**

Agent 将加载 `sjc-scanner` 子 skill，执行三阶段智能扫描：
1. **白名单快速通道** — 检查已知 Agent 的常见路径
2. **注册表扫描** — 使用通用 AI 关键词在系统注册表中搜索新安装的 Agent
3. **智能推断** — 自动在 `~/.{agent}/`、`%APPDATA%\{Agent}\` 等位置搜索 skill 目录

### 方式三：本地手动执行 (💻)
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
