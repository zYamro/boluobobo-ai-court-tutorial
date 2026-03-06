#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates/christian-court"

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

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  log_err "找不到模板目录: $TEMPLATE_DIR"
  exit 1
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

copy_template_to_workspace() {
  local src="$1"
  local dest="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] 写入模板: $src -> $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
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
  local workspace_escaped
  workspace_escaped="${WORKSPACE//|/\\|}"
  workspace_escaped="${workspace_escaped//&/\\&}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] 生成新配置: $CONFIG_FILE"
    return
  fi

  mkdir -p "$CONFIG_DIR"
  sed "s|__WORKSPACE__|${workspace_escaped}|g" "$template" > "$CONFIG_FILE"
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
