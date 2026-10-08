#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Lab 04 – Troubleshoot a broken deployment
#  Run: ./lab-04-troubleshoot.sh [REGISTRY]
#  Default registry: quay.io/tjungbau
#  Expects: oc logged in to an OpenShift cluster
# ---------------------------------------------------------------------------
set -euo pipefail

REGISTRY="${1:-quay.io/tjungbau}"
NGINX_IMAGE="docker.io/library/nginx:1.28"
RH_NGINX_IMAGE="registry.access.redhat.com/hi/nginx:1.28"
DEPLOY_NAME="broken"
APP_NAME="hello-web"

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
    printf "Lab aborted.\n"
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
    printf "Lab aborted.\n"
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
  printf "%sClean up lab resources? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    oc delete deployment "${DEPLOY_NAME}" 2>/dev/null || true
    oc delete deployment rh-nginx 2>/dev/null || true
    printf "%sCleaned up.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT
# ═══════════════════════════════════════════════════════════════════════════

if ! oc whoami &>/dev/null; then
  printf "%sERROR: Not logged in to OpenShift. Run 'oc login' first.%s\n" "${RED}" "${RESET}" >&2
  exit 1
fi

# clean up stale resources from previous runs
oc delete deployment "${DEPLOY_NAME}" 2>/dev/null || true
oc delete deployment rh-nginx 2>/dev/null || true

CLUSTER_USER=$(oc whoami)
CLUSTER_API=$(oc whoami --show-server)
NAMESPACE=$(oc project -q)
printf "%sLogged in as: %s%s%s\n" "${DIM}" "${CYAN}" "${CLUSTER_USER}" "${RESET}"
printf "%sCluster:      %s%s%s\n" "${DIM}" "${CYAN}" "${CLUSTER_API}" "${RESET}"
printf "%sNamespace:    %s%s%s\n" "${DIM}" "${YELLOW}" "${NAMESPACE}" "${RESET}"

# ═══════════════════════════════════════════════════════════════════════════
#  LAB START
# ═══════════════════════════════════════════════════════════════════════════

printf "\n%s" "${BOLD}"
printf "  ╔══════════════════════════════════════════════════════╗\n"
printf "  ║   Lab 04 – Troubleshoot a broken deployment          ║\n"
printf "  ║   deploy · investigate · debug · fix                 ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sRegistry: %s%s%s\n" "${DIM}" "${CYAN}" "${REGISTRY}" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Deploy the community nginx image ─────────────────────────────────
banner "1 · Deploy the community nginx image"

comment "Create a deployment using the upstream Docker Hub nginx"
run "oc create deployment ${DEPLOY_NAME} --image=${NGINX_IMAGE}"

comment "Wait a few seconds for the pod to attempt to start..."
sleep 5

comment "Check pod status -- expect CrashLoopBackOff"
run "oc get pods -l app=${DEPLOY_NAME}"

discuss \
  "The pod is crashing. Why?" \
  "" \
  "Community nginx expects:" \
  "  - To run as root (UID 0)" \
  "  - To bind to port 80 (privileged)" \
  "  - To write to /var/cache/nginx" \
  "" \
  "OpenShift's restricted SCC runs pods with" \
  "an arbitrary UID and drops all capabilities." \
  "Let us investigate..."

# ── 2 · Investigate the failure ───────────────────────────────────────────
banner "2 · Investigate: events, logs, SCC"

comment "Describe the pod -- look at Events and State sections"
run "oc describe pod -l app=${DEPLOY_NAME}"

comment "Check container logs for the actual error message"
run "oc logs deploy/${DEPLOY_NAME}"

comment "Which SCC was assigned to this pod?"
run "oc get pod -l app=${DEPLOY_NAME} -o jsonpath='{.items[0].metadata.annotations.openshift\.io/scc}'"
printf "\n"

discuss \
  "Security Context Constraints (SCC)" \
  "" \
  "OpenShift assigns an SCC to every pod." \
  "The 'restricted' SCC enforces:" \
  "" \
  "  - Random UID (not root, not the image's USER)" \
  "  - GID 0 (root group) -- but no root privileges" \
  "  - No privileged ports (below 1024)" \
  "  - Read-only root filesystem (depending on SCC)" \
  "  - Dropped Linux capabilities" \
  "" \
  "nginx:1.28 was built for Docker, not OpenShift." \
  "It assumes root -- and that assumption breaks."

