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
      environment{
        BUILD_VERSION = sh(script: "tail -n 1 /home/ubuntu/jenkins/build_version", returnStdout: true).trim()
      }
      steps {
        sh 'echo "${BUILD_VERSION}"'
        sh 'terraform -chdir=prod/ plan -var "app_version=${BUILD_VERSION}"'
      }
    }
    stage('apply') {
      when {
        branch 'main'
      }
      environment{
        BUILD_VERSION = sh(script: "tail -n 1 /home/ubuntu/jenkins/build_version", returnStdout: true).trim()
      }
      steps {
        // sh 'terraform apply --auto-approve'
        // sh 'terraform -chdir=prod/ apply --auto-approve -var "app_version=${BUILD_VERSION}"'
        sh 'echo "SUCCESS"'
        sh 'echo "${BUILD_VERSION}"'
      }
    }
  }
  environment {
    docker_tag = 'continuum-app'
  }
}