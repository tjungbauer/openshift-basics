#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo 01 – Container Image Basics
#  Run: ./demo-01-image-basics.sh [IMAGE]
#  Default image: registry.access.redhat.com/ubi9/httpd-24:latest
# ---------------------------------------------------------------------------
set -euo pipefail

IMG="${1:-registry.access.redhat.com/ubi9/httpd-24:latest}"

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

# ── cleanup helper ─────────────────────────────────────────────────────────
cleanup() {
  echo
  echo -ne "${DIM}Clean up demo artifacts (Containerfile, web:1.0 images)? [y/N] ${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    rm -f Containerfile
    podman rmi -f web:1.0 2>/dev/null || true
    echo -e "${GREEN}Cleaned up.${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║        Demo 01 – Container Image Basics             ║"
echo "  ║                                                      ║"
echo "  ║  Image: ${IMG}"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "${DIM}Press ENTER to advance through each command.${RESET}"
echo -e "${DIM}Type 'q' + ENTER at any prompt to quit.${RESET}"

# ── Pull the image ─────────────────────────────────────────────────────────
banner "Pull the container image"

run "podman pull ${IMG}"

# ── Section 1: Layers ──────────────────────────────────────────────────────
banner "1 · Layers – one entry per build step, newest on top"

comment "Show the layer history of the image"
run "podman history ${IMG}"

comment "More details – exact size and the Dockerfile instruction that created each layer"
run "podman history --no-trunc --format '{{.Size}} {{.CreatedBy}}' ${IMG}"

# ── Section 2: Metadata ───────────────────────────────────────────────────
banner "2 · Metadata – who runs it, which ports, what starts"

comment "Which user does the container run as?"
run "podman image inspect ${IMG} --format '{{.Config.User}}'"

comment "Which ports are declared as exposed?"
run "podman image inspect ${IMG} --format '{{.Config.ExposedPorts}}'"

comment "What is the default command (entrypoint / CMD)?"
run "podman image inspect ${IMG} --format '{{.Config.Cmd}}'"

# ── Section 3: Tags vs Digests ────────────────────────────────────────────
banner "3 · Tags move – digests do not"

comment "Every image has an immutable digest (sha256 hash of the manifest)"
run "podman image inspect ${IMG} --format '{{.Digest}}'"

comment "Build two images with the SAME tag but different labels"
comment "→ The tag 'web:1.0' will point to the SECOND build"
comment "→ The digest of each build is different"

run "echo 'FROM ${IMG}' > Containerfile"

comment "First build – tagged web:1.0, label build=1"
run "podman build -q -t web:1.0 --label build=1 ."

comment "Second build – same tag web:1.0, but label build=2"
run "podman build -q -t web:1.0 --label build=2 ."

comment "Which build does the tag point to now?"
run "podman image inspect web:1.0 --format 'label build={{index .Config.Labels \"build\"}}  digest={{.Digest}}'"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Demo complete!"
echo
echo -e "${GREEN}Key takeaways:${RESET}"
echo "  • Images are built from layers – each Dockerfile instruction creates one"
echo "  • Metadata (user, ports, cmd) is baked into the image config"
echo "  • Tags are mutable pointers – digests are the only stable reference"
echo
