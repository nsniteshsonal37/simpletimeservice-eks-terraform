# SimpleTimeService - DevOps Challenge Submission

This repository contains a minimal web service and infrastructure code for the Particle41 DevOps assessment.

## Repository Structure

```text
.
├── app/        # FastAPI service, Dockerfile, and local docker compose files
├── k8s/        # Kubernetes manifest (Deployment + Service)
└── terraform/  # Terraform code for VPC + EKS
```

## Prerequisites

Install the following tools:

- Python 3.12+ (https://www.python.org/downloads/)
- Docker and Docker Compose (https://docs.docker.com/get-docker/)
- kubectl (https://kubernetes.io/docs/tasks/tools/)
- Terraform >= 1.6 (https://developer.hashicorp.com/terraform/install)
- AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## AWS Authentication

Do not commit credentials. Configure AWS credentials locally before running Terraform.

Example:

```sh
aws configure
```

Or use environment variables:

```sh
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

## Task 1 - Application, Docker, and Kubernetes

### 1. Run service locally (optional)

```sh
cd app
pip install -r requirements.txt
uvicorn main:app --reload --no-access-log
```

Test endpoint:

```sh
curl http://localhost:8000/
```

Expected JSON shape:

```json
{
  "timestamp": "2026-04-07T17:51:42.923090+00:00",
  "ip": "203.0.113.10"
}
```

### 2. Build and publish container image to DockerHub

From repository root:

```sh
docker login
docker build -t nsniteshsonal37/simpletimeservice:1.0.2 ./app
docker push nsniteshsonal37/simpletimeservice:1.0.2
```

Optional Jenkins pipeline:

- A root `Jenkinsfile` is included to build from `app/` and push to DockerHub.
- The pipeline is written for a Linux Jenkins agent with Docker installed.
- Store DockerHub credentials in Jenkins Credentials, not in the repository.
- Configure a Jenkins `Username with password` credential with ID `dockerhub-credentials`.
- The `Jenkinsfile` reads that credential via `withCredentials(...)` and passes it to `docker login --password-stdin`.
- Default pipeline tag is `1.0.2`; override it with the `IMAGE_TAG` parameter.
- Set `PUSH_LATEST=true` if you also want to publish the `latest` tag.

### 3. Deploy to Kubernetes

```sh
kubectl apply -f k8s/microservice.yml
```

Verify:

```sh
kubectl get pods
kubectl get svc
```

The application Service `simpletimeservice` is internal (`ClusterIP`).
External access is provided through `simpletimeservice-nginx` (`NodePort`) so
the setup still avoids `LoadBalancer`.

## Task 2 - Terraform (VPC + EKS)

The Terraform code creates:

- 1 VPC
- 2 public subnets
- 2 private subnets
- 1 EKS cluster
- 1 managed node group with profile-driven defaults (`dev` or `prod`)
- EKS worker nodes on private subnets only

Profile switching:

- Default profile is `deployment_profile = "prod"` so `terraform plan` and `terraform apply` produce the assessment-sized infrastructure by default.
- Switch to lower-cost development defaults with:
  - `deployment_profile = "dev"` in `terraform/terraform.tfvars`, or
  - `terraform apply -var="deployment_profile=dev"`

Profile switch scripts:

- PowerShell:

```powershell
./scripts/switch-profile.ps1
```

- Bash:

```bash
./scripts/switch-profile.sh
```

Both scripts write `terraform/profile.auto.tfvars`, which Terraform loads automatically.

One-click deploy scripts (Terraform + kubeconfig + Kubernetes apply):

- PowerShell:

```powershell
./scripts/deploy.ps1 -Profile prod
```

- Bash:

```bash
./scripts/deploy.sh --profile prod
```

By default these scripts run `terraform apply -auto-approve`.
Use `-NoAutoApprove` (PowerShell) or `--no-auto-approve` (Bash) to require manual confirmation.

One-click destroy scripts (Kubernetes delete + Terraform destroy):

- PowerShell:

```powershell
./scripts/destroy.ps1
```

- Bash:

```bash
./scripts/destroy.sh
```

By default these scripts run `terraform destroy -auto-approve`.
Use `-NoAutoApprove` (PowerShell) or `--no-auto-approve` (Bash) to require manual confirmation.

Cost-optimized dev profile defaults:

- `az_count = 1`
- `node_instance_types = ["t3.medium"]`
- `node_capacity_type = "SPOT"`
- `node_desired_size = 1`
- `node_min_size = 1`
- `node_max_size = 1`

Prod profile defaults:

- `az_count = 2` (multi-AZ)
- `node_instance_types = ["m6a.large"]`
- `node_capacity_type = "ON_DEMAND"`
- `node_desired_size = 2`
- `node_min_size = 2`
- `node_max_size = 2`

Optional explicit overrides:

- Any `node_*` variable you set explicitly will override profile defaults.

### 1. Deploy infrastructure

```sh
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

### 2. Configure kubectl for the cluster

After apply completes:

```sh
aws eks update-kubeconfig --region <aws-region> --name <cluster-name>
```
Then deploy the service:

```sh
kubectl apply -f k8s/microservice.yml
```

## Cleanup

Terraform resources:

```sh
cd terraform
terraform destroy
```

Kubernetes workload only:

```sh
kubectl delete -f k8s/microservice.yml
```

## Notes

- The Docker container runs as a non-root user.
- The app Service is `ClusterIP`; Nginx is exposed via `NodePort` (not `LoadBalancer`).
- Extra-credit sidecar implemented: OpenTelemetry Collector runs as a sidecar in the app pod and receives telemetry on `localhost:4317`.
- Health probe traffic is excluded from manual request logging and OpenTelemetry tracing to reduce observability noise.
- No secrets are committed to this repository.
