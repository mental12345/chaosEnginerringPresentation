#!/usr/bin/env bash
set -euo pipefail

# ===========================================================
# AWS Fault Injection Simulator (FIS) Experiment Runner
# Starts an experiment from an existing FIS template.
# Usage:
#   ./start-experiment.sh <template-id>
# ===========================================================

TEMPLATE_ID=${1:-}
REGION=${AWS_REGION:-"us-west-2"}
LOG_DIR="logs"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

if [[ -z "$TEMPLATE_ID" ]]; then
  echo "❌ Error: No template ID provided."
  echo "Usage: $0 <template-id>"
  exit 1
fi

echo "🚀 Starting experiment from template: $TEMPLATE_ID (region: $REGION)"
EXPERIMENT_ID=$(aws fis start-experiment \
  --region "$REGION" \
  --experiment-template-id "$TEMPLATE_ID" \
  --query "experiment.id" \
  --output text)

echo "✅ Experiment started: $EXPERIMENT_ID"

# Optional: create logs directory if not exists
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/experiment-${EXPERIMENT_ID}-${TIMESTAMP}.log"

# Monitor experiment status
echo "📡 Monitoring experiment status..."
while true; do
  STATUS=$(aws fis get-experiment \
    --region "$REGION" \
    --id "$EXPERIMENT_ID" \
    --query "experiment.state.status" \
    --output text)

  echo "🕐 Current status: $STATUS" | tee -a "$LOG_FILE"

  if [[ "$STATUS" == "completed" || "$STATUS" == "stopped" || "$STATUS" == "failed" ]]; then
    echo "✅ Experiment finished with status: $STATUS"
    break
  fi

  sleep 10
done

# Show summary details
echo "📊 Experiment summary:"
aws fis get-experiment \
  --region "$REGION" \
  --id "$EXPERIMENT_ID" \
  --query "experiment | {id:id, startTime:startTime, endTime:endTime, state:state.status, actions:actions}" \
  --output table | tee -a "$LOG_FILE"

