#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo – Build & Run hello-web
#  Run: ./demo-hello-web.sh
#  Builds the hello-web container image, runs it, and curls the webpage.
# ---------------------------------------------------------------------------
set -euo pipefail

IMAGE_NAME="hello-web:1.0.0"
HOST_PORT=8080
CONTAINER_PORT=8080
CONTAINER_ID=""

# ── colours & helpers ──────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
RESET='\033[0m'

step=0

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
  echo
  echo -ne "${DIM}Clean up demo artifacts (stop container, remove image)? [y/N] ${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    if [[ -n "${CONTAINER_ID}" ]]; then
      podman rm -f "${CONTAINER_ID}" 2>/dev/null || true
    fi
    podman rmi -f "${IMAGE_NAME}" 2>/dev/null || true
    echo -e "${GREEN}Cleaned up.${RESET}"
  fi
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║        Demo – Build & Run hello-web                  ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "${DIM}Press ENTER to advance through each command.${RESET}"
echo -e "${DIM}Type 'q' + ENTER at any prompt to quit.${RESET}"

# ── Show the Containerfile ────────────────────────────────────────────────
banner "1 · Inspect the Containerfile"

comment "Let's look at the Containerfile we will build"
show_file "${SCRIPT_DIR}/Containerfile"

echo -ne "${DIM}   Press ENTER to continue...${RESET}"
read -r input
if [[ "${input}" == "q" ]]; then exit 0; fi

# ── Show the web content ─────────────────────────────────────────────────
banner "2 · Inspect the web content"

comment "The HTML page that will be served"
show_file "${SCRIPT_DIR}/html/index.html"

echo -ne "${DIM}   Press ENTER to continue...${RESET}"
read -r input
if [[ "${input}" == "q" ]]; then exit 0; fi

# ── Build ─────────────────────────────────────────────────────────────────
banner "3 · Build the container image"

comment "Build the image from the Containerfile"
run "podman build -t ${IMAGE_NAME} ${SCRIPT_DIR}"

comment "Verify the image exists"
run "podman images ${IMAGE_NAME}"

# ── Run ───────────────────────────────────────────────────────────────────
banner "4 · Run the container"

comment "Start the container in detached mode, mapping port ${HOST_PORT}"
run "CONTAINER_ID=\$(podman run -d -p ${HOST_PORT}:${CONTAINER_PORT} ${IMAGE_NAME}) && echo \"Container: \${CONTAINER_ID:0:12}\""

CONTAINER_ID=$(podman ps -q --filter ancestor="${IMAGE_NAME}" | head -1)

comment "List running containers"
run "podman ps --filter ancestor=${IMAGE_NAME}"

# ── Verify the webpage ───────────────────────────────────────────────────
banner "5 · Verify the webpage is served"

comment "Curl the running container to see the webpage"
run "curl -s http://localhost:${HOST_PORT}"

comment "Just the page title to confirm it's our app"
run "curl -s http://localhost:${HOST_PORT} | grep -o '<title>[^<]*</title>'"

# ── Stop & remove ─────────────────────────────────────────────────────────
banner "6 · Stop & remove the container"

comment "Stop the container gracefully"
run "podman stop ${CONTAINER_ID}"

comment "Remove the stopped container"
run "podman rm ${CONTAINER_ID}"

CONTAINER_ID=""

comment "Verify – no more running containers for this image"
run "podman ps -a --filter ancestor=${IMAGE_NAME}"

# ── Done ──────────────────────────────────────────────────────────────────
banner "Demo complete!"
echo
echo -e "${GREEN}Key takeaways:${RESET}"
echo "  • The Containerfile copies static HTML into the Apache document root"
echo "  • The image runs as non-root (UID 1001) on port 8080"
echo "  • curl confirms the container serves our webpage"
echo "  • Lifecycle: build → run → verify → stop → rm"
echo
