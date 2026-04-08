pipeline {
    agent any

    options {
        timestamps()
    }

    parameters {
        string(name: 'STS_IMAGE_TAG', defaultValue: '1.0.2', description: 'Docker image tag to build and push')
        booleanParam(name: 'STS_PUSH_LATEST', defaultValue: false, description: 'Also push the latest tag')
        booleanParam(name: 'STS_DEPLOY_TO_EKS', defaultValue: false, description: 'Deploy the pushed image tag to EKS')
        string(name: 'STS_AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region for EKS deployment')
        string(name: 'STS_EKS_CLUSTER_NAME', defaultValue: 'simpletimeservice-prod-eks', description: 'EKS cluster name for deployment')
    }

    environment {
        STS_IMAGE_REPOSITORY = 'nsniteshsonal37/simpletimeservice'
        STS_APP_DIRECTORY = 'app'
        STS_DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t "$STS_IMAGE_REPOSITORY:$STS_IMAGE_TAG" "$STS_APP_DIRECTORY"'
            }
        }

        stage('Push Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.STS_DOCKER_CREDENTIALS_ID, usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD')]) {
                    script {
                        sh '''
echo "$DOCKERHUB_PASSWORD" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin
docker push "$STS_IMAGE_REPOSITORY:$STS_IMAGE_TAG"
'''

                        if (params.STS_PUSH_LATEST) {
                            sh '''
docker tag "$STS_IMAGE_REPOSITORY:$STS_IMAGE_TAG" "$STS_IMAGE_REPOSITORY:latest"
docker push "$STS_IMAGE_REPOSITORY:latest"
'''
                        }
                    }
                }
            }
        }

        stage('Deploy to EKS') {
            when {
                expression { params.STS_DEPLOY_TO_EKS }
            }
            steps {
                sh '''
aws eks update-kubeconfig --region "$STS_AWS_REGION" --name "$STS_EKS_CLUSTER_NAME"

if kubectl get deployment/simpletimeservice >/dev/null 2>&1; then
    kubectl set image deployment/simpletimeservice simpletimeservice="$STS_IMAGE_REPOSITORY:$STS_IMAGE_TAG"
else
    kubectl apply -f k8s/microservice.yml
fi

kubectl rollout status deployment/simpletimeservice --timeout=180s
kubectl get pods -l app=simpletimeservice
'''
        }
    }
    }

    post {
        always {
            sh 'docker logout || true'
        }
    }
}