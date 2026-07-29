#!/usr/bin/env bash
#
# Run from a WSL2 terminal in any working directory:
#   bash ./docker/verify.sh
#   bash ./docker/verify.sh --gui
#   bash ./docker/verify.sh --quick

set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
compose_file="$script_dir/docker-compose.yml"
test_script="$script_dir/scripts/verify_container.sh"

docker compose -f "$compose_file" up -d
docker compose -f "$compose_file" exec -T delft3d \
    bash -s -- "$@" <"$test_script"
