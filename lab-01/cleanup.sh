#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Cleanup – remove all artifacts created by lab-01a through lab-01d
# ---------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

printf "Cleaning up all lab-01 artifacts...\n\n"

# ── containers ─────────────────────────────────────────────────────────────
printf "Removing containers...\n"
for name in web-v1 web-v2 db db-vol db-bind uid-test; do
  podman rm -f "${name}" 2>/dev/null && printf "  removed container: %s\n" "${name}"
done

# ── images ─────────────────────────────────────────────────────────────────
printf "\nRemoving images...\n"
for img in hello-web:1.0.0 hello-web:1.1.0; do
  podman rmi -f "${img}" 2>/dev/null && printf "  removed image: %s\n" "${img}"
done

# ── volumes ────────────────────────────────────────────────────────────────
printf "\nRemoving volumes...\n"
podman volume rm dbdata 2>/dev/null && printf "  removed volume: dbdata\n"

# ── networks ───────────────────────────────────────────────────────────────
printf "\nRemoving networks...\n"
podman network rm app-net 2>/dev/null && printf "  removed network: app-net\n"

# ── local files ────────────────────────────────────────────────────────────
printf "\nRemoving local files...\n"
rm -f "${SCRIPT_DIR}/backup.tar" 2>/dev/null && printf "  removed: backup.tar\n"
rm -rf "${SCRIPT_DIR}/data" 2>/dev/null && printf "  removed: data/\n"

# ── restore hello-web/html/index.html if a backup exists ──────────────────
for bak in /tmp/index.html.bak.* "${TMPDIR:-/tmp}"/index.html.bak.*; do
  if [[ -f "${bak}" ]]; then
    cp "${bak}" "${SCRIPT_DIR}/hello-web/html/index.html" 2>/dev/null
    rm -f "${bak}"
    printf "  restored: hello-web/html/index.html from backup\n"
    break
  fi
done

printf "\nDone.\n"