# ── 3 · Reproduce with oc debug ──────────────────────────────────────────
banner "3 · Reproduce interactively with oc debug"

discuss \
  "oc debug deployment/<name>" \
  "" \
  "Starts a one-off pod with the same image" \
  "and config as the deployment, but:" \
  "  - Drops health/readiness probes" \
  "  - Overrides the entrypoint with a shell" \
  "  - Runs interactively so you can poke around" \
  "" \
  "Try these commands inside the debug pod:" \
  "  id" \
  "  touch /var/cache/nginx/test" \
  "  ls -la /var/cache/nginx/" \
  "  nginx -t" \
  "  exit"

comment "Start a debug shell -- try: id, touch /var/cache/nginx/test"
comment "Type 'exit' when done"
run "oc debug deployment/${DEPLOY_NAME}"

discuss \
  "What did you see?" \
  "" \
  "  id          -> uid=10000... (not root!)" \
  "  touch ...   -> Permission denied" \
  "  nginx -t    -> cannot open error_log, bind to :80" \
  "" \
  "The image's directories are owned by root." \
  "OpenShift runs you as a random UID." \
  "Result: permission denied everywhere."

# ── 4 · Fix it: switch to the OpenShift-ready image ──────────────────────
banner "4 · Fix: switch to your OpenShift-ready image"

comment "Replace the image with hello-web (built for OpenShift)"
run "oc set image deployment/${DEPLOY_NAME} nginx=${REGISTRY}/${APP_NAME}:1.0.0"

comment "Patch pull policy to ensure the fresh image is used"
run "oc patch deployment ${DEPLOY_NAME} -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"nginx\",\"imagePullPolicy\":\"Always\"}]}}}}'"

comment "Watch the rollout"
run "oc rollout status deployment/${DEPLOY_NAME} --timeout=60s"

comment "Verify -- should be Running now"
run "oc get pods -l app=${DEPLOY_NAME}"

discuss \
  "What makes an image OpenShift-ready?" \
  "" \
  "  1. Run as non-root (USER 1001 or similar)" \
  "  2. Listen on unprivileged port (>= 1024)" \
  "  3. Directories writable by GID 0" \
  "     (chgrp 0 + chmod g+rwx)" \
  "  4. No hardcoded UID assumptions" \
  "" \
  "Red Hat's S2I base images follow these rules." \
  "Our hello-web is built on ubi10/httpd-24," \
  "which handles all of this out of the box."

# ── 5 · Bonus: Red Hat's nginx image ─────────────────────────────────────
banner "Bonus · Red Hat's nginx -- does it work?"

comment "Deploy the Red Hat nginx image"
run "oc create deployment rh-nginx --image=${RH_NGINX_IMAGE} --port=8080"

comment "Wait a few seconds..."
sleep 10

comment "Check pod status -- it went to Completed, not Running!"
run "oc get pods -l app=rh-nginx"

comment "Check the logs to see why"
run "oc logs deploy/rh-nginx"

discuss \
  "This is an S2I builder image, not a runtime image!" \
  "" \
  "It printed usage instructions and exited." \
  "S2I (Source-to-Image) builder images expect" \
  "source code to be injected at build time:" \
  "" \
  "  oc new-app nginx:1.26~https://github.com/..." \
  "" \
  "The builder compiles/assembles your source" \
  "into a runnable image. Without source, it" \
  "just shows the help text and exits." \
  "" \
  "Lesson: not every image on the Red Hat" \
  "registry is a drop-in replacement." \
  "Check whether it is a builder or a runtime."

# ── Done ──────────────────────────────────────────────────────────────────
banner "Lab complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  * Community images often assume root -- they break on OpenShift\n"
printf "  * oc describe + oc logs + SCC annotation = your troubleshooting toolkit\n"
printf "  * oc debug lets you reproduce failures interactively\n"
printf "  * OpenShift-ready images: non-root, GID 0, unprivileged ports\n"
printf "  * Red Hat base images follow these patterns out of the box\n"
printf "\n"
