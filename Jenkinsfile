pipeline {
  agent any

  environment {
    REPO_URL = 'https://github.com/siddharth20s/E2EwithArgoCD.git'
  }

  stages {
    stage('Validate Pipeline Config') {
      steps {
        sh '''
          set -e
          if [ "$REPO_URL" = "https://github.com/REPLACE_WITH_YOUR_REPO.git" ]; then
            echo "Set REPO_URL in Jenkinsfile to your real repository URL before running deploy."
            exit 1
          fi
        '''
      }
    }

    stage('Backend Build') {
      steps {
        sh 'dotnet restore backend/Backend.Api/Backend.Api.csproj'
        sh 'dotnet build backend/Backend.Api/Backend.Api.csproj -c Release --no-restore'
      }
    }

    stage('Frontend Build') {
      steps {
        dir('frontend') {
          sh 'npm ci'
          sh 'npm run build'
        }
      }
    }

    stage('Helm Validate') {
      steps {
        sh 'helm lint helm/demo-e2e'
        sh 'helm template demo-stack helm/demo-e2e -f helm/demo-e2e/values-kind.yaml >/dev/null'
      }
    }

    stage('Deploy to kind with Argo CD') {
      when {
        expression {
          return env.BRANCH_NAME == null || env.BRANCH_NAME == 'main'
        }
      }
      steps {
        sh '''
          set -e
          SHORT_SHA=$(git rev-parse --short HEAD)
          IMAGE_TAG="${SHORT_SHA}-${BUILD_NUMBER}"

          bash ./scripts/deploy-kind-argocd.sh "$IMAGE_TAG" "$REPO_URL"
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
