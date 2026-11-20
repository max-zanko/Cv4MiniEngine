#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 || $1 == --help || $1 == -h ]]; then
    echo "Usage: $0 CIV4_ROOT [engine arguments...]"
    echo 'CIV4_ROOT must contain Beyond the Sword/Civ4BeyondSword.exe.'
    echo 'On first launch, select /civ4 in the directory prompt.'
    exit 0
fi

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
game_dir=$(cd -- "$1" && pwd)
shift

if [[ ! -f "$game_dir/Beyond the Sword/Civ4BeyondSword.exe" ]]; then
    echo "Missing Beyond the Sword/Civ4BeyondSword.exe in: $game_dir" >&2
    exit 1
fi
if [[ ! -f "$repo_dir/out/docker-install/Cv4MiniEngine_Regular.sh" ]]; then
    echo 'Build the application first; see BUILDING.md.' >&2
    exit 1
fi

mkdir -p -- "$repo_dir/out/runtime/config/Beyond the Sword" \
    "$repo_dir/out/runtime/data" "$repo_dir/out/runtime/cache"

terminal_args=(-i)
if [[ -t 0 && -t 1 ]]; then
    terminal_args+=(-t)
fi

exec docker run --rm "${terminal_args[@]}" \
    --user "$(id -u):$(id -g)" \
    --security-opt label=disable \
    -v "$repo_dir:/workspace" \
    -v "$game_dir:/civ4:ro" \
    -e TERM \
    -e XDG_CONFIG_HOME=/workspace/out/runtime/config \
    -e XDG_DATA_HOME=/workspace/out/runtime/data \
    -e XDG_CACHE_HOME=/workspace/out/runtime/cache \
    -w /workspace/out/docker-install \
    cv4mini-build:local sh ./Cv4MiniEngine_Regular.sh "$@"
