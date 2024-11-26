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
                bat 'make build' // Cambiado a bat para entornos Windows
            }
        }
        stage('Unit tests') {
            steps {
                echo 'Running unit tests...'
                bat 'make test-unit' // Cambiado a bat para entornos Windows
                archiveArtifacts artifacts: 'results/*.xml' // Archiva los resultados de las pruebas unitarias
            }
        }
        stage('API tests') {
            steps {
                echo 'Running API tests...'
                bat 'make test-api' // Comando para ejecutar pruebas de API
                archiveArtifacts artifacts: 'results/api/*.xml' // Archiva los resultados de las pruebas API
            }
        }
        stage('E2E tests') {
            steps {
                echo 'Running E2E tests...'
                bat 'make test-e2e' // Comando para ejecutar pruebas E2E
                archiveArtifacts artifacts: 'results/e2e/*.xml' // Archiva los resultados de las pruebas E2E
            }
        }
    }
    post {
        always {
            echo 'Archiving test results and cleaning workspace...'
            junit 'results/**/*_result.xml' // Publica los resultados como informes de JUnit
            cleanWs() // Limpia el workspace al final
        }
        failure {
            echo 'Pipeline failed. Simulating email notification...'
            script {
                def jobName = env.JOB_NAME ?: 'Unknown Job'
                def buildNumber = env.BUILD_NUMBER ?: 'Unknown Build'
                echo "Sending email: Pipeline failed - Job: ${jobName}, Build: #${buildNumber}"
                // Puedes agregar el bloque mail descomentando esto:
                // mail to: 'team@example.com',
                //      subject: "Pipeline failed: ${jobName} #${buildNumber}",
                //      body: "The pipeline ${jobName} failed during execution. Build number: ${buildNumber}."
            }
        }
    }
}
