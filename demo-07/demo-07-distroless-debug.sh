#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo 07 – Debugging distroless / hardened containers
#  Run: ./demo-07-distroless-debug.sh
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NGINX_IMAGE="registry.access.redhat.com/hi/nginx:1.28"
UBI_IMAGE="registry.access.redhat.com/ubi10/ubi"

# detect platform for cosign
ARCH=$(podman info --format '{{.Host.Arch}}' 2>/dev/null || uname -m)
case "${ARCH}" in
  arm64|aarch64) COSIGN_PLATFORM="linux/arm64" ;;
  *)             COSIGN_PLATFORM="linux/amd64" ;;
esac

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

run_expect_fail() {
  step=$((step + 1))
  printf "\n"
  printf "%s── step %s ──────────────────────────────────────────────────%s\n" "${DIM}" "${step}" "${RESET}"
  printf "%s▶ %s%s%s\n" "${GREEN}" "${CYAN}" "$*" "${RESET}"
  printf "%s   (this is expected to fail)%s\n" "${RED}" "${RESET}"
  printf "%s   Press ENTER to run (or 'q' to quit)...%s" "${DIM}" "${RESET}"
  read -r input
  if [[ "${input}" == "q" ]]; then
    printf "Demo aborted.\n"
    exit 0
  fi
  printf "\n"
  eval "$@" || true
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
  printf "%sClean up demo artifacts? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    podman rm -f web-hi 2>/dev/null || true
    rm -f "${SCRIPT_DIR}/index.html" 2>/dev/null || true
    rm -f "${SCRIPT_DIR}/nginx.sbom" 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT
# ═══════════════════════════════════════════════════════════════════════════

podman rm -f web-hi 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Demo 07 – Debugging distroless containers         ║\n"
printf "  ║   no shell · logs · sidecar · SBOM · signature      ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sDetected platform: %s%s%s\n" "${DIM}" "${CYAN}" "${COSIGN_PLATFORM}" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Start the hardened nginx ───────────────────────────────────────────
banner "1 · Start the hardened nginx image"

comment "Port 8080 -- this image runs as non-root (no port 80)"
comment "Bind-mount a custom html directory"
run "podman run -d --name web-hi -p 8001:8080 -v ${SCRIPT_DIR}/html:/usr/share/nginx/html:z ${NGINX_IMAGE}"

sleep 2

comment "Verify it is serving"
run "curl -s localhost:8001"

comment "Now try to exec into it -- no shell available!"
run_expect_fail "podman exec -it web-hi bash"

run_expect_fail "podman exec -it web-hi sh"

discuss \
  "No shell. No package manager." \
  "" \
  "Hardened / distroless images strip out" \
  "everything the app does not need:" \
  "  - No bash, sh, or any shell" \
  "  - No apt/dnf/yum" \
  "  - No coreutils (ls, cat, grep ...)" \
  "" \
  "Less software = smaller attack surface." \
  "But how do you debug?"

# ── 2 · Debug from the outside ────────────────────────────────────────────
banner "2 · Debug from the outside -- no shell needed"

comment "Logs -- always available, even without a shell"
run "podman logs web-hi"

comment "Process list -- uses the HOST's ps, not the container's"
run "podman top web-hi"

comment "How many binaries in /bin/? (export the filesystem as tar)"
run "podman export web-hi | tar -tf - | grep /bin/ | wc -l"

comment "For comparison: a regular UBI image has many more"
run "podman run --rm ${UBI_IMAGE} ls /bin/ | wc -l"

comment "Copy a file OUT of the container without a shell"
run "podman cp web-hi:/usr/share/nginx/html/index.html ${SCRIPT_DIR}/index.html"

comment "Inspect the copied file"
run "cat ${SCRIPT_DIR}/index.html"

discuss \
  "Debug tools that need nothing inside:" \
  "" \
  "  podman logs     - stdout/stderr" \
  "  podman top      - process list (host ps)" \
  "  podman export   - full filesystem as tar" \
  "  podman cp       - copy files in/out" \
  "  podman inspect  - config and metadata" \
  "" \
  "None of these require a shell or tools" \
  "inside the container."

# ── 3 · Debug sidecar ─────────────────────────────────────────────────────
banner "3 · Debug sidecar -- borrow a shell"

discuss \
  "The sidecar approach" \
  "" \
  "Attach a second container that shares the" \
  "network and PID namespace of the target." \
  "" \
  "You get a full shell + tools, but they" \
  "never enter the production image." \
  "" \
  "On Kubernetes: kubectl debug --target" \
  "(requires pods/ephemeralcontainers RBAC)"

comment "Start a UBI sidecar sharing web-hi's network + PIDs"
comment "Try: ps aux, curl localhost:8080, cat /proc/1/cmdline"
comment "Type 'exit' when done"
run "podman run --rm -it --network container:web-hi --pid container:web-hi ${UBI_IMAGE}"

# ── 4 · SBOM and signature ────────────────────────────────────────────────
banner "4 · SBOM + signature verification"

discuss \
  "Software Bill of Materials (SBOM)" \
  "" \
  "An SBOM lists every package in the image." \
  "Red Hat signs their images and attaches" \
  "SBOMs -- you can verify both with cosign." \
  "" \
  "cosign itself runs as a container --" \
  "nothing to install on your laptop."

comment "Download the SBOM for the nginx image"
comment "(a deprecation warning from upstream cosign is expected)"
run "podman run --rm registry.access.redhat.com/hi/cosign:latest download sbom --platform ${COSIGN_PLATFORM} ${NGINX_IMAGE} > ${SCRIPT_DIR}/nginx.sbom"

comment "First few lines of the SBOM:"
run "head -20 ${SCRIPT_DIR}/nginx.sbom"

comment "Verify the image signature against Red Hat's public key"
run "podman run --rm registry.access.redhat.com/hi/cosign:latest verify --key 'https://security.access.redhat.com/data/63405576.txt' --insecure-ignore-tlog ${NGINX_IMAGE}"

discuss \
  "Why this matters" \
  "" \
  "In production you should verify:" \
  "  1. The image is signed (not tampered)" \
  "  2. The SBOM matches (known contents)" \
  "  3. No critical CVEs (scan the SBOM)" \
  "" \
  "OpenShift can enforce signature" \
  "verification at admission time."

# ── Done ───────────────────────────────────────────────────────────────────
banner "Demo complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • Hardened images have no shell -- that is a feature\n"
printf "  • podman logs/top/export/cp work without a shell\n"
printf "  • A sidecar container can borrow network + PIDs for debugging\n"
printf "  • cosign verifies signatures and downloads SBOMs\n"
printf "  • On K8s: kubectl debug --target is the sidecar equivalent\n"
printf "\n"
