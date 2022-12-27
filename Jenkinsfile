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
    office365ConnectorWebhooks([[
      name: 'Teams-JK-Alerts',
      startNotification: true,
      url: 'https://unaledu.webhook.office.com/webhookb2/ceab6fb2-ca5b-4d5d-9885-b7bcc5299c0e@577fc1d8-0922-458e-87bf-ec4f455eb600/IncomingWebhook/7cc7c93a924e499e92024375cff65836/95e094a2-b2d3-4dff-a40c-47b9fe3f5404'
    ]])
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
  post {
        success {
            office365ConnectorSend webhookUrl: "https://unaledu.webhook.office.com/webhookb2/ceab6fb2-ca5b-4d5d-9885-b7bcc5299c0e@577fc1d8-0922-458e-87bf-ec4f455eb600/IncomingWebhook/7cc7c93a924e499e92024375cff65836/95e094a2-b2d3-4dff-a40c-47b9fe3f5404",
                factDefinitions: [[name: "Branch", template: "${BRANCH_NAME}"],
                                  [name: "Job", template: "${JOB_NAME}"]]
        }
        aborted {
            office365ConnectorSend webhookUrl: "https://unaledu.webhook.office.com/webhookb2/ceab6fb2-ca5b-4d5d-9885-b7bcc5299c0e@577fc1d8-0922-458e-87bf-ec4f455eb600/IncomingWebhook/6ad2005726044cb7879331c7537f6804/95e094a2-b2d3-4dff-a40c-47b9fe3f5404",
                factDefinitions: [[name: "Branch", template: "${BRANCH_NAME}"],
                                  [name: "Job", template: "${JOB_NAME}"]]
        }
        failure {
            office365ConnectorSend webhookUrl: "https://unaledu.webhook.office.com/webhookb2/ceab6fb2-ca5b-4d5d-9885-b7bcc5299c0e@577fc1d8-0922-458e-87bf-ec4f455eb600/IncomingWebhook/e26dfa085e4c48d7b68a5f81011e63e9/95e094a2-b2d3-4dff-a40c-47b9fe3f5404",
                factDefinitions: [[name: "Branch", template: "${BRANCH_NAME}"],
                                  [name: "Job", template: "${JOB_NAME}"]]
        }
    }
}