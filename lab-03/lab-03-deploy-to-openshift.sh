#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Lab 03 – Deploy to OpenShift
#  Run: ./lab-03-deploy-to-openshift.sh [REGISTRY]
#  Default registry: quay.io/tjungbau
#  Expects: hello-web/ subfolder, oc logged in to a cluster
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="${SCRIPT_DIR}/hello-web"
REGISTRY="${1:-quay.io/tjungbau}"
APP_NAME="hello-web"

if [[ ! -f "${LAB_DIR}/Containerfile" ]]; then
  printf "ERROR: %s/Containerfile not found.\n" "${LAB_DIR}" >&2
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
  printf "%sClean up OpenShift resources? [y/N] %s" "${DIM}" "${RESET}"
  read -r answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    oc delete route "${APP_NAME}" 2>/dev/null || true
    oc delete service "${APP_NAME}" 2>/dev/null || true
    oc delete deployment "${APP_NAME}" 2>/dev/null || true
    printf "%sCleaned up OpenShift resources.%s\n" "${GREEN}" "${RESET}"
  fi
  if [[ -n "${INDEX_BACKUP}" && -f "${INDEX_BACKUP}" ]]; then
    cp "${INDEX_BACKUP}" "${LAB_DIR}/html/index.html"
    rm -f "${INDEX_BACKUP}"
    printf "%sRestored original html/index.html.%s\n" "${GREEN}" "${RESET}"
  fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
#  PRE-FLIGHT: check oc login, build images
# ═══════════════════════════════════════════════════════════════════════════

if ! oc whoami &>/dev/null; then
  printf "%sERROR: Not logged in to OpenShift. Run 'oc login' first.%s\n" "${RED}" "${RESET}" >&2
  exit 1
fi

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
printf "  ║   Lab 03 – Deploy to OpenShift                       ║\n"
printf "  ║   push · deploy · route · scale · rollout            ║\n"
printf "  ╚══════════════════════════════════════════════════════╝\n"
printf "%s\n" "${RESET}"
printf "%sRegistry: %s%s%s\n" "${DIM}" "${CYAN}" "${REGISTRY}" "${RESET}"
printf "%sPress ENTER to advance through each command.%s\n" "${DIM}" "${RESET}"
printf "%sType 'q' + ENTER at any prompt to quit.%s\n" "${DIM}" "${RESET}"

# ── 1 · Build and push both versions ──────────────────────────────────────
banner "1 · Build and push both versions to the registry"

# back up index.html so we can restore it on exit
INDEX_BACKUP=$(mktemp "${TMPDIR:-/tmp}/index.html.bak.XXXXXX")
cp "${LAB_DIR}/html/index.html" "${INDEX_BACKUP}"

comment "Build v1.0.0 (--platform linux/amd64 for OpenShift clusters)"
run "podman build --platform linux/amd64 -t ${REGISTRY}/${APP_NAME}:1.0.0 ${LAB_DIR}"

comment "Edit index.html for v1.1.0"
sed -i '' 's/Version 1.0.0/Version 1.1.0/' "${LAB_DIR}/html/index.html"

comment "Build v1.1.0"
run "podman build --platform linux/amd64 -t ${REGISTRY}/${APP_NAME}:1.1.0 ${LAB_DIR}"

comment "Push both versions"
run "podman push ${REGISTRY}/${APP_NAME}:1.0.0"
run "podman push ${REGISTRY}/${APP_NAME}:1.1.0"

# ── 2 · Create Deployment, Service, Route ──────────────────────────────────
banner "2 · Create Deployment, Service, and Route"

comment "Create a Deployment with one replica"
run "oc create deployment ${APP_NAME} --image=${REGISTRY}/${APP_NAME}:1.0.0 --port=8080"

comment "Force pull policy to Always (avoid stale node cache)"
run "oc patch deployment ${APP_NAME} -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"${APP_NAME}\",\"imagePullPolicy\":\"Always\"}]}}}}'"

comment "Wait for the pod to be ready"
run "oc rollout status deployment/${APP_NAME} --timeout=60s"

comment "Expose the Deployment as a Service (ClusterIP)"
run "oc expose deployment ${APP_NAME} --port=8080"

comment "Create an edge-terminated Route (TLS)"
run "oc create route edge ${APP_NAME} --service=${APP_NAME}"

comment "Get the Route URL"
run "oc get route ${APP_NAME} -o jsonpath='{.spec.host}'"

ROUTE_URL=$(oc get route "${APP_NAME}" -o jsonpath='{.spec.host}' 2>/dev/null)
printf "\n\n"
printf "%s   Route URL: %shttps://%s%s\n" "${DIM}" "${GREEN}" "${ROUTE_URL}" "${RESET}"

