pipeline {
  agent {
    node {
      label 'terraform'
    }
  }
  options {
    ansiColor('xterm')
  }
  stages {
    stage('Checkout code') {
      steps {
        sh 'echo "${BRANCH_NAME}"'
        // git branch: 'main', credentialsId: 'jenkins-dabanolo-continuum', url: 'https://github.com/dabanolo-devops-lab/continuum-project'
      }
    }
    stage('init') {
      steps {
        sh 'terraform -chdir=prod/ init'
      }
    }
    stage('validate') {
      steps {
        sh 'terraform -chdir=prod/ validate'
      }
    }
    stage('plan') {
      steps {
        sh 'terraform -chdir=prod/ plan'
      }
    }
    stage('apply') {
      steps {
        // sh 'terraform apply --auto-approve'
        sh 'echo "SUCCESS"'
      }
    }
  }
  environment {
    docker_tag = 'continuum-app'
  }
}