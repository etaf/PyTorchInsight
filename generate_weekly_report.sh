#!/bin/bash
# PyTorch 社区周报自动生成脚本
# 通过 Copilot CLI programmatic 模式 + pytorch-community MCP 生成周报
#
# 用法：
#   手动执行：./generate_weekly_report.sh
#   cron 定时：0 12 * * 0 /path/to/PyTorchInsight/generate_weekly_report.sh

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
SINCE=$(date -d '7 days ago' +%Y-%m-%d)
REPORT_FILE="${REPORT_DIR}/pytorch_weekly_${DATE}.md"
LOG_FILE="${REPORT_DIR}/.generate_weekly_${DATE}.log"
COPILOT_WEEKLY_MODEL="${COPILOT_WEEKLY_MODEL:-${COPILOT_MODEL:-auto}}"

# copilot CLI 认证：使用 gh auth login 的 OAuth 缓存
unset COPILOT_GITHUB_TOKEN 2>/dev/null || true
unset GH_TOKEN 2>/dev/null || true
unset GITHUB_TOKEN 2>/dev/null || true

# 如果本周的周报已存在则跳过
if [[ -f "$REPORT_FILE" ]]; then
    echo "[$(date)] Weekly report already exists: $REPORT_FILE" | tee -a "$LOG_FILE"
    exit 0
fi

mkdir -p "$REPORT_DIR"

echo "[$(date)] Generating weekly report (${SINCE} ~ ${DATE}) with model: ${COPILOT_WEEKLY_MODEL}" | tee "$LOG_FILE"

cd "$SCRIPT_DIR"

copilot -p "Generate PyTorch community weekly report for ${SINCE} to ${DATE}, save to ${REPORT_FILE}" \
    --agent pytorch-weekly-report \
    --model "${COPILOT_WEEKLY_MODEL}" \
    --allow-tool='pytorch-community' \
    --allow-tool='write' \
    --deny-tool='shell' \
    2>&1 | tee -a "$LOG_FILE" || true

# 检查是否生成成功
if [[ -f "$REPORT_FILE" ]]; then
    echo "[$(date)] Weekly report generated: $REPORT_FILE" | tee -a "$LOG_FILE"

    # 正式模式使用 REPORT_TO_EMAIL_PROD
    if [[ "$REPORT_MODE" == "prod" && -n "${REPORT_TO_EMAIL_PROD:-}" ]]; then
        export REPORT_TO_EMAIL="$REPORT_TO_EMAIL_PROD"
    fi

    # 发送邮件
    echo "[$(date)] Sending weekly report email to: $REPORT_TO_EMAIL" | tee -a "$LOG_FILE"
    python3 "${SCRIPT_DIR}/send_report_email.py" "$REPORT_FILE" \
        2>&1 | tee -a "$LOG_FILE"
else
    echo "[$(date)] ERROR: Weekly report file not created" | tee -a "$LOG_FILE"
    exit 1
fi
