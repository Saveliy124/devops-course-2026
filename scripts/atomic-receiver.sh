#!/usr/bin/env bash
# Installed once at ~/devops-course-2026/scripts/atomic-receiver.sh.
# Normal mode is invoked by rsync --rsync-path with its server arguments.
set -euo pipefail
base=/var/www/devops-site
switch_current() {
  local target="$1" old
  old=""; if [[ -L "$base/current" ]]; then old="$(readlink -f "$base/current")"; fi
  rm -f "$base/current_tmp"
  ln -s "$target" "$base/current_tmp" && mv -T "$base/current_tmp" "$base/current"
  if [[ -n "$old" && "$old" != "$target" ]]; then
    rm -f "$base/previous_tmp"
    ln -s "$old" "$base/previous_tmp" && mv -T "$base/previous_tmp" "$base/previous"
  fi
}
if [[ "${1:-}" == --rollback ]]; then
  target="$(readlink -f "$base/previous")"
  [[ -d "$target" && -f "$target/index.html" ]] || { echo 'Нет предыдущей версии' >&2; exit 1; }
  exec 9>"$base/.deploy.lock"; flock 9
  switch_current "$target"
  echo "Откат на $target" >&2
  exit 0
fi
release="${1:?release required}"; shift
[[ "$release" =~ ^/var/www/devops-site/releases/[0-9]{8}-[0-9]{6}-[A-Za-z0-9]+$ ]] || exit 1
[[ -d "$release" ]] || exit 1
exec 9>"$base/.deploy.lock"; flock 9
if ! rsync "$@"; then rm -rf -- "$release"; exit 1; fi
[[ -f "$release/index.html" ]] || { rm -rf -- "$release"; exit 1; }
switch_current "$release"
# Preserve current and previous, then fill the remaining slots with newest releases.
current="$(readlink -f "$base/current")"
previous="$(readlink -f "$base/previous" || true)"
mapfile -t versions < <(find "$base/releases" -mindepth 1 -maxdepth 1 -type d | sort -r)
declare -A seen=()
count=0
for dir in "$current" "$previous" "${versions[@]}"; do
  [[ -n "$dir" && -d "$dir" && -z "${seen[$dir]:-}" ]] || continue
  seen["$dir"]=1
  if (( count < 5 )); then ((count+=1)); else rm -rf -- "$dir"; fi
done
echo "Активирована версия $release; хранится $count версий" >&2
