#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="${ROOT_DIR}/build/patrol_web_report"
RESULTS_DIR="${ROOT_DIR}/build/patrol_web_results"
TARGET="patrol_test/web/text_fixer_test.dart"
OPEN_REPORT=false
WEB_HEADLESS=true
RUN_WIDGET_TESTS=true
PATROL_VERBOSE="${PATROL_VERBOSE:-false}"
BROWSER_LOCALE="${BROWSER_LOCALE:-en-US}"
PATROL_HARD_TIMEOUT_MINUTES="${PATROL_HARD_TIMEOUT_MINUTES:-}"

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
    --patrol-only|--skip-widget-tests)
      RUN_WIDGET_TESTS=false
      shift
      ;;
    --fail-fast-minutes)
      PATROL_HARD_TIMEOUT_MINUTES="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--open] [--headed] [--patrol-only] [--fail-fast-minutes <n>] [--target <patrol_test path>]"
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

cd "${ROOT_DIR}"

if [[ "${RUN_WIDGET_TESTS}" == "true" ]]; then
  echo "==> Running Flutter widget tests"
  flutter test
fi

echo "==> Running Patrol web tests with report output"
PATROL_ARGS=(
  test
  --device chrome
  --target "${TARGET}"
  --web-report-dir "${REPORT_DIR}"
  --web-results-dir "${RESULTS_DIR}"
  --web-reporter '["html","json","list"]'
  --web-headless "${WEB_HEADLESS}"
)

if [[ "${PATROL_VERBOSE}" == "true" ]]; then
  PATROL_ARGS=(--verbose "${PATROL_ARGS[@]}")
fi

TIMEOUT_BIN=""
if [[ -n "${PATROL_HARD_TIMEOUT_MINUTES}" ]]; then
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
  else
    echo "Warning: fail-fast requested (${PATROL_HARD_TIMEOUT_MINUTES}m) but neither timeout nor gtimeout is available."
  fi
fi

if [[ -n "${TIMEOUT_BIN}" ]]; then
  "${TIMEOUT_BIN}" --signal=SIGINT --kill-after=30s "${PATROL_HARD_TIMEOUT_MINUTES}m" env \
    LANG="${BROWSER_LOCALE}" \
    LANGUAGE="${BROWSER_LOCALE}" \
    PATROL_ANALYTICS_ENABLED=false \
    "${PATROL_CMD}" "${PATROL_ARGS[@]}"
else
  LANG="${BROWSER_LOCALE}" \
  LANGUAGE="${BROWSER_LOCALE}" \
  PATROL_ANALYTICS_ENABLED=false "${PATROL_CMD}" "${PATROL_ARGS[@]}"
fi

echo "==> Patrol report: ${REPORT_DIR}/index.html"
echo "==> Patrol json:   ${REPORT_DIR}/results.json"

if [[ "${OPEN_REPORT}" == "true" ]]; then
  if command -v open >/dev/null 2>&1; then
    open "${REPORT_DIR}/index.html"
  else
    echo "Skipping auto-open: 'open' command is not available on this system."
  fi
fi
