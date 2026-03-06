#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates/christian-court"
HAS_TEMPLATE_DIR=0

CONFIG_FILE="${HOME}/.clawdbot/clawdbot.json"
WORKSPACE="${HOME}/clawd"

DRY_RUN=0
SKIP_DEPS=0
WORKSPACE_EXPLICIT=0
NON_INTERACTIVE=0

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  cat <<'EOF'
Christian Court 一键升级脚本（Linux）

用法:
  bash upgrade_christian_court.sh [选项]

选项:
  --workspace <path>   指定工作区目录（默认: ~/clawd）
  --config <path>      指定 clawdbot 配置文件（默认: ~/.clawdbot/clawdbot.json）
  --skip-deps          跳过依赖安装（jq）
  --non-interactive    跳过交互式 Discord Token 配置
  --dry-run            仅打印动作，不落盘修改
  -h, --help           显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      [[ $# -lt 2 ]] && { log_err "--workspace 需要参数"; exit 1; }
      WORKSPACE="$2"
      WORKSPACE_EXPLICIT=1
      shift 2
      ;;
    --config)
      [[ $# -lt 2 ]] && { log_err "--config 需要参数"; exit 1; }
      CONFIG_FILE="$2"
      shift 2
      ;;
    --skip-deps)
      SKIP_DEPS=1
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_err "未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  log_err "该脚本仅支持 Linux。"
  exit 1
fi

if [[ -d "$TEMPLATE_DIR" ]]; then
  HAS_TEMPLATE_DIR=1
else
  log_warn "未检测到本地模板目录，将使用脚本内置模板。"
fi

CONFIG_DIR="$(dirname "$CONFIG_FILE")"

install_jq_if_needed() {
  if command -v jq >/dev/null 2>&1; then
    return
  fi
  if [[ "$SKIP_DEPS" -eq 1 ]]; then
    log_err "检测到 jq 缺失，且指定了 --skip-deps。请先手动安装 jq。"
    exit 1
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    log_err "检测到 jq 缺失，且系统无 apt-get。请手动安装 jq 后重试。"
    exit 1
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] sudo apt-get update -qq && sudo apt-get install -y jq -qq"
    return
  fi
  log_info "安装依赖 jq..."
  sudo apt-get update -qq
  sudo apt-get install -y jq -qq
}

jq_value_or_default() {
  local query="$1"
  local default="$2"
  local value
  value="$(jq -r "$query" "$CONFIG_FILE" 2>/dev/null || true)"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

backup_file_if_exists() {
  local file="$1"
  local backup_dir="$2"
  [[ ! -f "$file" ]] && return
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] 备份文件: $file -> $backup_dir"
    return
  fi
  cp "$file" "$backup_dir/"
}

write_embedded_template_file() {
  local kind="$1"
  local dest="$2"

  case "$kind" in
    SOUL.md)
      cat > "$dest" <<'EOF'
# SOUL.md - 基督教价值观朝廷行为准则

## 核心价值
1. 敬畏真理：先查证再下结论，不编造、不夸大。
2. 爱人如己：坚持尊重沟通，拒绝操控、羞辱与恶意攻击。
3. 谦卑服事：发现错误立即承认并修复，持续复盘改进。
4. 忠心管家：重视时间、金钱、数据与系统安全的可持续管理。
5. 公义怜悯：优先保护弱势、隐私、合法权益与长期信任。

## 决策守则
- 先问：是否真实、是否有益、是否必要，再执行。
- 高风险操作必须二次确认，并提供可回滚方案。
- 涉及法律、医疗、财务建议时默认保守，并提示专业复核。

## 沟通风格
- 中文为主，结论先行，步骤清晰。
- 冲突场景先澄清事实，再给可执行选项。
EOF
      ;;
    IDENTITY.md)
      cat > "$dest" <<'EOF'
# IDENTITY.md - 基督教价值观朝廷多 Agent 架构

## 目标
构建一个长期可托付的多 Agent 个人助理体系，在保持高执行力的同时，遵循基督教价值观：
- 真实可信
- 彼此成全
- 谦卑服事
- 公义与怜悯并行

## 七部职责（兼容原始 ID）
1. `main` - 司礼监（总管）：任务分派、风险把关、日程统筹、复盘闭环。
2. `bingbu` - 工匠部（技术与工程）：代码实现、架构设计、测试与性能优化。
3. `hubu` - 管家部（财务与资源）：预算、成本、现金流与资源配置建议。
4. `libu` - 见证部（品牌与传播）：内容策划、对外表达、社媒沟通。
5. `gongbu` - 守望部（运维与安全）：部署、监控、故障恢复、基线安全。
6. `libu2` - 同工部（项目与协作）：项目管理、里程碑推进、协同流程。
7. `xingbu` - 真理部（法务与伦理）：合规审查、合同条款、伦理与风险评估。

