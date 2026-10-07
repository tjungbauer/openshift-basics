#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Lab 02 – Why UID matters: root vs non-root images
#  Run: ./lab-02-uid-security.sh
#  Expects: hello-web:1.0.0 image (rebuilds from ../lab-01/hello-web if missing)
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB01_DIR="${SCRIPT_DIR}/../lab-01/hello-web"

# ── colours & helpers ──────────────────────────────────────────────────────
BOLD=$'\033[1m'
CYAN=$'\033[1;36m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'
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

discuss() {
  local inner=72
  local border pad
  printf "\n"
  border=$(printf '═%.0s' $(seq 1 "${inner}"))
  pad=$(printf ' %.0s' $(seq 1 "${inner}"))

  # collect all lines, truncate to fit
  local -a lines=()
  lines+=("$1")
  shift
  for arg in "$@"; do
    lines+=("${arg}")
  done

  printf "%s%s╔%s╗%s\n" "${BG_DISCUSS}" "${FG_TITLE}" "${border}" "${RESET}"
  printf "%s%s║%s║%s\n" "${BG_DISCUSS}" "${FG_TITLE}" "${pad}" "${RESET}"

  local first=1
  for line in "${lines[@]}"; do
    # truncate if too long (inner - 4 for "║  " and " ║")
    local maxlen=$((inner - 4))
    if [[ ${#line} -gt ${maxlen} ]]; then
      line="${line:0:${maxlen}}"
    fi
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
  printf "%sClean up lab artifacts (containers)? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    podman rm -f ngx 2>/dev/null || true
    podman rm -f web-uid 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT: clean up stale containers, ensure hello-web:1.0.0 exists
# ═══════════════════════════════════════════════════════════════════════════

podman rm -f ngx 2>/dev/null || true
podman rm -f web-uid 2>/dev/null || true

if ! podman image exists hello-web:1.0.0; then
  if [[ -f "${LAB01_DIR}/Containerfile" ]]; then
    printf "%s⚠ hello-web:1.0.0 not found – building it now...%s\n" "${YELLOW}" "${RESET}"
    podman build -t hello-web:1.0.0 "${LAB01_DIR}"
  else
    printf "ERROR: hello-web:1.0.0 not found and %s/Containerfile missing.\n" "${LAB01_DIR}" >&2
    printf "Run lab-01a first, or build the image manually.\n" >&2
    exit 1
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
#  LAB START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Lab 02 – Why UID matters                           ║\n"
printf "  ║   root vs non-root images on OpenShift               ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Run nginx with a random UID ───────────────────────────────────────
banner "1 · Run nginx with a random UID (like OpenShift would)"

comment "OpenShift assigns a random UID with GID 0 to every container"
comment "Let's simulate that with --user 100000:0 (on a real cluster this would be ~1000680000)"
run "podman run -d --name ngx --user 100000:0 docker.io/library/nginx:1.28"

# ── 2 · Read the logs ─────────────────────────────────────────────────────
banner "2 · Read the logs – what fails?"

comment "Give the container a moment to try starting..."
sleep 2

run "podman logs ngx"

discuss \
  "What exactly fails and why?" \
  "" \
  "nginx crashes before it even starts listening:" \
  "  - mkdir /var/cache/nginx/client_temp" \
  "    -> Permission denied" \
  "  - The cache dir is owned by root," \
  "    our UID cannot write to it" \
  "  - The 'user' directive is ignored" \
  "    (only works as root)" \
  "" \
  "It never gets to bind port 80 --" \
  "it fails earlier on file permissions."

# ── 3 · Run hello-web with the same UID ───────────────────────────────────
banner "3 · Run hello-web with the same random UID"

comment "Same UID, same GID 0 – but does hello-web handle it?"
run "podman run -d --name web-uid --user 100000:0 -p 8080:8080 hello-web:1.0.0"

sleep 2

comment "Does it work?"
run "curl -s localhost:8080"

discuss \
  "Why does hello-web work but nginx doesn't?" \
  "" \
  "hello-web was built for non-root:" \
  "  • Listens on port 8080 (unprivileged)" \
  "  • Directories are group-writable (GID 0)" \
  "  • No files require root ownership"

# ── 4 · Compare the default user of both images ───────────────────────────
banner "4 · Compare the default user"

comment "What user does the nginx image default to?"
run "podman image inspect docker.io/library/nginx:1.28 --format '{{.Config.User}}'"

printf "\n"
printf "%s   → empty = root (UID 0)%s\n" "${RED}" "${RESET}"

comment "What user does hello-web default to?"
run "podman image inspect hello-web:1.0.0 --format '{{.Config.User}}'"

printf "\n"
printf "%s   → non-root by design%s\n" "${GREEN}" "${RESET}"

# ── 5 · Discussion ────────────────────────────────────────────────────────
banner "5 · What would you change in the nginx image?"

discuss \
  "To make nginx work with an arbitrary UID:" \
  "" \
  "1. Use an unprivileged port (8080 not 80)" \
  "2. Make dirs group-writable (GID 0):" \
  "   chmod -R g+rwX /var/cache/nginx" \
  "                   /var/run /var/log/nginx" \
  "3. Set USER to a non-root UID" \
  "" \
  "Or use a Red Hat UBI nginx image" \
  "-- it does all of this out of the box:" \
  "  registry.access.redhat.com/ubi10/nginx-126"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Lab complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • OpenShift runs containers with a random UID and GID 0\n"
printf "  • Images that expect root will fail on OpenShift\n"
printf "  • Use unprivileged ports (>= 1024)\n"
printf "  • Make directories group-writable for GID 0\n"
printf "  • Set a non-root USER in the Containerfile\n"
printf "  • Red Hat UBI-based images are built for this out of the box\n"
printf "\n"
