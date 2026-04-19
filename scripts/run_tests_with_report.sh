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
PATROL_NO_OUTPUT_TIMEOUT_SECONDS="${PATROL_NO_OUTPUT_TIMEOUT_SECONDS:-90}"
PATROL_PRINT_LOGS="${PATROL_PRINT_LOGS:-true}"

cleanup_web_processes() {
  # Best effort cleanup for orphan Playwright/Chromium processes from previous runs.
  # Restrict to common Playwright cache/process names to avoid unrelated process kills.
  pkill -f 'ms-playwright/.*/chrome-linux64/chrome' >/dev/null 2>&1 || true
  pkill -f 'ms-playwright/.*/chrome-headless-shell' >/dev/null 2>&1 || true
  pkill -f 'playwright.*chromium' >/dev/null 2>&1 || true
  pkill -f 'patrol-.*/web_runner' >/dev/null 2>&1 || true
}

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
    --no-output-timeout-seconds)
      PATROL_NO_OUTPUT_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--open] [--headed] [--patrol-only] [--fail-fast-minutes <n>] [--no-output-timeout-seconds <n>] [--target <patrol_test path>]"
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
  --dart-define "PATROL_PRINT_LOGS=${PATROL_PRINT_LOGS}"
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

run_patrol_command() {
  if [[ "${CI:-false}" == "true" ]]; then
    cleanup_web_processes
  fi

  if [[ "${CI:-false}" == "true" ]]; then
    trap cleanup_web_processes EXIT
  fi

  PATROL_WEB_LOCALE="${BROWSER_LOCALE//_/-}" \
  PATROL_ANALYTICS_ENABLED=false \
  "${PATROL_CMD}" "${PATROL_ARGS[@]}"

  if [[ "${CI:-false}" == "true" ]]; then
    trap - EXIT
    cleanup_web_processes
  fi
}

run_with_no_output_watchdog() {
  local timeout_seconds="$1"
  local heartbeat_file
  heartbeat_file="$(mktemp)"
  date +%s > "${heartbeat_file}"

  run_patrol_command > >(while IFS= read -r line; do
    printf '%s\n' "$line"
    date +%s > "${heartbeat_file}"
  done) 2> >(while IFS= read -r line; do
    printf '%s\n' "$line" >&2
    date +%s > "${heartbeat_file}"
  done) &

  local patrol_pid=$!
  local now
  local last_output

  while kill -0 "${patrol_pid}" >/dev/null 2>&1; do
    now=$(date +%s)
    last_output=$(cat "${heartbeat_file}" 2>/dev/null || echo "${now}")
    if (( now - last_output >= timeout_seconds )); then
      echo "No output received for ${timeout_seconds}s. Stopping Patrol process..." >&2
      kill -SIGINT "${patrol_pid}" >/dev/null 2>&1 || true
      sleep 30
      kill -SIGKILL "${patrol_pid}" >/dev/null 2>&1 || true
      wait "${patrol_pid}" >/dev/null 2>&1 || true
      rm -f "${heartbeat_file}"
      return 124
    fi
    sleep 2
  done

  wait "${patrol_pid}"
  local status=$?
  rm -f "${heartbeat_file}"
  return "${status}"
}

if [[ -n "${PATROL_NO_OUTPUT_TIMEOUT_SECONDS}" && "${PATROL_NO_OUTPUT_TIMEOUT_SECONDS}" != "0" ]]; then
  if [[ -n "${PATROL_HARD_TIMEOUT_MINUTES}" ]]; then
    echo "Info: ignoring PATROL_HARD_TIMEOUT_MINUTES because no-output watchdog is enabled."
  fi
  run_with_no_output_watchdog "${PATROL_NO_OUTPUT_TIMEOUT_SECONDS}"
elif [[ -n "${TIMEOUT_BIN}" ]]; then
  "${TIMEOUT_BIN}" --signal=SIGINT --kill-after=30s "${PATROL_HARD_TIMEOUT_MINUTES}m" run_patrol_command
else
  run_patrol_command
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
