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
                archiveArtifacts artifacts: 'results/unit_result.xml'
            }
        }
        stage('API tests') {
            steps {
                echo 'Running API tests...'
                bat 'make test-api'
                // Validar que el archivo de resultados existe en la ubicación correcta
                script {
                    if (!fileExists('results/api_result.xml')) {
                        error "API test results not found! Ensure the file is copied correctly."
                    }
                }
                // Archivar el archivo de resultados API
                archiveArtifacts artifacts: 'results/api_result.xml'
            }
        }
        stage('E2E tests') {
            steps {
                echo 'Running E2E tests...'
                bat 'make test-e2e'
                // Archivar los resultados de las pruebas E2E
                archiveArtifacts artifacts: 'results/e2e/*.xml'
            }
        }
    }
    post {
        always {
            echo 'Archiving test results and cleaning workspace...'
            junit 'results/**/*.xml' // Publica todos los resultados de pruebas
            cleanWs() // Limpia el workspace al finalizar
        }
        failure {
            echo 'Pipeline failed. Simulating email notification...'
            script {
                def jobName = env.JOB_NAME ?: 'Unknown Job'
                def buildNumber = env.BUILD_NUMBER ?: 'Unknown Build'
                echo "Sending email: Pipeline failed - Job: ${jobName}, Build: #${buildNumber}"
                // Puedes descomentar el siguiente bloque para enviar correos reales
                // mail to: 'team@example.com',
                //      subject: "Pipeline failed: ${jobName} #${buildNumber}",
                //      body: "The pipeline ${jobName} failed during execution. Build number: ${buildNumber}."
            }
        }
    }
}
