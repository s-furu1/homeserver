#!/usr/bin/env bash
set -euo pipefail

created_tmp_env=false

cleanup() {
  if [[ "$created_tmp_env" == "true" && -L .env ]]; then
    target="$(readlink .env)"
    if [[ "$target" == ".env.example" ]]; then
      rm .env
    fi
  fi
}

trap cleanup EXIT

if [[ ! -e .env ]]; then
  ln -s .env.example .env
  created_tmp_env=true
fi

docker compose config
