#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Lab 01b – Runtime Basics: logs, shell, UID, ports
#  Run: ./lab-01b-runtime-basics.sh
#  Expects: hello-web:1.0.0 image and web-v1 container from lab-01a
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="${SCRIPT_DIR}/hello-web"

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
  printf "%sClean up lab artifacts (uid-test container)? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    podman stop uid-test 2>/dev/null || true
    podman rm -f uid-test 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT: ensure web-v1 and the image exist
# ═══════════════════════════════════════════════════════════════════════════

if ! podman image exists hello-web:1.0.0; then
  printf "%s⚠ hello-web:1.0.0 not found – building it now...%s\n" "${YELLOW}" "${RESET}"
  if [[ ! -f "${LAB_DIR}/Containerfile" ]]; then
    printf "ERROR: %s/Containerfile not found. Run lab-01a first.\n" "${LAB_DIR}" >&2
    exit 1
  fi
  podman build -t hello-web:1.0.0 "${LAB_DIR}"
fi

if ! podman container exists web-v1; then
  printf "%s⚠ web-v1 container not found – creating it now...%s\n" "${YELLOW}" "${RESET}"
  podman run -d --name web-v1 -p 8080:8080 hello-web:1.0.0
  sleep 1
fi

# ═══════════════════════════════════════════════════════════════════════════
#  LAB START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Lab 01b – Runtime Basics                          ║\n"
printf "  ║   logs · shell · arbitrary UID · ports              ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Exit code and logs of a stopped container ─────────────────────────
banner "1 · Exit code and logs of a stopped container"

comment "Stop web-v1 so we can inspect it in stopped state"
run "podman stop web-v1"

comment "Show the stopped container – note the exit code"
run "podman ps -a --filter name=web-v1"

comment "Logs are still available even after the container has stopped"
run "podman logs web-v1"

# ── 2 · Start a shell instead of the app ──────────────────────────────────
banner "2 · Start a shell instead of the app"

comment "Override the entrypoint to get an interactive shell"
comment "Try running: id, whoami, ls /var/www/html/, then type 'exit'"
run "podman run -it --rm --entrypoint /bin/bash hello-web:1.0.0"

# ── 3 · Simulate OpenShift: arbitrary UID, root group (GID 0) ─────────────
banner "3 · Simulate OpenShift: arbitrary UID, root group (GID 0)"

comment "OpenShift runs containers with a random UID but GID 0 (root group)"
comment "web-v1 is already stopped, so port 8080 is free"
run "podman run -d --rm --name uid-test -p 8080:8080 --user 100000:0 hello-web:1.0.0"

comment "Check which user the container is running as"
run "podman exec uid-test id"

comment "The app still works despite the random UID"
run "curl -s localhost:8080"

discuss \
  "Why does this work?" \
  "" \
  "OpenShift assigns a random UID per namespace" \
  "but always GID 0 (root group)." \
  "" \
  "Your image must:" \
  "  - Use an unprivileged port (>= 1024)" \
  "  - Make directories group-writable (GID 0)" \
  "  - Not rely on a specific UID"

# ── 4 · Ports ──────────────────────────────────────────────────────────────
banner "4 · Port mappings"

comment "Stop uid-test first to free port 8080 (--rm auto-removes it)"
run "podman stop uid-test"

comment "Start web-v1 again"
run "podman start web-v1"

comment "Show the port mappings for web-v1"
run "podman port web-v1"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Lab complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • Logs persist after a container stops – useful for debugging\n"
printf "  • --entrypoint lets you override the default command (e.g. for debugging)\n"
printf "  • OpenShift uses arbitrary UIDs with GID 0 – your image must handle this\n"
printf "  • podman port shows the host↔container port mappings\n"
printf "\n"
