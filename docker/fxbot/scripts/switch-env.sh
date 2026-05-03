#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: ./scripts/switch-env.sh practice|live" >&2
}

die() {
  echo "error: $*" >&2
  exit 1
}

mode="${1:-}"
case "$mode" in
  practice|live) ;;
  *)
    usage
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fxbot_dir="$(cd "${script_dir}/.." && pwd)"
env_file="${fxbot_dir}/.env.${mode}"

cd "$fxbot_dir"

[[ -f "$env_file" ]] || die ".env.${mode} does not exist"

if [[ "$mode" == "live" ]]; then
  read -r -p "Type 'I CONFIRM FXBOT LIVE' to switch to live: " confirmation
  [[ "$confirmation" == "I CONFIRM FXBOT LIVE" ]] || die "live confirmation failed"
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -n "$line" ]] || continue
  [[ "$line" != export\ * ]] || die "export syntax is not allowed: ${line}"
  [[ "$line" != *"#"* ]] || die "comments are not allowed: ${line}"
  [[ "$line" != *" = "* && "$line" != *" ="* && "$line" != *"= "* ]] || die "assignments with spaces are not allowed: ${line}"
  [[ "$line" != *\"* && "$line" != *\'* ]] || die "quoted values are not allowed: ${line}"
  [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]#]*$ ]] || die "invalid KEY=value line: ${line}"
done < "$env_file"

require_value() {
  local key="$1"
  local value
  value="$(awk -F= -v key="$key" '$1 == key { print substr($0, length($1) + 2); found = 1; exit } END { if (!found) exit 1 }' "$env_file")" \
    || die "${key} is required"
  printf '%s' "$value"
}

[[ "$(require_value FXBOT_MODE)" == "$mode" ]] || die "FXBOT_MODE must be ${mode}"
[[ "$(require_value OANDA_ENV)" == "$mode" ]] || die "OANDA_ENV must be ${mode}"
[[ "$(require_value FXBOT_EXPECTED_MODE)" == "$mode" ]] || die "FXBOT_EXPECTED_MODE must be ${mode}"
[[ "$(require_value FXBOT_DB_ENV)" == "$mode" ]] || die "FXBOT_DB_ENV must be ${mode}"
[[ "$(require_value DB_PATH)" == "/data/trades.db" ]] || die "DB_PATH must be /data/trades.db"

dry_run="$(require_value DRY_RUN)"
[[ "$dry_run" == "true" || "$dry_run" == "false" ]] || die "DRY_RUN must be true or false"

mkdir -p "data/${mode}"
ln -sfn ".env.${mode}" .env

export FXBOT_MODE="$mode"
docker compose pull
docker compose up -d
