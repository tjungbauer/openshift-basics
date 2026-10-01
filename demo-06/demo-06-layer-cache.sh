#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo 06 – Watch where the layer cache stops
#  Run: ./demo-06-layer-cache.sh
#  Expects: hello-php/ subfolder with Containerfile and src/index.php
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${SCRIPT_DIR}/hello-php"

if [[ ! -f "${APP_DIR}/Containerfile" ]]; then
  printf "ERROR: %s/Containerfile not found.\n" "${APP_DIR}" >&2
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

pause() {
  printf "\n"
  printf "%s   Press ENTER to continue...%s" "${DIM}" "${RESET}"
  read -r input
  if [[ "${input}" == "q" ]]; then exit 0; fi
}

show_file() {
  printf "\n"
  printf "%s── file: %s ──────────────────────────────────────────%s\n" "${DIM}" "$1" "${RESET}"
  printf "%s" "${CYAN}"
  cat "$1"
  printf "%s\n" "${RESET}"
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
  printf "%sClean up demo artifacts (images)? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    podman rmi -f hello-php:1.0.0 hello-php:1.0.1 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
  if [[ -n "${INDEX_BACKUP}" && -f "${INDEX_BACKUP}" ]]; then
    cp "${INDEX_BACKUP}" "${APP_DIR}/src/index.php"
    rm -f "${INDEX_BACKUP}"
    printf "%sRestored original src/index.php.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Demo 06 – Watch where the layer cache stops       ║\n"
printf "  ║   build · rebuild · edit · rebuild                   ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── Show the Containerfile ─────────────────────────────────────────────────
banner "The hello-php Containerfile"

comment "Containerfile:"
show_file "${APP_DIR}/Containerfile"

comment "src/index.php:"
show_file "${APP_DIR}/src/index.php"

discuss \
  "7 steps in this Containerfile" \
  "" \
  "  1  FROM .../ubi10/php-83     (base image)" \
  "  2  USER 0                    (switch to root)" \
  "  3  COPY src/ /tmp/src/       (copy app code)" \
  "  4  RUN chown -R 1001:0 ...   (fix ownership)" \
  "  5  USER 1001                 (back to non-root)" \
  "  6  RUN .../s2i/assemble      (build the app)" \
  "  7  CMD .../s2i/run           (start command)" \
  "" \
  "Watch the build output for:" \
  "  --> Using cache <id>"

# back up index.php so we can restore it on exit
INDEX_BACKUP=$(mktemp "${TMPDIR:-/tmp}/index.php.bak.XXXXXX")
cp "${APP_DIR}/src/index.php" "${INDEX_BACKUP}"

# ── Build 1: first build, every step runs ──────────────────────────────────
banner "Build 1 · First build -- every step runs"

comment "First build: no cache exists yet, every step executes"
comment "Look for --> Using cache (there should be NONE)"
run "podman build -t hello-php:1.0.0 ${APP_DIR}"

discuss \
  "Build 1: every step ran" \
  "" \
  "No cache existed, so podman executed all" \
  "7 steps from scratch. This is the slowest" \
  "build -- the base image had to be pulled" \
  "and s2i/assemble ran for the first time."

# ── Build 2: nothing changed, full cache ───────────────────────────────────
banner "Build 2 · Rebuild with nothing changed"

comment "Same Containerfile, same source code"
comment "Look for --> Using cache after every STEP"
run "podman build -t hello-php:1.0.0 ${APP_DIR}"

discuss \
  "Build 2: every step used the cache" \
  "" \
  "Nothing changed, so podman reused every" \
  "cached layer. The build finishes in seconds." \
  "" \
  "For each step podman checks:" \
  "  Same instruction? Same input? Same layer" \
  "  below? Then reuse the cached result."

# ── Build 3: edit a source file ────────────────────────────────────────────
banner "Build 3 · Edit src/index.php and rebuild"

comment "Current src/index.php:"
show_file "${APP_DIR}/src/index.php"

pause

comment "Changing the greeting from 'Hello, World!' to 'Hello, OpenShift!'"

sed -i '' 's/Hello, World!/Hello, OpenShift!/' "${APP_DIR}/src/index.php"

printf "\n%s   BEFORE: %sHello, World!%s\n" "${DIM}" "${RED}" "${RESET}"
printf "%s   AFTER:  %sHello, OpenShift!%s\n\n" "${DIM}" "${GREEN}" "${RESET}"

comment "Updated src/index.php:"
show_file "${APP_DIR}/src/index.php"

pause

comment "Rebuild -- watch WHERE the cache stops"
comment "Steps 1-2 (FROM, USER 0): cached (unchanged)"
comment "Step 3 (COPY src/): NOT cached (file checksum changed)"
comment "Steps 4-7: must ALL re-run (even though they did not change)"
run "podman build -t hello-php:1.0.1 ${APP_DIR}"

discuss \
  "Build 3: cache broke at COPY" \
  "" \
  "FROM and USER 0 were still cached." \
  "But COPY compares checksums of the files." \
  "One file changed -> cache miss at step 3." \
  "" \
  "THE RULE: the first changed instruction" \
  "invalidates ALL layers after it." \
  "" \
  "Even USER 1001, chown, assemble, and CMD" \
  "had to re-run, although they did not change."

# ── Why this matters ───────────────────────────────────────────────────────
banner "Why this matters"

discuss \
  "In a real app, this is expensive" \
  "" \
  "If s2i/assemble runs 'composer install'" \
  "or 'npm install', every code change" \
  "reinstalls ALL dependencies." \
  "" \
  "The fix: order your Containerfile so that" \
  "  1. COPY dependency files first (lock files)" \
  "  2. RUN install dependencies" \
  "  3. COPY application code last" \
  "" \
  "This way, code changes only invalidate" \
  "the cheap COPY, not the expensive install."

# ── Done ───────────────────────────────────────────────────────────────────
banner "Demo complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • podman caches each build step as a layer\n"
printf "  • Same instruction + same input = cache hit\n"
printf "  • COPY checks file checksums, not just names\n"
printf "  • A cache miss invalidates ALL subsequent layers\n"
printf "  • Order matters: dependencies first, code last\n"
printf "\n"
