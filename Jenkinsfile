pipeline {
  agent {
    node {
      label 'terraform'
    }

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
        sh 'terraform init'
      }
    }
    stage('validate') {
      steps {
        sh 'terraform validate'
      }
    }
    stage('plan') {
      steps {
        sh 'terraform plan'
      }
    }
    // stage('apply') {
    //   steps {
    //     sh 'terraform apply --auto-approve'
    //   }
    // }
  }
  environment {
    docker_tag = 'continuum-app'
  }
}