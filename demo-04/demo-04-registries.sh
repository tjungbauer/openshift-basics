#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo 04 – Registries: tag, push, inspect, housekeeping
#  Run: ./demo-04-registries.sh [REGISTRY]
#  Default registry: quay.io/tjungbau
# ---------------------------------------------------------------------------
set -euo pipefail

REGISTRY="${1:-quay.io/tjungbau}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB01_DIR="${SCRIPT_DIR}/../lab-01/hello-web"

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

# ═══════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT: ensure hello-web:1.0.0 exists
# ═══════════════════════════════════════════════════════════════════════════

if ! podman image exists hello-web:1.0.0; then
  if [[ -f "${LAB01_DIR}/Containerfile" ]]; then
    printf "%s⚠ hello-web:1.0.0 not found – building it now...%s\n" "${YELLOW}" "${RESET}"
    podman build --platform linux/amd64 -t hello-web:1.0.0 "${LAB01_DIR}"
  else
    printf "ERROR: hello-web:1.0.0 not found and %s/Containerfile missing.\n" "${LAB01_DIR}" >&2
    printf "Run lab-01a first, or build the image manually.\n" >&2
    exit 1
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Demo 04 – Registries                              ║\n"
printf "  ║   tag · push · remote inspect · housekeeping        ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sRegistry: %s%s%s\n" "${DIM}" "${CYAN}" "${REGISTRY}" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Image naming convention ───────────────────────────────────────────
banner "1 · Image naming convention"

discuss \
  "Fully qualified image name:" \
  "" \
  "  registry / organisation / repository : tag" \
  "" \
  "  quay.io  / tjungbau     / hello-web  : 1.0.0" \
  "" \
  "Without a registry prefix, podman searches" \
  "the registries listed in registries.conf" \
  "(typically docker.io, then quay.io)."

# ── 2 · Tag for the registry ──────────────────────────────────────────────
banner "2 · Tag the image for the registry"

comment "Tag the local image with the full registry path"
comment "This does NOT copy the image -- it adds another name"
run "podman tag hello-web:1.0.0 ${REGISTRY}/hello-web:1.0.0"

comment "Both names now point to the same image ID"
run "podman images hello-web"

# ── 3 · Log in and push ───────────────────────────────────────────────────
banner "3 · Log in and push"

comment "Authenticate to the registry"
run "podman login quay.io"

comment "Push the image to the registry"
run "podman push ${REGISTRY}/hello-web:1.0.0"

discuss \
  "What just happened?" \
  "" \
  "podman pushed only the layers the registry" \
  "does not already have (delta upload)." \
  "" \
  "The image is now available to anyone with" \
  "pull access to ${REGISTRY}."

# ── 4 · Inspect remotely with skopeo ──────────────────────────────────────
banner "4 · Inspect remotely (without pulling)"

comment "skopeo can inspect an image in the registry"
comment "without downloading it -- useful for CI/CD and auditing"
run "skopeo inspect docker://${REGISTRY}/hello-web:1.0.0"

discuss \
  "Why skopeo?" \
  "" \
  "skopeo works without a container runtime." \
  "It can:" \
  "  - Inspect digests, labels, layers" \
  "  - Copy between registries" \
  "  - Delete tags from a registry" \
  "" \
  "Great for CI pipelines where you do not" \
  "want a full podman/docker install."

# ── 5 · Housekeeping ──────────────────────────────────────────────────────
banner "5 · Housekeeping on your laptop"

comment "List all local images"
run "podman images"

comment "Remove a specific image by tag"
run "podman rmi hello-web:1.0.0"

comment "Remove dangling images (untagged, unused layers)"
run "podman image prune"

comment "Verify what is left"
run "podman images"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Demo complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • podman tag adds a name -- it does not copy the image\n"
printf "  • podman push uploads only missing layers (delta)\n"
printf "  • skopeo inspects remote images without pulling\n"
printf "  • podman image prune cleans up dangling layers\n"
printf "  • Always use fully qualified image names in production\n"
printf "\n"
