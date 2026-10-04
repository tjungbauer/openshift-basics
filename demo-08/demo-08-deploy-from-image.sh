#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Demo 08 – Deploy a container image on OpenShift
#  Run: ./demo-08-deploy-from-image.sh
# ---------------------------------------------------------------------------
set -euo pipefail

NS="hello-web"
REGISTRY="quay.io/tjungbau"
IMAGE="${REGISTRY}/hello-web:1.0.0"

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
    oc delete route hello-web -n "${NS}" 2>/dev/null || true
    oc delete svc hello-web -n "${NS}" 2>/dev/null || true
    oc delete deployment hello-web -n "${NS}" 2>/dev/null || true
    oc delete project "${NS}" 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  DEMO START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Demo 08 – Deploy a container image on OpenShift   ║\n"
printf "  ║   deployment · service · route · curl               ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sImage:     %s%s%s\n" "${DIM}" "${CYAN}" "${IMAGE}" "${RESET}"
printf "%sNamespace: %s%s%s\n" "${DIM}" "${CYAN}" "${NS}" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Create the project ───────────────────────────────────────────────
banner "1 · Create a new project"

comment "Create a dedicated namespace for this demo"
run "oc new-project ${NS}"

# ── 2 · Create the Deployment ────────────────────────────────────────────
banner "2 · Create a Deployment from the container image"

comment "One command -- OpenShift pulls the image and creates a Deployment"
run "oc create deployment hello-web --image=${IMAGE} --port=8080 -n ${NS}"

comment "Wait for the pod to be ready"
run "oc rollout status deployment/hello-web -n ${NS} --timeout=60s"

comment "Check the pod"
run "oc get pods -n ${NS}"

discuss \
  "What about private registries?" \
  "" \
  "Our image on quay.io is public, so no" \
  "credentials are needed. For private images:" \
  "" \
  "  oc create secret docker-registry my-pull-secret \\" \
  "    --docker-server=quay.io \\" \
  "    --docker-username=<robot-account> \\" \
  "    --docker-password=<token>" \
  "" \
  "  oc secrets link default my-pull-secret --for=pull" \
  "" \
  "This links the pull secret to the default" \
  "ServiceAccount so pods can pull automatically."

# ── 3 · Expose via Service + Route ────────────────────────────────────────
banner "3 · Expose the Deployment with a Service and Route"

comment "Create a ClusterIP Service on port 8080"
run "oc expose deployment hello-web --port=8080 -n ${NS}"

comment "Create an edge-terminated Route (TLS at the router)"
run "oc create route edge hello-web --service=hello-web -n ${NS}"

comment "Show all created resources"
run "oc get deployment,pods,svc,route -n ${NS}"

# ── 4 · Verify ────────────────────────────────────────────────────────────
banner "4 · Verify the application is reachable"

comment "Curl the route"
run "curl -sk https://\$(oc get route hello-web -n ${NS} -o jsonpath='{.spec.host}')"

discuss \
  "What just happened?" \
  "" \
  "  Deployment  → manages ReplicaSet → runs Pod" \
  "  Service     → stable ClusterIP for the pods" \
  "  Route       → external HTTPS URL via HAProxy" \
  "" \
  "The router terminates TLS (edge) and forwards" \
  "plain HTTP to port 8080 inside the pod." \
  "" \
  "This is the simplest way to go from a" \
  "container image to a running, reachable app."

# ── Done ──────────────────────────────────────────────────────────────────
banner "Demo complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • oc create deployment -- one command to run any image\n"
printf "  • oc expose -- creates a Service from a Deployment\n"
printf "  • oc create route edge -- TLS-terminated external access\n"
printf "  • Private registries need a pull secret linked to the SA\n"
printf "\n"