## 统一协作原则
- 任何结论都要可追溯事实来源。
- 重大决策优先给出 A/B 方案与权衡。
- 涉及人身、财务、法律风险时升级为人工确认。
- 输出应当可执行、可复查、可回滚。
EOF
      ;;
    HEARTBEAT.md)
      cat > "$dest" <<'EOF'
# HEARTBEAT.md - Christian Court 日常巡检

## 每日任务
- 检查今日待办优先级与执行阻塞项。
- 汇总当日关键决策并生成简要复盘。
- 审视高风险操作（财务、法律、部署）是否完成二次确认。

## 每周任务
- 复盘本周目标完成率、成本与质量指标。
- 更新下周重点事项与风险缓释计划。
- 审核数据、密钥与权限最小化执行状态。
EOF
      ;;
    *)
      log_err "未知内置模板类型: $kind"
      exit 1
      ;;
  esac
}

emit_embedded_config_template() {
  cat <<'EOF'
{
  "models": {
    "providers": {
      "your-provider": {
        "baseUrl": "https://your-llm-provider-api-url",
        "apiKey": "YOUR_LLM_API_KEY",
        "api": "your-api-format",
        "models": [
          {
            "id": "fast-model",
            "name": "快速模型",
            "input": ["text", "image"],
            "contextWindow": 200000,
            "maxTokens": 8192
          },
          {
            "id": "strong-model",
            "name": "强力模型",
            "input": ["text", "image"],
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "__WORKSPACE__",
      "model": { "primary": "your-provider/fast-model" },
      "sandbox": { "mode": "non-main" }
    },
    "list": [
      {
        "id": "main",
        "name": "司礼监（总管）",
        "model": { "primary": "your-provider/fast-model" },
        "identity": {
          "theme": "你是司礼监总管，遵循基督教价值观：敬畏真理、爱人如己、谦卑服事、忠心管家、公义怜悯。你负责任务分派、风险把关、复盘闭环。回答必须先给结论，再给可执行步骤。"
        },
        "sandbox": { "mode": "off" }
      },
      {
        "id": "bingbu",
        "name": "工匠部",
        "model": { "primary": "your-provider/strong-model" },
        "identity": {
          "theme": "你是工匠部尚书，专精软件工程与系统架构。你要在真实、可验证、可回滚的前提下交付代码，并明确测试与风险。"
        },
        "sandbox": { "mode": "all", "scope": "agent" }
      },
      {
        "id": "hubu",
        "name": "管家部",
        "model": { "primary": "your-provider/strong-model" },
        "identity": {
          "theme": "你是管家部尚书，负责预算、成本、现金流和资源规划。你要坚持忠心管家原则，优先长期稳健与透明。"
        },
        "sandbox": { "mode": "all", "scope": "agent" }
      },
      {
        "id": "libu",
        "name": "见证部",
        "model": { "primary": "your-provider/fast-model" },
        "identity": {
          "theme": "你是见证部尚书，专精品牌传播与内容表达。你要以真实和尊重为前提，避免操控和夸张叙事。"
        },
        "sandbox": { "mode": "all", "scope": "agent" }
      },
      {
        "id": "gongbu",
        "name": "守望部",
        "model": { "primary": "your-provider/fast-model" },
        "identity": {
          "theme": "你是守望部尚书，负责运维、部署、监控和安全。你要优先保证系统可靠性、可恢复性和最小权限。"
        },
        "sandbox": { "mode": "all", "scope": "agent" }
      },
      {
        "id": "libu2",
        "name": "同工部",
        "model": { "primary": "your-provider/fast-model" },
        "identity": {
          "theme": "你是同工部尚书，负责项目管理与协作推进。你要保证目标清晰、节奏稳定、复盘闭环。"
        },
        "sandbox": { "mode": "all", "scope": "agent" }
      },
      {
        "id": "xingbu",
        "name": "真理部",
        "model": { "primary": "your-provider/fast-model" },
        "identity": {
          "theme": "你是真理部尚书，负责法务、合规和伦理审查。你要坚持公义怜悯原则，清晰提示风险边界和合规建议。"
        },
        "sandbox": { "mode": "all", "scope": "agent" }
      }
    ]
  },
  "channels": {
    "discord": {
      "enabled": true,
      "groupPolicy": "open",
      "allowBots": true,
      "accounts": {
        "main": {
          "name": "司礼监（总管）",
          "token": "YOUR_MAIN_BOT_TOKEN",
          "groupPolicy": "open"
        },
        "bingbu": {
          "name": "工匠部",
          "token": "YOUR_BINGBU_BOT_TOKEN",
          "groupPolicy": "open"
        },
        "hubu": {
          "name": "管家部",
          "token": "YOUR_HUBU_BOT_TOKEN",
          "groupPolicy": "open"
        },
        "libu": {
          "name": "见证部",
          "token": "YOUR_LIBU_BOT_TOKEN",
          "groupPolicy": "open"
        },
        "gongbu": {
          "name": "守望部",
          "token": "YOUR_GONGBU_BOT_TOKEN",
          "groupPolicy": "open"
        },
        "libu2": {
          "name": "同工部",
          "token": "YOUR_LIBU2_BOT_TOKEN",
          "groupPolicy": "open"
        },
        "xingbu": {
          "name": "真理部",
          "token": "YOUR_XINGBU_BOT_TOKEN",
          "groupPolicy": "open"
        }
      }
    }
  },
  "bindings": [
    { "agentId": "main", "match": { "channel": "discord", "accountId": "main" } },
    { "agentId": "bingbu", "match": { "channel": "discord", "accountId": "bingbu" } },
    { "agentId": "hubu", "match": { "channel": "discord", "accountId": "hubu" } },
    { "agentId": "libu", "match": { "channel": "discord", "accountId": "libu" } },
    { "agentId": "gongbu", "match": { "channel": "discord", "accountId": "gongbu" } },
    { "agentId": "libu2", "match": { "channel": "discord", "accountId": "libu2" } },
    { "agentId": "xingbu", "match": { "channel": "discord", "accountId": "xingbu" } }
  ]
}
EOF
}

copy_template_to_workspace() {
  local src="$1"
  local dest="$2"
  local kind
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] 写入模板: $src -> $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
  else
    kind="$(basename "$dest")"
    write_embedded_template_file "$kind" "$dest"
  fi
}

mask_token() {
  local token="$1"
  if [[ -z "$token" || "$token" == "null" ]]; then
    echo "(未设置)"
    return
  fi
  if [[ "${#token}" -le 8 ]]; then
    echo "********"
    return
  fi
  echo "${token:0:4}****${token: -4}"
}

create_config_from_template() {
  local template="${TEMPLATE_DIR}/clawdbot.json.template"
  local workspace_escaped tmp_template
  workspace_escaped="${WORKSPACE//|/\\|}"
  workspace_escaped="${workspace_escaped//&/\\&}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] 生成新配置: $CONFIG_FILE"
    return
  fi

  mkdir -p "$CONFIG_DIR"
  if [[ -f "$template" ]]; then
    sed "s|__WORKSPACE__|${workspace_escaped}|g" "$template" > "$CONFIG_FILE"
  else
    tmp_template="$(mktemp)"
    emit_embedded_config_template > "$tmp_template"
    sed "s|__WORKSPACE__|${workspace_escaped}|g" "$tmp_template" > "$CONFIG_FILE"
    rm -f "$tmp_template"
  fi
}

upgrade_existing_config() {
  local fast_model strong_model tmp
  fast_model="$(jq_value_or_default '(.agents.defaults.model.primary // [.agents.list[]?.model.primary][0])' 'your-provider/fast-model')"
  strong_model="$(jq_value_or_default '([.agents.list[]? | select(.id=="bingbu" or .id=="hubu").model.primary][0] // .agents.defaults.model.primary)' "$fast_model")"
  if [[ -z "$strong_model" || "$strong_model" == "null" ]]; then
    strong_model="$fast_model"
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] 升级现有配置: $CONFIG_FILE"
    return
  fi

  tmp="$(mktemp)"
  jq \
    --arg workspace "$WORKSPACE" \
    --arg fast "$fast_model" \
    --arg strong "$strong_model" \
    '
      . as $root
      | def model_for($id; $fallback): ([ $root.agents.list[]? | select(.id==$id).model.primary ][0] // $fallback);
      .agents = (.agents // {})
      | .agents.defaults = (.agents.defaults // {})
      | .agents.defaults.workspace = $workspace
      | .agents.defaults.model = (.agents.defaults.model // {"primary": $fast})
      | .agents.defaults.model.primary = (.agents.defaults.model.primary // $fast)
      | .agents.defaults.sandbox = (.agents.defaults.sandbox // {"mode":"non-main"})
      | .agents.defaults.sandbox.mode = (.agents.defaults.sandbox.mode // "non-main")
      | .channels = (.channels // {})
      | .channels.discord = (.channels.discord // {})
      | .channels.discord.accounts = (.channels.discord.accounts // {})
      | .agents.list = [
          {
            "id": "main",
            "name": "司礼监（总管）",
            "model": { "primary": model_for("main"; $fast) },
            "identity": {
              "theme": "你是司礼监总管，遵循基督教价值观：敬畏真理、爱人如己、谦卑服事、忠心管家、公义怜悯。你负责任务分派、风险把关、复盘闭环。回答必须先给结论，再给可执行步骤。"
            },
            "sandbox": { "mode": "off" }
          },
          {
            "id": "bingbu",
            "name": "工匠部",
            "model": { "primary": model_for("bingbu"; $strong) },
            "identity": {
              "theme": "你是工匠部尚书，专精软件工程与系统架构。你要在真实、可验证、可回滚的前提下交付代码，并明确测试与风险。"
            },
            "sandbox": { "mode": "all", "scope": "agent" }
          },
          {
            "id": "hubu",
            "name": "管家部",
            "model": { "primary": model_for("hubu"; $strong) },
            "identity": {
              "theme": "你是管家部尚书，负责预算、成本、现金流和资源规划。你要坚持忠心管家原则，优先长期稳健与透明。"
            },
            "sandbox": { "mode": "all", "scope": "agent" }
          },
          {
            "id": "libu",
            "name": "见证部",
            "model": { "primary": model_for("libu"; $fast) },
            "identity": {
              "theme": "你是见证部尚书，专精品牌传播与内容表达。你要以真实和尊重为前提，避免操控和夸张叙事。"
            },
            "sandbox": { "mode": "all", "scope": "agent" }
          },
          {
            "id": "gongbu",
            "name": "守望部",
            "model": { "primary": model_for("gongbu"; $fast) },
            "identity": {
              "theme": "你是守望部尚书，负责运维、部署、监控和安全。你要优先保证系统可靠性、可恢复性和最小权限。"
            },
            "sandbox": { "mode": "all", "scope": "agent" }
          },
          {
            "id": "libu2",
            "name": "同工部",
            "model": { "primary": model_for("libu2"; $fast) },
            "identity": {
              "theme": "你是同工部尚书，负责项目管理与协作推进。你要保证目标清晰、节奏稳定、复盘闭环。"
            },
            "sandbox": { "mode": "all", "scope": "agent" }
          },
          {
            "id": "xingbu",
            "name": "真理部",
            "model": { "primary": model_for("xingbu"; $fast) },
            "identity": {
              "theme": "你是真理部尚书，负责法务、合规和伦理审查。你要坚持公义怜悯原则，清晰提示风险边界和合规建议。"
            },
            "sandbox": { "mode": "all", "scope": "agent" }
          }
        ]
      | .channels.discord.allowBots = true
      | .channels.discord.groupPolicy = (.channels.discord.groupPolicy // "open")
      | (if .channels.discord.accounts.main? then .channels.discord.accounts.main.name = "司礼监（总管）" else . end)
      | (if .channels.discord.accounts.bingbu? then .channels.discord.accounts.bingbu.name = "工匠部" else . end)
      | (if .channels.discord.accounts.hubu? then .channels.discord.accounts.hubu.name = "管家部" else . end)
      | (if .channels.discord.accounts.libu? then .channels.discord.accounts.libu.name = "见证部" else . end)
      | (if .channels.discord.accounts.gongbu? then .channels.discord.accounts.gongbu.name = "守望部" else . end)
      | (if .channels.discord.accounts.libu2? then .channels.discord.accounts.libu2.name = "同工部" else . end)
      | (if .channels.discord.accounts.xingbu? then .channels.discord.accounts.xingbu.name = "真理部" else . end)
      | (
          if $root.channels.discord? and $root.channels.discord.accounts? then
            (["main","bingbu","hubu","libu","gongbu","libu2","xingbu"]
            | map(select($root.channels.discord.accounts[.]? != null) | {"agentId": ., "match": {"channel": "discord", "accountId": .}})) as $newBindings
            | if ($newBindings | length) > 0 then .bindings = $newBindings else . end
          else
            .
          end
        )
    ' "$CONFIG_FILE" > "$tmp"

  mv "$tmp" "$CONFIG_FILE"
}

configure_discord_tokens_interactive() {
  local ans ids id name current masked token tmp

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    log_info "已按参数跳过交互式 Token 配置。"
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] 将进行交互式 Discord Token 配置。"
    return
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_warn "配置文件不存在，跳过交互式 Token 配置。"
    return
  fi

  if [[ "$(jq -r 'if (.channels? != null and .channels.discord? != null and .channels.discord.accounts? != null) then "yes" else "no" end' "$CONFIG_FILE")" != "yes" ]]; then
    log_warn "未检测到 channels.discord.accounts，跳过交互式 Token 配置。"
    return
  fi

  echo
  read -r -p "是否进入 CLI 交互式部署 Discord Bot Token？[Y/n]: " ans
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    log_info "你选择跳过 Token 录入。"
    return
  fi

  mapfile -t ids < <(jq -r '.channels.discord.accounts | keys[]' "$CONFIG_FILE")
  for id in "${ids[@]}"; do
    name="$(jq -r --arg id "$id" '.channels.discord.accounts[$id].name // $id' "$CONFIG_FILE")"
    current="$(jq -r --arg id "$id" '.channels.discord.accounts[$id].token // ""' "$CONFIG_FILE")"
    masked="$(mask_token "$current")"

    echo
    echo "账号: ${id} (${name})"
    echo "当前 token: ${masked}"
    read -r -s -p "请输入新 token（回车保留当前，输入 '-' 清空）: " token
    echo

    if [[ -z "$token" ]]; then
      continue
    fi
    if [[ "$token" == "-" ]]; then
      token=""
    fi

    tmp="$(mktemp)"
    jq --arg id "$id" --arg token "$token" '.channels.discord.accounts[$id].token = $token' "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    log_ok "已更新 ${id} 的 token。"
  done
}

echo
echo -e "${BLUE}Christian Court 升级脚本${NC}"
echo "================================"

install_jq_if_needed

if [[ "$DRY_RUN" -eq 0 && ! -f "$CONFIG_FILE" && ! -d "$CONFIG_DIR" ]]; then
  mkdir -p "$CONFIG_DIR"
fi

if [[ -f "$CONFIG_FILE" && "$WORKSPACE_EXPLICIT" -eq 0 ]] && command -v jq >/dev/null 2>&1; then
  existing_workspace="$(jq -r '.agents.defaults.workspace // empty' "$CONFIG_FILE" 2>/dev/null || true)"
  if [[ -n "$existing_workspace" ]]; then
    WORKSPACE="$existing_workspace"
  fi
fi

timestamp="$(date +%Y%m%d%H%M%S)"
backup_dir="${CONFIG_DIR}/backups/christian-court-${timestamp}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log_info "[dry-run] 创建备份目录: $backup_dir"
else
  mkdir -p "$backup_dir" "$WORKSPACE"
fi

backup_file_if_exists "$CONFIG_FILE" "$backup_dir"
backup_file_if_exists "${WORKSPACE}/SOUL.md" "$backup_dir"
backup_file_if_exists "${WORKSPACE}/IDENTITY.md" "$backup_dir"
backup_file_if_exists "${WORKSPACE}/HEARTBEAT.md" "$backup_dir"
backup_file_if_exists "${WORKSPACE}/USER.md" "$backup_dir"

copy_template_to_workspace "${TEMPLATE_DIR}/SOUL.md" "${WORKSPACE}/SOUL.md"
copy_template_to_workspace "${TEMPLATE_DIR}/IDENTITY.md" "${WORKSPACE}/IDENTITY.md"
copy_template_to_workspace "${TEMPLATE_DIR}/HEARTBEAT.md" "${WORKSPACE}/HEARTBEAT.md"

if [[ -f "$CONFIG_FILE" ]]; then
  upgrade_existing_config
  log_ok "已升级配置: $CONFIG_FILE"
else
  create_config_from_template
  log_ok "已创建新配置: $CONFIG_FILE"
fi

configure_discord_tokens_interactive

echo
echo -e "${GREEN}升级完成${NC}"
echo "备份目录: $backup_dir"
echo
echo "建议下一步:"
echo "1) 检查配置文件中的模型与 Token 是否正确: $CONFIG_FILE"
echo "2) 重启网关: systemctl --user restart clawdbot-gateway"
echo "3) 验证状态: systemctl --user status clawdbot-gateway"
