#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Lab 01d – Volumes & Bind Mounts
#  Run: ./lab-01d-volumes.sh
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_IMAGE="registry.access.redhat.com/hi/mariadb:11.8"

# ── colours & helpers ──────────────────────────────────────────────────────
BOLD=$'\033[1m'
CYAN=$'\033[1;36m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
DIM=$'\033[2m'
RESET=$'\033[0m'
BG_DISCUSS=$'\033[48;5;88m'
FG_TITLE=$'\033[1;97m'
FG_BODY=$'\033[38;5;224m'

step=0

banner() {
  printf "\n"
  printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "${BOLD}" "${RESET}"
  printf "%s  %s%s\n" "${YELLOW}" "$1" "${RESET}"
  printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "${BOLD}" "${RESET}"
}

run() {
  step=$((step + 1))
  printf "\n"
  printf "%s── step %s ──────────────────────────────────────────────────%s\n" "${DIM}" "${step}" "${RESET}"
  printf "%s▶ %s%s%s\n" "${GREEN}" "${CYAN}" "$*" "${RESET}"
  printf "%s   Press ENTER to run (or 'q' to quit)...%s" "${DIM}" "${RESET}"
  read -r input
  if [[ "${input}" == "q" ]]; then
    printf "Demo aborted.\n"
    exit 0
  fi
  printf "\n"
  eval "$@"
}

comment() {
  printf "\n"
  printf "%s# %s%s\n" "${YELLOW}" "$*" "${RESET}"
}

pause() {
  printf "\n"
  printf "%s   Press ENTER to continue...%s" "${DIM}" "${RESET}"
  read -r input
  if [[ "${input}" == "q" ]]; then exit 0; fi
}

discuss() {
  local inner=72
  local border pad
  printf "\n"
  border=$(printf '═%.0s' $(seq 1 "${inner}"))
  pad=$(printf ' %.0s' $(seq 1 "${inner}"))
  local -a lines=()
  lines+=("$1")
  shift
  for arg in "$@"; do lines+=("${arg}"); done
  printf "%s%s╔%s╗%s\n" "${BG_DISCUSS}" "${FG_TITLE}" "${border}" "${RESET}"
  printf "%s%s║%s║%s\n" "${BG_DISCUSS}" "${FG_TITLE}" "${pad}" "${RESET}"
  local first=1
  for line in "${lines[@]}"; do
    local maxlen=$((inner - 4))
    if [[ ${#line} -gt ${maxlen} ]]; then line="${line:0:${maxlen}}"; fi
    local spaces=$((inner - 2 - ${#line}))
    local trailing
    trailing=$(printf ' %.0s' $(seq 1 "${spaces}"))
    if [[ ${first} -eq 1 ]]; then
      printf "%s%s║  %s%s%s║%s\n" "${BG_DISCUSS}" "${FG_TITLE}" "${line}" "${trailing}" "${FG_TITLE}" "${RESET}"
      first=0
    else
      printf "%s%s║  %s%s%s║%s\n" "${BG_DISCUSS}" "${FG_BODY}" "${line}" "${trailing}" "${FG_TITLE}" "${RESET}"
    fi
  done
  printf "%s%s║%s║%s\n" "${BG_DISCUSS}" "${FG_TITLE}" "${pad}" "${RESET}"
  printf "%s%s╚%s╝%s\n" "${BG_DISCUSS}" "${FG_TITLE}" "${border}" "${RESET}"
  printf "\n"
  printf "%s   Press ENTER to continue...%s" "${DIM}" "${RESET}"
  read -r input
  if [[ "${input}" == "q" ]]; then exit 0; fi
}

cleanup() {
  printf "\n"
  printf "%sClean up lab artifacts (containers, volume, backup, ./data)? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    podman rm -f db-vol 2>/dev/null || true
    podman volume rm dbdata 2>/dev/null || true
    rm -f "${SCRIPT_DIR}/backup.tar" 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT: ensure app-net exists, remove conflicting containers
# ═══════════════════════════════════════════════════════════════════════════

if ! podman network exists app-net 2>/dev/null; then
  printf "%s⚠ app-net not found – creating it now...%s\n" "${YELLOW}" "${RESET}"
  podman network create app-net
fi

podman rm -f db 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
#  LAB START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Lab 01d – Volumes & Bind Mounts                   ║\n"
printf "  ║   named volumes · export · bind mount permissions   ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Create a named volume ─────────────────────────────────────────────
banner "1 · Create a named volume"

comment "Named volumes are managed by podman – no path wrangling needed"
run "podman volume create dbdata"

# ── 2 · Run MariaDB with the volume ───────────────────────────────────────
banner "2 · Run MariaDB with the named volume"

comment "Mount the volume at the MariaDB data directory"
comment "The :Z flag sets the SELinux label (important on RHEL/OpenShift)"
run "podman run -d --name db-vol --network app-net -v dbdata:/var/lib/mysql:Z -e MARIADB_ROOT_PASSWORD=s3cret ${DB_IMAGE}"

comment "Wait for MariaDB to initialise..."
sleep 5

comment "Verify it is running"
run "podman ps --filter name=db-vol"

# ── 3 · Write some data ───────────────────────────────────────────────────
banner "3 · Write data to prove persistence"

comment "Create a test database"
run "podman exec db-vol mariadb -uroot -ps3cret -e 'CREATE DATABASE training; SHOW DATABASES;'"

# ── 4 · Restart and verify persistence ─────────────────────────────────────
banner "4 · Restart – data survives"

comment "Stop and remove the container"
run "podman rm -f db-vol"

comment "Start a fresh container with the same volume"
run "podman run -d --name db-vol --network app-net -v dbdata:/var/lib/mysql:Z -e MARIADB_ROOT_PASSWORD=s3cret ${DB_IMAGE}"

sleep 5

comment "The 'training' database is still there"
run "podman exec db-vol mariadb -uroot -ps3cret -e 'SHOW DATABASES;'"

discuss \
  "The volume outlives the container" \
  "" \
  "The container was deleted and recreated," \
  "but the data survived in the named volume." \
  "" \
  "In Kubernetes, this maps to a" \
  "PersistentVolumeClaim (PVC) --" \
  "same concept, different orchestrator."

# ── 5 · List and export the volume ────────────────────────────────────────
banner "5 · List and export volumes"

comment "List all volumes"
run "podman volume ls"

comment "Export the volume to a tar file (backup)"
run "podman volume export dbdata > ${SCRIPT_DIR}/backup.tar"

comment "Check the backup file"
run "ls -lh ${SCRIPT_DIR}/backup.tar"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Lab complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • Named volumes are the easiest way to persist data\n"
printf "  • Data in a volume survives container removal and recreation\n"
printf "  • podman volume export creates a portable tar backup\n"
printf "  • The :Z flag handles SELinux relabelling on RHEL systems\n"
printf "\n"
