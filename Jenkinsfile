pipeline {
  agent {
    node {
      label 'terraform'
    }
  }
  environment{
    BUILD_VERSION = sh(script: """
    #!/bin/bash -el
    tail -n 1 /home/ubuntu/jenkins/build_version
    """, returnStdout: true).trim()
    docker_tag = 'continuum-app'
  }
  options {
    ansiColor('xterm')
  }
  stages {
    stage('Checkout code') {
      steps {
        sh 'echo "${BRANCH_NAME}"'
        sh 'echo "${BUILD_VERSION}"'
        // git branch: 'main', credentialsId: 'jenkins-dabanolo-continuum', url: 'https://github.com/dabanolo-devops-lab/continuum-project'
      }
    }
    stage('init') {
      steps {
        withAWS(region:'us-east-1',credentials:'aws_dabanolo'){
          sh """#!/bin/bash -el
          terraform -chdir=prod/ init
          """
        }
      }
    }
    stage('validate') {
      steps {
        sh """#!/bin/bash -el
        terraform -chdir=prod/ validate
        """
      }
    }
    stage('plan') {
      
      steps {
        sh 'echo "${BUILD_VERSION}"'
        withAWS(region:'us-east-1',credentials:'aws_dabanolo'){
          sh """#!/bin/bash -el
          terraform -chdir=prod/ plan -var "app_version=${BUILD_VERSION}"
          """
        }
      }
    }
    stage('apply') {
      when {
        branch 'main'
      }
      steps {
        withAWS(region:'us-east-1',credentials:'aws_dabanolo'){
          script {
            def APPLY_CHOICE=input  message: 'Do you want to apply the changes into the infrasctructure?', 
                                    ok: 'Submit', 
                                    parameters: [choice(choices: ['apply', 'discard'], name: 'terraform_choice')]
            if ("${APPLY_CHOICE}" == "apply") {
                echo "APPLYING"
                sh """#!/bin/bash -el
                terraform -chdir=prod/ apply --auto-approve -var "app_version=${BUILD_VERSION}"
                """
            } else {
                echo "NOT APPLYING"
            }
          }
        }
        sh 'echo "SUCCESS"'
        sh 'echo "${BUILD_VERSION}"'
      }
    }
  }
}