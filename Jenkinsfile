pipeline {
  agent any

  environment {
    REPO_URL = 'https://github.com/REPLACE_WITH_YOUR_REPO.git'
  }

  options {
    timestamps()
  }

  stages {
    stage('Validate Pipeline Config') {
      steps {
        powershell '''
          if ($env:REPO_URL -eq 'https://github.com/REPLACE_WITH_YOUR_REPO.git') {
            throw 'Set REPO_URL in Jenkinsfile to your real repository URL before running deploy.'
          }
        '''
      }
    }

    stage('Backend Build') {
      steps {
        powershell 'dotnet restore backend/Backend.Api/Backend.Api.csproj'
        powershell 'dotnet build backend/Backend.Api/Backend.Api.csproj -c Release --no-restore'
      }
    }

    stage('Frontend Build') {
      steps {
        dir('frontend') {
          powershell 'npm ci'
          powershell 'npm run build'
        }
      }
    }

    stage('Helm Validate') {
      steps {
        powershell 'helm lint helm/demo-e2e'
        powershell 'helm template demo-stack helm/demo-e2e -f helm/demo-e2e/values-kind.yaml > $null'
      }
    }

    stage('Deploy to kind with Argo CD') {
      when {
        branch 'main'
      }
      steps {
        powershell '''
          $shortSha = (git rev-parse --short HEAD).Trim()
          $imageTag = "$shortSha-$env:BUILD_NUMBER"

          .\\scripts\\deploy-kind-argocd.ps1 -ImageTag $imageTag -RepoUrl $env:REPO_URL

          git config user.email "jenkins@local"
          git config user.name "jenkins"

          git add helm/demo-e2e/values-kind.yaml
          git diff --cached --quiet
          if ($LASTEXITCODE -ne 0) {
            git commit -m "gitops: promote local kind images to $imageTag"
            git push origin HEAD:main
          } else {
            Write-Host "No GitOps values change detected; skipping commit."
          }
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'frontend/dist/**', allowEmptyArchive: true
    }
  }
}
