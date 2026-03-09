---
name: hr-manual-keeper
description: "强制执行部门级项目操作手册的创建与智能维护迭代。通过文件系统状态机和物理日志标记，倒逼 AI 必须查阅、建立并更新项目手册，杜绝走过场。"
---

## 核心理念 (Role)

This skill forces the strict creation and continuous maintenance of project operation manuals.
**DO NOT trust your LLM memory.** **DO NOT just say "I will update it later".** 
You MUST physically check the file system. If a gate fails, you MUST stop and fix the file.

## 工作流 (Workflow)

Complete phases in order. A later phase must not begin until the prior phase's gate passes.

### Phase 1: 强制查验与创建手册 (Enforce Manual Existence)

Trigger this phase at the beginning of any maintenance or finalization task.

1. Check if the physical manual exists.
2. If it does not exist, create `docs/Project_Operation_Manual.md` with:
   - 项目简介 (Project Overview)
   - 核心系统架构与环境变量 (Architecture & Env)
   - 常见避坑与报错处理 (Gotchas & Troubleshooting) - **(HR 经验沉淀核心区)**
   - 维护日志 (Maintenance Log)
3. **GATE (执行强校验)**: Run this bash command. If it fails, stop execution completely!

```bash
mkdir -p docs && test -f docs/Project_Operation_Manual.md || { echo "GATE FAILED: 操作手册不存在，禁止进行下一步。请先创建！"; exit 1; }
```

### Phase 2: 强制经验反思与更新 (Forced Experience Extraction)

Before starting, run:
```bash
test -f docs/Project_Operation_Manual.md || { echo "STOP: Manual missing"; exit 1; }
```

大模型极容易说“我已经更新了”但实际没动笔。我们通过强制生成一个时间戳审计文件来锁死它。

1. 回顾最近一次开发的代码变更或踩回的坑（比如配置失败、特定报错）。
2. 将这些经验**物理写入**到 `docs/Project_Operation_Manual.md` 的“常见避坑与报错处理”章节中。
3. 创建本轮维护的物理标记 (Audit Trail)，向硬盘写入一个标记文件：

```bash
mkdir -p .agents/hr_audit
# 写入包含今天日期的更新声明
echo "Manual updated for recent findings" > .agents/hr_audit/manual-updated-$(date +%Y%m%d).done
```

### Phase 3: 最终物理校验 (Final Physical Gate)

只有当硬盘上真实存在当天的 `.done` 更新标记时，本次经验沉淀任务才算合法结束。

**GATE**: 
```bash
# 检查今天是否真的生成了更新标记
ls .agents/hr_audit/manual-updated-$(date +%Y%m%d).done 2>/dev/null | wc -l | grep -q 1 || { echo "GATE FAILED: AI 没有执行实际的手册更新写入动作，抓到偷懒行为，请重新执行 Phase 2"; exit 1; }
```

Exit only when the manual exists and the physical audit dump for today is confirmed by Bash.
