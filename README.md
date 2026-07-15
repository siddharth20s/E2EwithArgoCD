# Demo E2E: .NET + React + Postgres + Jenkins + Argo CD + kind

This repository is configured for a local, zero-cost GitOps flow.

## What Is Included

- backend/Backend.Api: ASP.NET Core Web API
- frontend: React app
- helm/demo-e2e: Helm chart for backend, frontend, and postgres
- helm/demo-e2e/values-kind.yaml: local kind deployment values
- Jenkinsfile: Jenkins pipeline
- scripts/deploy-kind-argocd.sh: deploy helper used by Jenkins (Linux shell)

## Flow

1. You push to main.
2. Jenkins webhook triggers a pipeline run.
3. Jenkins builds backend and frontend, validates Helm.
4. Jenkins creates an image tag from commit and build number.
5. Jenkins runs scripts/deploy-kind-argocd.sh with that tag.
6. Script updates helm/demo-e2e/values-kind.yaml, builds images, loads images into kind, and ensures Argo CD app exists.
7. Jenkins commits the values file change to main.
8. Argo CD detects the Git change and syncs to kind.

## One-Time Setup

1. Install required tools on the Jenkins agent:

   - dotnet SDK 8
   - node and npm
   - docker
   - kind
   - kubectl
   - helm
   - git
   - bash

2. Create the local kind cluster:

   ```powershell
   kind create cluster --name kind
   ```

3. Create a Jenkins Pipeline job pointed at this repository.

4. In Jenkinsfile, set REPO_URL to your real repository URL.

5. Ensure Jenkins has permission to push to main.

6. Configure a Git webhook to Jenkins so push events trigger builds.

## Custom Jenkins Container (Recommended)

This repo includes a Jenkins image with required tools preinstalled:

- dotnet 8 SDK
- node and npm
- docker CLI
- kind
- kubectl
- helm
- git

Files:

- docker/jenkins/Dockerfile
- docker/jenkins/plugins.txt
- docker-compose.jenkins.yml

Start Jenkins:

```powershell
docker compose -f docker-compose.jenkins.yml up -d --build
```

Open Jenkins UI:

- http://localhost:8082

If setup wizard appears, get initial admin password:

```powershell
docker exec jenkins-local cat /var/jenkins_home/secrets/initialAdminPassword
```

Check tools inside container:

```powershell
docker exec jenkins-local sh -lc "dotnet --version && node --version && npm --version && kubectl version --client && helm version && kind --version && docker --version"
```

Stop Jenkins:

```powershell
docker compose -f docker-compose.jenkins.yml down
```

## Run It Yourself

1. Push code to main.
2. Open Jenkins and watch the pipeline run.
3. Verify deployment:

   ```powershell
   kubectl get applications -n argocd
   kubectl get pods -n demo
   ```

## Optional Local App Run (without Kubernetes)

```powershell
docker compose up --build
```

- Frontend: http://localhost:3003
- Backend: http://localhost:8080/api/todos
