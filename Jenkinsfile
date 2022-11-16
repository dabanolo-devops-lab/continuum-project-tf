pipeline {
  agent {
    node {
      label 'Terraform'
    }

  }
  stages {
    stage('Checkout code') {
      steps {
        git(url: 'https://github.com/dabanolo-devops-lab/continuum-project', branch: 'terraform')
      }
    }
    stage('init') {
      steps {
        sh 'terraform init'
      }
    }
    stage('plan') {
      steps {
        sh 'terraform plan'
      }
    }
    stage('apply') {
      steps {
        sh 'terraform apply --auto-approve'
      }
    }
  }
  environment {
    docker_tag = 'continuum-app'
  }
}