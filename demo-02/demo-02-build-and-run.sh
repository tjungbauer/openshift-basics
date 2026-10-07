#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo 02 – Build & Run a Container
#  Run: ./demo-02-build-and-run.sh
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
CONTAINER_ID=""

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
  if [[ -n "${CONTAINER_ID}" ]]; then
    podman rm -f "${CONTAINER_ID}" 2>/dev/null || true
  fi
  if [[ -n "${DEMO_DIR}" && -d "${DEMO_DIR}" ]]; then
    rm -rf "${DEMO_DIR}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║      Demo 02 – Build & Run a Container               ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "${DIM}Press ENTER to advance through each command.${RESET}"
echo -e "${DIM}Type 'q' + ENTER at any prompt to quit.${RESET}"

# ── Prepare the Containerfile ──────────────────────────────────────────────
banner "Prepare the Containerfile"

DEMO_DIR=$(mktemp -d "${TMPDIR:-/tmp}/demo-02.XXXXXX")
cat > "${DEMO_DIR}/Containerfile" <<'CFILE'
FROM docker.io/library/busybox:1.37

ARG APP_VERSION=0.0.0

RUN mkdir -p /www && \
    printf '<html><body style="font-family:sans-serif">\n<h1>simple-app</h1>\n<p>version: %s</p>\n</body></html>\n' \
      "${APP_VERSION}" > /www/index.html && \
    chmod 0755 /www && chmod 0644 /www/index.html

EXPOSE 8080

USER 1001

ENTRYPOINT ["/bin/busybox", "httpd", "-f", "-v", "-p", "8080", "-h", "/www"]
CFILE

comment "We created this Containerfile:"
show_file "${DEMO_DIR}/Containerfile"

echo -ne "${DIM}   Press ENTER to continue...${RESET}"
read -r input
if [[ "${input}" == "q" ]]; then exit 0; fi

# ── Build ──────────────────────────────────────────────────────────────────
banner "Build the image"

comment "Build with a build-arg to bake the version into the HTML"
run "podman build -t simple-app:1.0.0 --build-arg APP_VERSION=1.0.0 ${DEMO_DIR}"

# ── Run ────────────────────────────────────────────────────────────────────
banner "Run the container"

comment "Start the container in detached mode, mapping port 8080"
run "CONTAINER_ID=\$(podman run -d -p 8080:8080 simple-app:1.0.0) && echo \"Container: \${CONTAINER_ID:0:12}\""

CONTAINER_ID=$(podman ps -q --filter ancestor=simple-app:1.0.0 | head -1)

comment "Verify – curl the running container"
run "curl -s localhost:8080"

# ── Inspect the running container ──────────────────────────────────────────
banner "Inspect the running container"

comment "List running containers"
run "podman ps --filter ancestor=simple-app:1.0.0"

# ── Stop & remove ──────────────────────────────────────────────────────────
banner "Stop & remove the container"

comment "Stop the container gracefully"
run "podman stop ${CONTAINER_ID}"

comment "Remove the stopped container"
run "podman rm ${CONTAINER_ID}"

comment "Verify – no more running containers for this image"
run "podman ps -a --filter ancestor=simple-app:1.0.0"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Demo complete!"
echo
echo -e "${GREEN}Key takeaways:${RESET}"
echo "  • ARG lets you inject values at build time (e.g. version strings)"
echo "  • USER 1001 means the container runs as non-root"
echo "  • EXPOSE documents the port – the -p flag actually publishes it"
echo "  • Lifecycle: build → run → stop → rm"
echo
