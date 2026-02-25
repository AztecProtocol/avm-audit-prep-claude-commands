#!/usr/bin/env bash
# Run all avm-* commands that support fix mode on a given PIL file.
# Usage: avm-run-all-fix.sh <path-to-pil-file>
#
# Discovers commands dynamically by scanning .claude/commands/avm-*.md
# for files containing "fix mode" (case-insensitive). Skips orchestrator
# commands (avm-auto-*) and the audit overview (avm-pil-audit).
#
# Each command is run via `claude -p` in non-interactive mode.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path-to-pil-file>"
    exit 1
fi

PIL_FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="${SCRIPT_DIR}"
PASSED=0
FAILED=0
SKIPPED=0
FAILURES=()

# Discover all avm-* commands that support fix mode.
mapfile -t CMD_FILES < <(grep -ril "fix mode" "${COMMANDS_DIR}"/avm-*.md 2>/dev/null | sort)

if [[ ${#CMD_FILES[@]} -eq 0 ]]; then
    echo "No fix-mode commands found in ${COMMANDS_DIR}"
    exit 1
fi

echo "=== AVM Fix-Mode Runner ==="
echo "PIL file: ${PIL_FILE}"
echo "Found ${#CMD_FILES[@]} fix-mode commands"
echo ""

for cmd_file in "${CMD_FILES[@]}"; do
    # Extract the command name from the filename (strip path and .md).
    cmd_name=$(basename "${cmd_file}" .md)

    # Skip orchestrator / meta commands.
    if [[ "${cmd_name}" == avm-auto-* ]] || [[ "${cmd_name}" == avm-pil-audit ]]; then
        echo "--- SKIP: /${cmd_name} (orchestrator/meta) ---"
        ((SKIPPED++))
        continue
    fi

    echo "--- Running: /${cmd_name} fix ${PIL_FILE} ---"
    if claude -p --allowedTools "Read,Edit,Write,Glob,Grep,Bash,Task" \
        "/${cmd_name} fix ${PIL_FILE}" 2>&1; then
        echo "--- PASS: /${cmd_name} ---"
        ((PASSED++))
    else
        echo "--- FAIL: /${cmd_name} ---"
        ((FAILED++))
        FAILURES+=("${cmd_name}")
    fi
    echo ""
done

echo "=== Summary ==="
echo "Passed: ${PASSED}"
echo "Failed: ${FAILED}"
echo "Skipped: ${SKIPPED}"
if [[ ${FAILED} -gt 0 ]]; then
    echo "Failures: ${FAILURES[*]}"
    exit 1
fi
