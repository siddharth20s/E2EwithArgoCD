param(
  [Parameter(Mandatory = $true)]
  [string]$ImageTag,

  [Parameter(Mandatory = $false)]
  [string]$RepoUrl = "https://github.com/REPLACE_WITH_YOUR_REPO.git",

  [Parameter(Mandatory = $false)]
  [string]$ValuesFile = "helm/demo-e2e/values-kind.yaml"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ValuesFile)) {
  throw "Values file not found: $ValuesFile"
}

Write-Host "Using image tag: $ImageTag"

Write-Host "Updating Helm values file with new tag..."
$content = Get-Content -Path $ValuesFile -Raw

# Replace frontend image tag only inside frontend image block.
$content = $content -replace '(?s)(frontend:\s*\r?\n\s*replicaCount:\s*\d+\s*\r?\n\s*image:\s*\r?\n\s*repository:\s*[^\r\n]+\s*\r?\n\s*tag:\s*)[^\r\n]+', "`${1}$ImageTag"

# Replace backend image tag only inside backend image block.
$content = $content -replace '(?s)(backend:\s*\r?\n\s*replicaCount:\s*\d+\s*\r?\n\s*image:\s*\r?\n\s*repository:\s*[^\r\n]+\s*\r?\n\s*tag:\s*)[^\r\n]+', "`${1}$ImageTag"

Set-Content -Path $ValuesFile -Value $content -NoNewline

Write-Host "Building backend image..."
docker build -t "demo-backend:$ImageTag" ./backend

Write-Host "Building frontend image..."
docker build -t "demo-frontend:$ImageTag" ./frontend

Write-Host "Loading images into kind cluster 'kind'..."
kind load docker-image "demo-backend:$ImageTag" --name kind
kind load docker-image "demo-frontend:$ImageTag" --name kind

Write-Host "Ensuring Argo CD namespace exists..."
kubectl get namespace argocd 2>$null
if ($LASTEXITCODE -ne 0) {
  kubectl create namespace argocd
}

Write-Host "Installing or updating Argo CD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

Write-Host "Applying Argo CD app for local kind..."

@"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-e2e-kind
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $RepoUrl
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
"@ | kubectl apply -f -

Write-Host "Waiting for app rollout..."
kubectl rollout status deployment/backend -n demo --timeout=300s
kubectl rollout status deployment/frontend -n demo --timeout=300s

Write-Host "Done. Current pods:"
kubectl get pods -n demo
