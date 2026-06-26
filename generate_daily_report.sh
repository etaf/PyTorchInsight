#!/bin/bash
# PyTorch 社区日报自动生成脚本
# 通过 Copilot CLI programmatic 模式 + pytorch-community MCP 生成日报
#
# 用法：
#   手动执行：./generate_daily_report.sh
#   cron 定时：0 9 * * * /path/to/PyTorchInsight/generate_daily_report.sh

set -euo pipefail

# --prod 参数切换正式收件人
REPORT_MODE="test"
if [[ "${1:-}" == "--prod" ]]; then
    REPORT_MODE="prod"
fi

# 确保 cron 环境能找到所需命令
export PATH="$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 加载 .env 中的环境变量（含 GITHUB_TOKEN、代理、EXTRA_PATH 等）
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
fi

# 追加额外 PATH（如 conda 路径，从 .env 的 EXTRA_PATH 读取）
if [[ -n "${EXTRA_PATH:-}" ]]; then
    export PATH="${EXTRA_PATH}:$PATH"
fi

export no_proxy="${no_proxy:-127.0.0.1,localhost}"

REPORT_DIR="${SCRIPT_DIR}/reports"
DATE=$(date +%Y-%m-%d)
REPORT_FILE="${REPORT_DIR}/pytorch_daily_${DATE}.md"
LOG_FILE="${REPORT_DIR}/.generate_${DATE}.log"
COPILOT_DAILY_MODEL="${COPILOT_DAILY_MODEL:-${COPILOT_MODEL:-auto}}"

# copilot CLI 认证：使用 gh auth login 的 OAuth 缓存
# classic PAT (ghp_) 不被 copilot CLI 接受，必须 unset 所有 token 变量以免干扰
# MCP server 的 GITHUB_TOKEN 通过 ~/.copilot/mcp-config.json 的 env 字段独立传递
unset COPILOT_GITHUB_TOKEN 2>/dev/null || true
unset GH_TOKEN 2>/dev/null || true
unset GITHUB_TOKEN 2>/dev/null || true

# 如果今天的日报已存在则跳过
if [[ -f "$REPORT_FILE" ]]; then
    echo "[$(date)] Report already exists: $REPORT_FILE" | tee -a "$LOG_FILE"
    exit 0
fi

mkdir -p "$REPORT_DIR"

echo "[$(date)] Generating daily report with model: ${COPILOT_DAILY_MODEL}" | tee "$LOG_FILE"

# 使用 Copilot CLI programmatic 模式
# --agent: 使用日报生成专用 agent
# --allow-tool: 只允许 MCP 工具和文件写入，不允许任意 shell
cd "$SCRIPT_DIR"

copilot -p "Generate today's (${DATE}) PyTorch community daily report, save to ${REPORT_FILE}" \
    --agent pytorch-daily-report \
    --model "${COPILOT_DAILY_MODEL}" \
    --allow-tool='pytorch-community' \
    --allow-tool='write' \
    --deny-tool='shell' \
    2>&1 | tee -a "$LOG_FILE" || true

# 检查是否生成成功
if [[ -f "$REPORT_FILE" ]]; then
    echo "[$(date)] Report generated: $REPORT_FILE" | tee -a "$LOG_FILE"

    # 正式模式使用 REPORT_TO_EMAIL_PROD
    if [[ "$REPORT_MODE" == "prod" && -n "${REPORT_TO_EMAIL_PROD:-}" ]]; then
        export REPORT_TO_EMAIL="$REPORT_TO_EMAIL_PROD"
    fi

    # 发送邮件
    echo "[$(date)] Sending report email to: $REPORT_TO_EMAIL" | tee -a "$LOG_FILE"
    python3 "${SCRIPT_DIR}/send_report_email.py" "$REPORT_FILE" \
        2>&1 | tee -a "$LOG_FILE"
else
    echo "[$(date)] ERROR: Report file not created" | tee -a "$LOG_FILE"
    exit 1
fi