discuss \
  "What did we just create?" \
  "" \
  "  Deployment  - manages ReplicaSets and Pods" \
  "  Service     - stable ClusterIP + DNS name" \
  "  Route       - external HTTPS endpoint" \
  "" \
  "The Route terminates TLS at the router" \
  "and forwards plain HTTP to port 8080."

printf "\n"
printf "%s>> Open the Route URL in your browser now.%s\n" "${BOLD}" "${RESET}"
printf "%s>> Also check the Topology view in the web console.%s\n" "${BOLD}" "${RESET}"
pause

# ── 3 · Scale to 3 replicas ───────────────────────────────────────────────
banner "3 · Scale to 3 replicas"

comment "Scale the Deployment to 3 replicas"
run "oc scale deployment/${APP_NAME} --replicas=3"

comment "Watch the pods come up"
run "oc get pods -l app=${APP_NAME}"

discuss \
  "3 pods behind one Service" \
  "" \
  "The Service load-balances across all pods." \
  "Each pod gets a unique name but shares the" \
  "same image, config, and network identity." \
  "" \
  "What happens if we delete one?"

# ── 4 · Self-healing: delete a pod ────────────────────────────────────────
banner "4 · Self-healing: delete a pod"

comment "Pick one of the pods"
POD_TO_DELETE=$(oc get pods -l app="${APP_NAME}" -o jsonpath='{.items[0].metadata.name}')
printf "%s   Deleting pod: %s%s%s\n" "${DIM}" "${RED}" "${POD_TO_DELETE}" "${RESET}"

comment "Delete it and watch -- the Deployment creates a replacement"
run "oc delete pod ${POD_TO_DELETE} && oc get pods -l app=${APP_NAME} -w &"

comment "Wait a moment then press Ctrl+C or just continue"
pause

run "oc get pods -l app=${APP_NAME}"

discuss \
  "Self-healing" \
  "" \
  "The Deployment controller noticed the pod" \
  "count dropped below the desired 3 replicas" \
  "and immediately created a replacement." \
  "" \
  "This is the declarative model:" \
  "you declare the desired state, Kubernetes" \
  "makes it happen."

# ── 5 · Rolling update to v1.1.0 ──────────────────────────────────────────
banner "5 · Rolling update to v1.1.0"

comment "Update the image to v1.1.0"
run "oc set image deployment/${APP_NAME} ${APP_NAME}=${REGISTRY}/${APP_NAME}:1.1.0"

comment "Watch the rollout"
run "oc rollout status deployment/${APP_NAME} --timeout=120s"

comment "Verify the pods are running the new version"
run "oc get pods -l app=${APP_NAME}"

printf "\n"
printf "%s>> Refresh the browser -- you should see v1.1.0%s\n" "${BOLD}" "${RESET}"
pause

# ── 6 · Rollback ──────────────────────────────────────────────────────────
banner "6 · Rollback to v1.0.0"

comment "Undo the last rollout"
run "oc rollout undo deployment/${APP_NAME}"

comment "Watch the rollback"
run "oc rollout status deployment/${APP_NAME} --timeout=120s"

run "oc get pods -l app=${APP_NAME}"

printf "\n"
printf "%s>> Refresh the browser -- back to v1.0.0%s\n" "${BOLD}" "${RESET}"
pause

discuss \
  "Rolling updates and rollbacks" \
  "" \
  "Kubernetes creates a NEW ReplicaSet and" \
  "gradually shifts pods from old to new." \
  "Zero-downtime by default." \
  "" \
  "oc rollout undo reverts to the previous" \
  "ReplicaSet -- the old pods come back."

# ── 7 · Bonus: export as YAML ─────────────────────────────────────────────
banner "Bonus · Export objects as YAML"

comment "Export the Deployment YAML"
run "oc get deployment ${APP_NAME} -o yaml"

discuss \
  "Which fields belong in Git?" \
  "" \
  "KEEP:" \
  "  - spec.template (image, ports, env)" \
  "  - spec.replicas" \
  "  - metadata.labels" \
  "" \
  "REMOVE (managed by the cluster):" \
  "  - metadata.uid, resourceVersion," \
  "    creationTimestamp, generation" \
  "  - status (entire block)" \
  "  - metadata.managedFields"

# ── Done ───────────────────────────────────────────────────────────────────
banner "Lab complete!"
printf "\n"
printf "%sKey takeaways:%s\n" "${GREEN}" "${RESET}"
printf "  • oc create deployment + expose + route = app on the internet\n"
printf "  • Deployments maintain the desired replica count (self-healing)\n"
printf "  • oc set image triggers a zero-downtime rolling update\n"
printf "  • oc rollout undo reverts to the previous version\n"
printf "  • Export YAML, clean it up, and store in Git for GitOps\n"
printf "\n"
