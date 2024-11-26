pipeline {
    agent {
        label 'docker'
    }
    stages {
        stage('Source') {
            steps {
                echo 'Cloning repository...'
                git 'https://github.com/srayuso/unir-cicd.git'
            }
        }
        stage('Build') {
            steps {
                echo 'Building the project...'
                bat 'make build'
            }
        }
        stage('Unit tests') {
            steps {
                echo 'Running unit tests...'
                bat 'make test-unit'
                archiveArtifacts artifacts: 'results/*.xml'
            }
        }
        stage('API tests') {
            steps {
                echo 'Running API tests...'
                bat 'make test-api'
                bat 'dir /s' // Lista los archivos en el workspace para depurar rutas
                script {
                    if (!fileExists('results/api/api_result.xml')) {
                        error "API test results not found! Ensure the file is copied correctly."
                    }
                }
                archiveArtifacts artifacts: 'results/api/*.xml'
            }
        }
        stage('E2E tests') {
            steps {
                echo 'Running E2E tests...'
                bat 'make test-e2e'
                archiveArtifacts artifacts: 'results/e2e/*.xml'
            }
        }
    }
    post {
        always {
            echo 'Archiving test results and cleaning workspace...'
            junit 'results/**/*.xml'
            cleanWs()
        }
        failure {
            echo 'Pipeline failed. Simulating email notification...'
            script {
                def jobName = env.JOB_NAME ?: 'Unknown Job'
                def buildNumber = env.BUILD_NUMBER ?: 'Unknown Build'
                echo "Sending email: Pipeline failed - Job: ${jobName}, Build: #${buildNumber}"
            }
        }
    }
}
