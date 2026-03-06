# ✝️ Christian Court 模式（基督教价值观朝廷）

本模式在原有“朝廷多 Agent”结构上，强化以下价值：
- 敬畏真理（事实优先）
- 爱人如己（尊重沟通）
- 谦卑服事（及时纠错）
- 忠心管家（成本与安全）
- 公义怜悯（合规与伦理）

## 角色映射（兼容原 ID）
- `main` 司礼监（总管）
- `bingbu` 工匠部（技术与工程）
- `hubu` 管家部（财务与资源）
- `libu` 见证部（品牌与传播）
- `gongbu` 守望部（运维与安全）
- `libu2` 同工部（项目与协作）
- `xingbu` 真理部（法务与伦理）

## 一键升级（Linux）

在项目目录执行：

```bash
bash ./upgrade_christian_court.sh
```

或直接从 GitHub 下载单脚本并执行（无需先 clone 仓库）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zYamro/boluobobo-ai-court-tutorial/main/upgrade_christian_court.sh)
```

可选参数：

```bash
bash ./upgrade_christian_court.sh --workspace /home/ubuntu/clawd --config /home/ubuntu/.clawdbot/clawdbot.json
```

非交互模式（用于 CI/自动化）：

```bash
bash ./upgrade_christian_court.sh --non-interactive
```

## 升级脚本会做什么
- 自动备份旧配置与关键工作区文件（`SOUL.md/IDENTITY.md/HEARTBEAT.md/USER.md`）。
- 将工作区更新为 Christian Court 模板（SOUL、IDENTITY、HEARTBEAT）。
- 以“兼容原 ID”的方式更新 `clawdbot.json`，尽量保留你已有模型提供商与 Discord token。
- 将 `allowBots` 打开，便于多 Agent 协作。
- 提供 CLI 交互式 Discord Token 配置（支持逐个账号更新）。
- 脚本内置模板，可直接通过单脚本 `curl` 方式运行。

## 升级后检查

```bash
systemctl --user restart clawdbot-gateway
systemctl --user status clawdbot-gateway
```

建议在 Discord 中逐个 @各部门 Bot 测试回复。
