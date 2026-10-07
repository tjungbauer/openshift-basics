#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo 03 – ENTRYPOINT vs CMD
#  Run: ./demo-03-entrypoint-vs-cmd.sh
# ---------------------------------------------------------------------------
set -euo pipefail

# ── colours & helpers ──────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
RESET='\033[0m'

step=0
DEMO_DIR=""

banner() {
  echo
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${YELLOW}  $1${RESET}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

run() {
  step=$((step + 1))
  echo
  echo -e "${DIM}── step ${step} ──────────────────────────────────────────────────${RESET}"
  echo -e "${GREEN}▶ ${CYAN}$*${RESET}"
  echo -ne "${DIM}   Press ENTER to run (or 'q' to quit)...${RESET}"
  read -r input
  if [[ "${input}" == "q" ]]; then
    echo "Demo aborted."
    exit 0
  fi
  echo
  eval "$@"
}

comment() {
  echo
  echo -e "${YELLOW}# $*${RESET}"
}

show_file() {
  echo
  echo -e "${DIM}── file: $1 ─────────────────────────────────────────────────${RESET}"
  echo -e "${CYAN}"
  cat "$1"
  echo -e "${RESET}"
}

cleanup() {
  if [[ -n "${DEMO_DIR}" && -d "${DEMO_DIR}" ]]; then
    rm -rf "${DEMO_DIR}"
  fi
  podman rmi -f ep-demo 2>/dev/null || true
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║       Demo 03 – ENTRYPOINT vs CMD                    ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "${DIM}Press ENTER to advance through each command.${RESET}"
echo -e "${DIM}Type 'q' + ENTER at any prompt to quit.${RESET}"

# ── Prepare the Containerfile ──────────────────────────────────────────────
banner "Prepare the Containerfile"

DEMO_DIR=$(mktemp -d "${TMPDIR:-/tmp}/demo-03.XXXXXX")
cat > "${DEMO_DIR}/Containerfile" <<'CFILE'
FROM registry.access.redhat.com/ubi10/ubi-minimal
ENTRYPOINT ["echo","Hello"]
CMD ["World"]
CFILE

comment "ENTRYPOINT = the fixed executable"
comment "CMD        = default arguments (can be overridden)"
show_file "${DEMO_DIR}/Containerfile"

echo -ne "${DIM}   Press ENTER to continue...${RESET}"
read -r input
if [[ "${input}" == "q" ]]; then exit 0; fi

# ── Build ──────────────────────────────────────────────────────────────────
banner "Build the image"

run "podman build -t ep-demo ${DEMO_DIR}"

# ── Run with defaults ─────────────────────────────────────────────────────
banner "Run with default CMD"

comment "No arguments → ENTRYPOINT + CMD → echo Hello World"
run "podman run --rm ep-demo"

# ── Override CMD ───────────────────────────────────────────────────────────
banner "Override CMD at runtime"

comment "Pass 'Podman' → replaces CMD → echo Hello Podman"
run "podman run --rm ep-demo Podman"

# ── Override ENTRYPOINT ────────────────────────────────────────────────────
banner "Override ENTRYPOINT at runtime"

comment "Replace the entire ENTRYPOINT with /bin/ls"
comment "Now the argument '/' is passed to ls instead of echo"
run "podman run --rm --entrypoint /bin/ls ep-demo /"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Demo complete!"
echo
echo -e "${GREEN}Key takeaways:${RESET}"
echo "  • ENTRYPOINT defines the executable that always runs"
echo "  • CMD provides default arguments – easily overridden at runtime"
echo "  • Together they form the final command:  ENTRYPOINT + CMD"
echo "  • --entrypoint lets you replace the executable entirely"
echo
echo -e "${DIM}  ┌─────────────────────────────────────────────────────────┐"
echo "  │  podman run --rm ep-demo            →  echo Hello World  │"
echo "  │  podman run --rm ep-demo Podman     →  echo Hello Podman │"
echo "  │  podman run --rm --entrypoint /bin/ls ep-demo /  →  ls / │"
echo -e "  └─────────────────────────────────────────────────────────┘${RESET}"
echo
