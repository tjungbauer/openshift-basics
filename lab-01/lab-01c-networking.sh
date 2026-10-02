#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Lab 01c – Container Networking
#  Run: ./lab-01c-networking.sh
# ---------------------------------------------------------------------------
set -euo pipefail

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
  printf "%sClean up lab artifacts (containers, network)? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    podman rm -f db 2>/dev/null || true
    podman network rm app-net 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  LAB START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Lab 01c – Container Networking                    ║\n"
printf "  ║   custom networks · DNS by name · inspect · ports   ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Create a custom network ───────────────────────────────────────────
banner "1 · Create a custom network"

comment "Containers on the default network cannot resolve each other by name"
comment "A custom network enables DNS-based service discovery"
run "podman network create app-net"

# ── 2 · Start MariaDB on the custom network ───────────────────────────────
banner "2 · Start MariaDB on the custom network"

comment "Run MariaDB with --name db on app-net"
comment "The container name 'db' becomes the DNS hostname"
run "podman run -d --name db --network app-net -e MARIADB_ROOT_PASSWORD=s3cret ${DB_IMAGE}"

comment "Wait a moment for MariaDB to start up..."
sleep 3

comment "Verify it is running"
run "podman ps --filter name=db"

# ── 3 · Connect from a second container by name ───────────────────────────
banner "3 · Connect from a second container by name"

comment "Launch a second container on the same network"
comment "It can reach MariaDB using the hostname 'db'"
comment "Run: SHOW DATABASES; then type 'exit'"
run "podman run --rm -it --network app-net ${DB_IMAGE} mariadb -hdb -uroot -ps3cret"

# ── 4 · Inspect the network ───────────────────────────────────────────────
banner "4 · Inspect the network"

comment "Show which containers are attached and their IPs"
run "podman network inspect app-net"

# ── 5 · Port mappings ─────────────────────────────────────────────────────
banner "5 · Port mappings"

comment "The db container has no published ports (-p was not used)"
comment "It is only reachable from within app-net"
run "podman port db"

discuss \
  "No published ports -- internal only" \
  "" \
  "The db container is reachable by name" \
  "from within app-net, but not from the host." \
  "" \
  "In Kubernetes, this maps to a Service:" \
  "  - Internal DNS (ClusterIP) for pod-to-pod" \
  "  - No external access unless you" \
  "    create a Route or NodePort"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Lab complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • Custom networks provide DNS-based service discovery by container name\n"
printf "  • Containers on the same network can talk to each other without -p\n"
printf "  • -p publishes a port to the host – without it the service is network-internal\n"
printf "  • podman network inspect shows IPs and attached containers\n"
printf "\n"
