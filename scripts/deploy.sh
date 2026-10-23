#!/usr/bin/env bash
# scripts/deploy.sh [--dry-run]
set -euo pipefail
REMOTE=devops
RSYNC_BIN=rsync
if [[ $(uname -s) == Darwin && -x /opt/homebrew/bin/rsync ]]; then RSYNC_BIN=/opt/homebrew/bin/rsync; fi
REMOTE_DIR=/var/www/devops-site
SITE_URL=https://devops.local
CA_CERT="${HOME}/devops.crt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LOCAL_DIR="${ROOT}/site/"
dry_run=false
case "${1:-}" in
  '') [[ $# -eq 0 ]] || { echo 'Usage: deploy.sh [--dry-run]' >&2; exit 1; } ;;
  --dry-run) [[ $# -eq 1 ]] || { echo 'Usage: deploy.sh [--dry-run]' >&2; exit 1; }; dry_run=true ;;
  *) echo 'Usage: deploy.sh [--dry-run]' >&2; exit 1 ;;
esac
[[ -f "${LOCAL_DIR}index.html" ]] || { echo 'site/index.html отсутствует; доставка отменена' >&2; exit 1; }
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || { echo 'Есть незафиксированные изменения; доставка отменена' >&2; exit 1; }
args=(-avz --delete --chmod=D755,F644 -e 'ssh -o BatchMode=yes -o ConnectTimeout=5')
if "$dry_run"; then args+=(--dry-run); fi
"$RSYNC_BIN" "${args[@]}" "$LOCAL_DIR" "${REMOTE}:${REMOTE_DIR}/" || exit 1
if "$dry_run"; then echo 'План построен; сервер не изменён'; exit 0; fi
curl_args=(--fail --silent --show-error --max-time 10 --cacert "$CA_CERT")
if [[ -n "${CURL_RESOLVE:-}" ]]; then curl_args+=(--resolve "$CURL_RESOLVE"); fi
curl "${curl_args[@]}" "$SITE_URL" >/dev/null || exit 1
echo "Доставлен коммит $(git -C "$ROOT" rev-parse --short HEAD)"
