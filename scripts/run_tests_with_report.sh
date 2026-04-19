#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="${ROOT_DIR}/build/patrol_web_report"
RESULTS_DIR="${ROOT_DIR}/build/patrol_web_results"
TARGET="patrol_test/web/text_fixer_test.dart"
OPEN_REPORT=false
WEB_HEADLESS=true
PATROL_VERBOSE="${PATROL_VERBOSE:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --open)
      OPEN_REPORT=true
      shift
      ;;
    --headed)
      WEB_HEADLESS=false
      shift
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--open] [--headed] [--target <patrol_test path>]"
      exit 1
      ;;
  esac
done

if command -v patrol >/dev/null 2>&1; then
  PATROL_CMD="patrol"
elif [[ -x "${HOME}/.pub-cache/bin/patrol" ]]; then
  PATROL_CMD="${HOME}/.pub-cache/bin/patrol"
else
  echo "Patrol CLI not found. Install with: dart pub global activate patrol_cli"
  exit 1
fi

echo "==> Running Flutter widget tests"
cd "${ROOT_DIR}"
flutter test

echo "==> Running Patrol web tests with report output"
PATROL_ARGS=()
if [[ "${PATROL_VERBOSE}" == "true" ]]; then
  PATROL_ARGS+=(--verbose)
fi

PATROL_ANALYTICS_ENABLED=false "${PATROL_CMD}" test \
  "${PATROL_ARGS[@]}" \
  --device chrome \
  --target "${TARGET}" \
  --web-report-dir "${REPORT_DIR}" \
  --web-results-dir "${RESULTS_DIR}" \
  --web-reporter '["html","json","list"]' \
  --web-headless "${WEB_HEADLESS}"

echo "==> Patrol report: ${REPORT_DIR}/index.html"
echo "==> Patrol json:   ${REPORT_DIR}/results.json"

if [[ "${OPEN_REPORT}" == "true" ]]; then
  if command -v open >/dev/null 2>&1; then
    open "${REPORT_DIR}/index.html"
  else
    echo "Skipping auto-open: 'open' command is not available on this system."
  fi
fi
