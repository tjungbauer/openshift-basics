#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo 05 – Pods & Kubernetes YAML
#  Run: ./demo-05-pods-and-kube.sh
#  Expects: hello-web:1.0.0 image (rebuilds from lab-01/hello-web if missing)
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB01_DIR="${SCRIPT_DIR}/../lab-01/hello-web"
DB_IMAGE="registry.access.redhat.com/hi/mariadb:11.8"
APP_IMAGE="hello-web:1.0.0"

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
  printf "%sClean up demo artifacts? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    podman rm -f t 2>/dev/null || true
    podman pod rm -f dev 2>/dev/null || true
    rm -f "${SCRIPT_DIR}/dev-pod.yaml" 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT
# ═══════════════════════════════════════════════════════════════════════════

podman rm -f t 2>/dev/null || true
podman pod rm -f dev 2>/dev/null || true

if ! podman image exists "${APP_IMAGE}"; then
  if [[ -f "${LAB01_DIR}/Containerfile" ]]; then
    printf "%s⚠ %s not found – building it now...%s\n" "${YELLOW}" "${APP_IMAGE}" "${RESET}"
    podman build -t "${APP_IMAGE}" "${LAB01_DIR}"
  else
    printf "ERROR: %s not found and %s/Containerfile missing.\n" "${APP_IMAGE}" "${LAB01_DIR}" >&2
    printf "Run lab-01a first, or build the image manually.\n" >&2
    exit 1
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Demo 05 – Pods & Kubernetes YAML                  ║\n"
printf "  ║   smoke test · pods · generate · play               ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Smoke test ────────────────────────────────────────────────────────
banner "1 · Smoke test: does the image start and answer?"

comment "Start the container"
run "podman run -d --name t -p 8080:8080 ${APP_IMAGE}"

comment "Wait for the container to be ready (retry up to 10 times)"
run "for i in \$(seq 1 10); do curl -fs localhost:8080 && break; sleep 1; done"

comment "Show it is running"
run "podman ps --filter name=t"

comment "Clean up the test container"
run "podman rm -f t"

discuss \
  "Why a smoke test?" \
  "" \
  "Before pushing to a registry or deploying," \
  "verify the image actually starts and serves." \
  "" \
  "A quick curl loop catches:" \
  "  - Missing entrypoint / wrong CMD" \
  "  - Permission errors (wrong UID)" \
  "  - Port mismatches"

# ── 2 · App + database in one pod ─────────────────────────────────────────
banner "2 · App + database in ONE pod"

discuss \
  "What is a pod?" \
  "" \
  "A pod groups containers that share:" \
  "  - The same network namespace (localhost)" \
  "  - The same port space" \
  "  - Optionally the same volumes" \
  "" \
  "This is exactly how Kubernetes Pods work." \
  "podman pods let you test that locally."

comment "Create a pod with port 8080 published"
run "podman pod create --name dev -p 8080:8080"

comment "Add MariaDB to the pod"
run "podman run -d --pod dev --name db -e MARIADB_ROOT_PASSWORD=s3cret ${DB_IMAGE}"

comment "Add the web app to the same pod"
run "podman run -d --pod dev --name app ${APP_IMAGE}"

comment "Wait for the containers to start..."
sleep 3

comment "Show all containers in the pod"
run "podman pod ps"
run "podman ps --filter pod=dev"

comment "The web app is reachable on the pod's published port"
run "curl -s localhost:8080"

discuss \
  "Containers in a pod share localhost" \
  "" \
  "The app container could reach MariaDB at" \
  "localhost:3306 -- no network setup needed." \
  "" \
  "Ports are published on the pod, not on" \
  "individual containers."

# ── 3 · Turn the pod into Kubernetes YAML ──────────────────────────────────
banner "3 · Generate Kubernetes YAML from the pod"

comment "Export the running pod as a Kubernetes Pod manifest"
run "podman generate kube dev > ${SCRIPT_DIR}/dev-pod.yaml"

comment "The generated YAML:"
show_file "${SCRIPT_DIR}/dev-pod.yaml"

pause

discuss \
  "podman generate kube" \
  "" \
  "Creates a valid Kubernetes Pod YAML from" \
  "a running pod. Useful for:" \
  "  - Prototyping locally, deploying to K8s" \
  "  - Generating a starting point for manifests" \
  "" \
  "The YAML usually needs some cleanup" \
  "(remove podman-specific annotations," \
  " add resource limits, probes, etc.)."

# ── 4 · Destroy and recreate from YAML ────────────────────────────────────
banner "4 · Destroy and recreate from YAML"

comment "Remove the running pod completely"
run "podman pod rm -f dev"

comment "Verify it is gone"
run "podman pod ps"

comment "Recreate everything from the YAML"
run "podman kube play ${SCRIPT_DIR}/dev-pod.yaml"

comment "Wait for the containers to start..."
sleep 5

comment "The pod is back"
run "podman pod ps"
run "podman ps --filter pod=dev"

comment "And the app is serving again"
run "curl -s localhost:8080"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Demo complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • Always smoke-test your image before pushing\n"
printf "  • Pods group containers that share localhost\n"
printf "  • podman generate kube exports a pod as K8s YAML\n"
printf "  • podman kube play recreates a pod from YAML\n"
printf "  • This is how you prototype locally for Kubernetes\n"
printf "\n"
