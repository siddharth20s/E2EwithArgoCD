#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image-tag> [repo-url] [values-file]"
  exit 1
fi

IMAGE_TAG="$1"
REPO_URL="${2:-https://github.com/REPLACE_WITH_YOUR_REPO.git}"
VALUES_FILE="${3:-helm/demo-e2e/values-kind.yaml}"

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "Values file not found: $VALUES_FILE"
  exit 1
fi

echo "Using image tag: $IMAGE_TAG"
echo "Updating Helm values file with new tag..."

awk -v tag="$IMAGE_TAG" '
  BEGIN { section=""; in_image=0 }
  /^frontend:[[:space:]]*$/ { section="frontend"; in_image=0; print; next }
  /^backend:[[:space:]]*$/  { section="backend";  in_image=0; print; next }
  /^[^[:space:]].*:[[:space:]]*$/ {
    if ($0 !~ /^frontend:[[:space:]]*$/ && $0 !~ /^backend:[[:space:]]*$/) {
      section=""
      in_image=0
    }
    print
    next
  }
  /^[[:space:]]+image:[[:space:]]*$/ { in_image=1; print; next }
  {
    if (in_image == 1 && section != "" && $0 ~ /^[[:space:]]+tag:[[:space:]]*/) {
      sub(/tag:[[:space:]]*.*/, "tag: " tag)
      in_image=0
      print
      next
    }
    print
  }
' "$VALUES_FILE" > "$VALUES_FILE.tmp"
mv "$VALUES_FILE.tmp" "$VALUES_FILE"

echo "Building backend image..."
docker build -t "demo-backend:$IMAGE_TAG" ./backend

echo "Building frontend image..."
docker build -t "demo-frontend:$IMAGE_TAG" ./frontend

load_image_into_kind() {
  local image="$1"

  if kind load docker-image "$image" --name kind; then
    return 0
  fi

  echo "kind load failed for $image, falling back to direct containerd import..."
  local archive
  archive="$(mktemp "${TMPDIR:-/tmp}/kind-image-XXXXXX.tar")"
  docker save "$image" -o "$archive"

  while IFS= read -r node; do
    echo "Importing $image into node $node"
    docker exec -i "$node" ctr -n k8s.io images import - < "$archive"
  done < <(kind get nodes --name kind)

  rm -f "$archive"
}

echo "Loading images into kind cluster 'kind'..."
load_image_into_kind "demo-backend:$IMAGE_TAG"
load_image_into_kind "demo-frontend:$IMAGE_TAG"

configure_kind_kubeconfig() {
  local kubeconfig_tmp
  kubeconfig_tmp="$(mktemp "${TMPDIR:-/tmp}/kind-kubeconfig-XXXXXX")"

  # Ensure Jenkins container can reach kind-control-plane on the kind network.
  docker network connect kind "$HOSTNAME" >/dev/null 2>&1 || true

  # Use internal endpoint (kind-control-plane:6443) so TLS SANs match.
  kind get kubeconfig --name kind --internal > "$kubeconfig_tmp"

  export KUBECONFIG="$kubeconfig_tmp"
  echo "Configured KUBECONFIG for kind: $KUBECONFIG"
}

echo "Configuring kube access for kind..."
configure_kind_kubeconfig
kubectl cluster-info

echo "Ensuring Argo CD namespace exists..."
kubectl get namespace argocd >/dev/null 2>&1 || kubectl create namespace argocd

echo "Installing or updating Argo CD..."
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "Applying Argo CD app for local kind..."
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-e2e-kind
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: main
    path: helm/demo-e2e
    helm:
      valueFiles:
        - values-kind.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo "Waiting for app rollout..."
kubectl rollout status deployment/backend -n demo --timeout=300s
kubectl rollout status deployment/frontend -n demo --timeout=300s

echo "Done. Current pods:"
kubectl get pods -n demo
