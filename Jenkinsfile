pipeline {
    agent any

    options {
        timestamps()
    }

    parameters {
        string(name: 'IMAGE_TAG', defaultValue: '1.0.2', description: 'Docker image tag to build and push')
        booleanParam(name: 'PUSH_LATEST', defaultValue: false, description: 'Also push the latest tag')
    }

    environment {
        IMAGE_REPOSITORY = 'nsniteshsonal37/simpletimeservice'
        APP_DIRECTORY = 'app'
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                script {
                    docker.build("${env.IMAGE_REPOSITORY}:${params.IMAGE_TAG}", env.APP_DIRECTORY)
                }
            }
        }

        stage('Push Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKER_CREDENTIALS_ID, usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD')]) {
                    script {
                        sh '''
echo "$DOCKERHUB_PASSWORD" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin
docker push "$IMAGE_REPOSITORY:$IMAGE_TAG"
'''

                        if (params.PUSH_LATEST) {
                            sh '''
docker tag "$IMAGE_REPOSITORY:$IMAGE_TAG" "$IMAGE_REPOSITORY:latest"
docker push "$IMAGE_REPOSITORY:latest"
'''
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
    }
}