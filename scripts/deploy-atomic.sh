#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
REMOTE=devops
BASE=/var/www/devops-site
RECEIVER=/home/devops/devops-course-2026/scripts/atomic-receiver.sh
RSYNC_BIN=rsync
if [[ $(uname -s) == Darwin && -x /opt/homebrew/bin/rsync ]]; then RSYNC_BIN=/opt/homebrew/bin/rsync; fi
ssh_args=(-o BatchMode=yes -o ConnectTimeout=5)
case "${1:-}" in
  --rollback)
    [[ $# -eq 1 ]] || exit 1
    ssh "${ssh_args[@]}" "$REMOTE" "bash $RECEIVER --rollback"
    ;;
  '')
    [[ $# -eq 0 ]] || exit 1
    [[ -f "$ROOT/site/index.html" ]] || { echo 'index.html отсутствует' >&2; exit 1; }
    [[ -z "$(git -C "$ROOT" status --porcelain)" ]] || { echo 'Есть незафиксированные изменения' >&2; exit 1; }
    # First connection prepares an empty release and returns a previous release for --link-dest.
    plan="$(ssh "${ssh_args[@]}" "$REMOTE" 'set -e; b=/var/www/devops-site; mkdir -p "$b/releases"; n=$(mktemp -d "$b/releases/$(date -u +%Y%m%d-%H%M%S)-XXXXXX"); chmod 755 "$b" "$b/releases" "$n"; p=""; if [ -L "$b/current" ]; then p=$(readlink -f "$b/current"); fi; printf "%s|%s\n" "$n" "$p"')"
    IFS='|' read -r release previous <<<"$plan"
    args=(-avz --delete --chmod=D755,F644 -e 'ssh -o BatchMode=yes -o ConnectTimeout=5')
    if [[ -n "$previous" ]]; then args+=("--link-dest=$previous"); fi
    # The receiver switches the symlink only after rsync completes successfully.
    "$RSYNC_BIN" "${args[@]}" --rsync-path="bash $RECEIVER $release" "$ROOT/site/" "$REMOTE:$release/"
    ;;
  *) echo 'Usage: deploy-atomic.sh [--rollback]' >&2; exit 1 ;;
esac
curl_args=(--fail --silent --show-error --max-time 10 --cacert "$HOME/devops.crt")
if [[ -n "${CURL_RESOLVE:-}" ]]; then curl_args+=(--resolve "$CURL_RESOLVE"); fi
curl "${curl_args[@]}" https://devops.local/ >/dev/null
echo "Атомарная операция завершена; источник $(git -C "$ROOT" rev-parse --short HEAD)"
