#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Lab 01a – Versioned Builds: two versions side by side
#  Run: ./lab-01a-versioned-builds.sh
#  Expects: hello-web/ subfolder with Containerfile and html/index.html
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="${SCRIPT_DIR}/hello-web"

if [[ ! -f "${LAB_DIR}/Containerfile" ]]; then
  printf "ERROR: %s/Containerfile not found.\n" "${LAB_DIR}" >&2
  exit 1
fi

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
INDEX_BACKUP=""

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

show_file() {
  printf "\n"
  printf "%s── file: %s ──────────────────────────────────────────%s\n" "${DIM}" "$1" "${RESET}"
  printf "%s" "${CYAN}"
  cat "$1"
  printf "%s\n" "${RESET}"
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
  printf "%sClean up lab artifacts (containers, images)? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    podman rm -f web-v1 2>/dev/null || true
    podman rm -f web-v2 2>/dev/null || true
    podman rmi -f hello-web:1.0.0 hello-web:1.1.0 2>/dev/null || true
    printf "%sCleaned up containers and images.%s\n" "${GREEN}" "${RESET}"
  fi
  if [[ -n "${INDEX_BACKUP}" && -f "${INDEX_BACKUP}" ]]; then
    cp "${INDEX_BACKUP}" "${LAB_DIR}/html/index.html"
    rm -f "${INDEX_BACKUP}"
    printf "%sRestored original html/index.html.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  LAB START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Lab 01a – Versioned Builds: two versions          ║\n"
printf "  ║              running side by side                    ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── Show existing lab files ────────────────────────────────────────────────
banner "Lab files in hello-web/"

comment "Containerfile:"
show_file "${LAB_DIR}/Containerfile"

comment "html/index.html:"
show_file "${LAB_DIR}/html/index.html"

pause

# back up index.html so we can restore it on exit
INDEX_BACKUP=$(mktemp "${TMPDIR:-/tmp}/index.html.bak.XXXXXX")
cp "${LAB_DIR}/html/index.html" "${INDEX_BACKUP}"

# ── Build v1.0.0 ───────────────────────────────────────────────────────────
banner "Build v1.0.0"

run "podman build -t hello-web:1.0.0 ${LAB_DIR}"

# ── Run v1.0.0 ─────────────────────────────────────────────────────────────
banner "Run v1.0.0 on port 8080"

run "podman run -d --name web-v1 -p 8080:8080 hello-web:1.0.0"

comment "Show running containers"
run "podman ps"

comment "Verify v1 is serving"
run "curl -s localhost:8080"

# ── Edit index.html ───────────────────────────────────────────────────────
banner "Edit html/index.html for v1.1.0"

comment "Current content:"
show_file "${LAB_DIR}/html/index.html"

pause

comment "Changing 'Version 1.0.0' → 'Version 1.1.0'"

sed -i '' 's/Version 1.0.0/Version 1.1.0/' "${LAB_DIR}/html/index.html"

printf "\n%s   BEFORE: %sVersion 1.0.0%s\n" "${DIM}" "${RED}" "${RESET}"
printf "%s   AFTER:  %sVersion 1.1.0%s\n\n" "${DIM}" "${GREEN}" "${RESET}"

comment "Updated html/index.html:"
show_file "${LAB_DIR}/html/index.html"

pause

# ── Build v1.1.0 ───────────────────────────────────────────────────────────
banner "Build v1.1.0"

run "podman build -t hello-web:1.1.0 ${LAB_DIR}"

# ── Run v1.1.0 alongside v1.0.0 ───────────────────────────────────────────
banner "Run v1.1.0 on port 8081 (alongside v1.0.0)"

run "podman run -d --name web-v2 -p 8081:8080 hello-web:1.1.0"

# ── Compare ────────────────────────────────────────────────────────────────
banner "Both versions running side by side"

comment "Show all running containers"
run "podman ps"

comment "v1.0.0 on port 8080:"
run "curl -s localhost:8080"

comment "v1.1.0 on port 8081:"
run "curl -s localhost:8081"

discuss \
  "Why does v1 still show the old content?" \
  "" \
  "The image is a snapshot -- it captured the" \
  "files at build time. The running container" \
  "uses those original layers." \
  "" \
  "Editing the source and rebuilding creates" \
  "a new, independent image. The old container" \
  "is unaffected."

# ── Done ───────────────────────────────────────────────────────────────────
banner "Lab complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • Each image tag is an immutable snapshot of that build\n"
printf "  • Multiple versions can run simultaneously on different ports\n"
printf "  • The container only includes what was COPYed at build time\n"
printf "  • Changing the source and rebuilding creates a new, independent image\n"
printf "\n"
printf "%s  web-v1 (1.0.0) → http://localhost:8080%s\n" "${DIM}" "${RESET}"
printf "%s  web-v2 (1.1.0) → http://localhost:8081%s\n" "${DIM}" "${RESET}"
printf "\n"
