#!/usr/bin/env bash
set -euo pipefail

NUM_USERS="${1:-25}"
HTPASSWD_FILE="htpasswd"
NS_MANIFEST="student-namespaces.yaml"

if ! [[ "$NUM_USERS" =~ ^[0-9]+$ ]] || [ "$NUM_USERS" -lt 1 ]; then
  echo "Usage: $0 [number_of_students]"
  echo "  Default: 25"
  exit 1
fi

generate_password() {
  LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12 || true
}

> "$HTPASSWD_FILE"
> "$NS_MANIFEST"

echo "=========================================="
echo " Student Credentials"
echo "=========================================="
printf "%-14s %s\n" "USERNAME" "PASSWORD"
echo "------------------------------------------"

for i in $(seq -w 1 "$NUM_USERS"); do
  user="labuser${i}"
  namespace="ocp-lab${i}"
  password=$(generate_password)

  printf "%-14s %s\n" "$user" "$password"

  hash=$(htpasswd -nbB "$user" "$password" 2>/dev/null)
  echo "$hash" >> "$HTPASSWD_FILE"

  cat >> "$NS_MANIFEST" <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
  labels:
    training: "true"
    student: "${user}"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${user}-admin
  namespace: ${namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: ${user}
EOF
done

echo "=========================================="
echo ""
echo "Files generated:"
echo "  - ${HTPASSWD_FILE}  (upload to cluster)"
echo "  - ${NS_MANIFEST}    (oc apply -f ${NS_MANIFEST})"
echo ""
echo "To apply namespaces and rolebindings:"
echo "  oc apply -f ${NS_MANIFEST}"
echo ""
echo "To update htpasswd on the cluster:"
echo "  oc create secret generic htpass-secret --from-file=htpasswd=${HTPASSWD_FILE} -n openshift-config --dry-run=client -o yaml | oc apply -f -"
