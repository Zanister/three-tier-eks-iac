**three-tier-eks-iac**

Complete Build Guide --- From Scratch

React · Node.js · MongoDB · AWS EKS · Terraform

| **\#** | **Phase**                      | **What happens**                                                  |
|--------|--------------------------------|-------------------------------------------------------------------|
| **1**  | **Prerequisites & Setup**      | Install tools, configure AWS CLI, create S3 state bucket          |
| **2**  | **Repo & Configuration**       | Clone repo, set your bucket name, review all Terraform files      |
| **3**  | **Terraform --- Provisioning** | VPC · EKS · IAM · Helm add-ons via terraform init/plan/apply      |
| **4**  | **kubectl Bootstrap**          | Connect kubectl, verify nodes and cluster add-ons are healthy     |
| **5**  | **Application Deployment**     | Build images (optional) and apply all K8s manifests in order      |
| **6**  | **Validation & Cleanup**       | End-to-end smoke test · troubleshooting table · terraform destroy |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>⚠ Time &amp; cost estimate</strong></p>
<p>Terraform apply: 15–20 min | K8s manifests: 5 min | Total: ~25–30 min</p>
<p>Running cost: ~$0.20–0.30/hr. Run terraform destroy when finished to stop billing.</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>Phase 1 · Prerequisites &amp; Setup</p>
<p><strong>Install all tools and configure AWS access</strong></p></td>
</tr>
</tbody>
</table>

|                                     |
|-------------------------------------|
| **Step 1.1 Install required tools** |

| **Tool**       | **Min Version** | **Notes**                                            |
|----------------|-----------------|------------------------------------------------------|
| **AWS CLI v2** | 2.x             | Must be v2 --- v1 has different eks get-token syntax |
| **Terraform**  | \~\> 1.0        | Any 1.x release works with this codebase             |
| **kubectl**    | 1.25+           | Should match or exceed your EKS cluster_version      |
| **Helm**       | 3.x             | Used to update chart repos after terraform apply     |
| **Docker**     | 20.x+           | Only needed if you want to build your own images     |
| **git**        | any             | To clone the repository                              |

|                                |
|--------------------------------|
| **Step 1.2 Configure AWS CLI** |

Run the following and enter your IAM credentials when prompted:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>aws configure</p>
<p>AWS Access Key ID : &lt;your-access-key-id&gt;</p>
<p>AWS Secret Access Key : &lt;your-secret-access-key&gt;</p>
<p>Default region name : us-west-2</p>
<p>Default output format : json</p></td>
</tr>
</tbody>
</table>

Verify the credentials work:

|                             |
|-----------------------------|
| aws sts get-caller-identity |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>✓ Expected output</strong></p>
<p>You should see your Account ID, UserId, and ARN.</p>
<p>If you get an error, recheck your key — do not proceed until this works.</p></td>
</tr>
</tbody>
</table>

|                                                              |
|--------------------------------------------------------------|
| **Step 1.3 Create the S3 bucket for Terraform remote state** |

Terraform stores its state remotely in S3. You must create this bucket before running terraform init. Bucket names are globally unique across all AWS accounts.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p># Replace &lt;YOUR-BUCKET&gt; with a unique name e.g. yourname-eks-tfstate-2024</p>
<p>aws s3api create-bucket \</p>
<p>--bucket &lt;YOUR-BUCKET&gt; \</p>
<p>--region us-west-2 \</p>
<p>--create-bucket-configuration LocationConstraint=us-west-2</p>
<p># Enable versioning to protect against accidental state corruption</p>
<p>aws s3api put-bucket-versioning \</p>
<p>--bucket &lt;YOUR-BUCKET&gt; \</p>
<p>--versioning-configuration Status=Enabled</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>⚠ Write down your bucket name</strong></p>
<p>You will paste this exact value into backend.tf in Step 2.1.</p>
<p>Bucket names cannot be changed after creation.</p></td>
</tr>
</tbody>
</table>

|                                             |
|---------------------------------------------|
| **Step 1.4 Update Helm chart repositories** |

|                  |
|------------------|
| helm repo update |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>Phase 2 · Repository &amp; Configuration</p>
<p><strong>Clone and customise the project for your AWS account</strong></p></td>
</tr>
</tbody>
</table>

|                                   |
|-----------------------------------|
| **Step 2.1 Clone the repository** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>git clone https://github.com/LondheShubham153/three-tier-eks-iac.git</p>
<p>cd three-tier-eks-iac</p></td>
</tr>
</tbody>
</table>

Key directory structure:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>three-tier-eks-iac/</p>
<p>├── terraform/</p>
<p>│ ├── backend.tf ← S3 remote state (EDIT THIS)</p>
<p>│ ├── variables.tf ← cluster name, region</p>
<p>│ ├── provider.tf ← AWS + kubectl + Helm providers</p>
<p>│ ├── vpc.tf ← VPC, subnets, NAT gateway</p>
<p>│ ├── eks.tf ← EKS cluster, 2 node groups</p>
<p>│ ├── iam.tf ← IAM roles + admin user</p>
<p>│ ├── autoscaler-iam.tf ← IRSA role for Cluster Autoscaler</p>
<p>│ ├── autoscaler-manifest.tf ← K8s resources for Autoscaler</p>
<p>│ ├── helm-provider.tf ← Helm provider auth config</p>
<p>│ └── helm-load-balancer-controller.tf</p>
<p>├── k8s_manifests/</p>
<p>│ ├── mongo/ ← secrets.yaml, deploy.yaml, service.yaml</p>
<p>│ ├── backend-deployment.yaml</p>
<p>│ ├── backend-service.yaml</p>
<p>│ ├── frontend-deployment.yaml</p>
<p>│ ├── frontend-service.yaml</p>
<p>│ └── full_stack_lb.yaml ← Ingress (creates the AWS ALB)</p>
<p>└── app/</p>
<p>├── backend/ ← Node.js source + Dockerfile</p>
<p>└── frontend/ ← React source + Dockerfile</p></td>
</tr>
</tbody>
</table>

|                                                         |
|---------------------------------------------------------|
| **Step 2.2 Update backend.tf with your S3 bucket name** |

Open terraform/backend.tf and replace the bucket name:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>terraform {</p>
<p>backend "s3" {</p>
<p>bucket = "&lt;YOUR-BUCKET&gt;" # ← paste your bucket name here</p>
<p>key = "eks/terraform.tfstate"</p>
<p>region = "us-west-2"</p>
<p>}</p>
<p>}</p></td>
</tr>
</tbody>
</table>

|                                                       |
|-------------------------------------------------------|
| **Step 2.3 Review variables.tf --- change if needed** |

These defaults work as-is for a us-west-2 deployment:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>cluster_name = "my-eks-cluster" # change if you want a different name</p>
<p>cluster_version = 1.25</p>
<p>region = "us-west-2" # if you change this, also update backend.tf</p>
<p>availability_zones = ["us-west-2a", "us-west-2b"]</p></td>
</tr>
</tbody>
</table>

|                                                   |
|---------------------------------------------------|
| **Step 2.4 Understand what Terraform will build** |

| **Terraform file** | **AWS/K8s resource**          | **Key details**                                               |
|--------------------|-------------------------------|---------------------------------------------------------------|
| vpc.tf             | **VPC + subnets**             | 10.0.0.0/16, 2 public + 2 private, single NAT gateway         |
| iam.tf             | **IAM roles + user**          | eks-admin role, allow-eks-access policy, user1                |
| eks.tf             | **EKS cluster v1.25**         | IRSA enabled, aws_auth_configmap wired to eks-admin role      |
| eks.tf             | **Node group: general**       | t3.small ON_DEMAND, min 1 / max 10, no taint                  |
| eks.tf             | **Node group: spot**          | t3.micro SPOT, min 1 / max 10, taint: market=spot:NO_SCHEDULE |
| autoscaler-iam     | **IRSA role (autoscaler)**    | Bound to OIDC, lets the pod call EC2 ASG APIs                 |
| autoscaler-mfst    | **K8s Autoscaler Deployment** | ServiceAccount, ClusterRole/Binding, Deployment v1.23.1       |
| helm-provider      | **Helm provider config**      | Authenticates to EKS via aws eks get-token exec block         |
| helm-lbc           | **AWS LB Controller**         | IRSA role + Helm release v1.4.4 from eks-charts               |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>Phase 3 · Terraform — Infrastructure Provisioning</p>
<p><strong>Provision the full AWS infrastructure with three commands</strong></p></td>
</tr>
</tbody>
</table>

Run all commands from inside the terraform/ directory:

|              |
|--------------|
| cd terraform |

|                             |
|-----------------------------|
| **Step 3.1 terraform init** |

Downloads all provider plugins and modules, and connects to your S3 backend bucket.

|                |
|----------------|
| terraform init |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>✓ Expected output</strong></p>
<p>Terraform has been successfully initialized!</p>
<p>Downloads: hashicorp/aws, gavinbunney/kubectl, hashicorp/helm</p>
<p>Modules: terraform-aws-modules/vpc, /eks, /iam</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>⚠ If init fails</strong></p>
<p>'NoSuchBucket': bucket name in backend.tf does not match what you created in Step 1.3.</p>
<p>'AccessDenied': IAM user needs s3:GetObject, s3:PutObject, s3:ListBucket on the bucket.</p>
<p>'Could not load credentials': run aws configure again and verify aws sts get-caller-identity.</p></td>
</tr>
</tbody>
</table>

|                             |
|-----------------------------|
| **Step 3.2 terraform plan** |

Preview every resource Terraform will create without making any changes. Always review before applying.

|                |
|----------------|
| terraform plan |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>✓ What to expect (~55–65 resources planned)</strong></p>
<p>VPC, 4 subnets, 1 NAT gateway, route tables, internet gateway</p>
<p>1 EKS cluster, 2 managed node groups, 1 OIDC provider</p>
<p>IAM roles and policies for eks-admin, LB controller, and autoscaler</p>
<p>1 Helm release (aws-load-balancer-controller)</p>
<p>kubectl_manifest resources: ServiceAccount, ClusterRole/Binding, Autoscaler Deployment</p></td>
</tr>
</tbody>
</table>

|                              |
|------------------------------|
| **Step 3.3 terraform apply** |

Provisions everything. EKS control plane creation takes the most time --- expect 15--20 minutes total.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>terraform apply</p>
<p># Type 'yes' at the prompt to confirm</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>✓ Success indicator</strong></p>
<p>Apply complete! Resources: XX added, 0 changed, 0 destroyed.</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>⚠ Charges start immediately after apply</strong></p>
<p>NAT Gateway: ~$0.045/hr + data transfer costs</p>
<p>EKS control plane: ~$0.10/hr</p>
<p>EC2 t3.small (general, ON_DEMAND): ~$0.0208/hr</p>
<p>EC2 t3.micro (spot, SPOT): ~$0.003–0.004/hr</p>
<p>Total: roughly $0.20–0.30/hr. Run terraform destroy when finished.</p></td>
</tr>
</tbody>
</table>

|                                             |
|---------------------------------------------|
| **Step 3.4 Verify the cluster was created** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>aws eks describe-cluster --name my-eks-cluster --region us-west-2 \</p>
<p>--query "cluster.status" --output text</p>
<p># Expected: ACTIVE</p>
<p>aws eks list-nodegroups --cluster-name my-eks-cluster --region us-west-2</p>
<p># Expected: [ 'general', 'spot' ]</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>Phase 4 · kubectl Bootstrap</p>
<p><strong>Connect kubectl to your cluster and verify all add-ons are healthy</strong></p></td>
</tr>
</tbody>
</table>

|                                      |
|--------------------------------------|
| **Step 4.1 Update local kubeconfig** |

Writes EKS authentication details into \~/.kube/config so kubectl knows where to connect and how to get a token.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>aws eks update-kubeconfig \</p>
<p>--name my-eks-cluster \</p>
<p>--region us-west-2</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>✓ Expected output</strong></p>
<p>Added new context arn:aws:eks:us-west-2:&lt;account-id&gt;:cluster/my-eks-cluster</p></td>
</tr>
</tbody>
</table>

|                                                    |
|----------------------------------------------------|
| **Step 4.2 Verify cluster access and node health** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl auth can-i "*" "*"</p>
<p># Expected: yes</p>
<p>kubectl get nodes -o wide</p>
<p># Expected: 2 nodes both in STATUS=Ready</p>
<p># NAME STATUS ROLES</p>
<p># ip-10-0-x-x.ec2.internal Ready &lt;none&gt;</p>
<p># ip-10-0-x-x.ec2.internal Ready &lt;none&gt;</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>⚠ If nodes are NotReady</strong></p>
<p>Wait 2–3 more minutes. Nodes join after the control plane is ready.</p>
<p>If still not ready after 5 min: aws eks describe-nodegroup --cluster-name my-eks-cluster --nodegroup-name general</p></td>
</tr>
</tbody>
</table>

|                                                      |
|------------------------------------------------------|
| **Step 4.3 Verify the AWS Load Balancer Controller** |

This must be Running before you apply the Ingress in Phase 5 --- it is what creates the ALB.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl get pods -n kube-system \</p>
<p>-l app.kubernetes.io/name=aws-load-balancer-controller</p>
<p># Expected: 1/1 Running</p></td>
</tr>
</tbody>
</table>

|                                            |
|--------------------------------------------|
| **Step 4.4 Verify the Cluster Autoscaler** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl get pods -n kube-system -l app=cluster-autoscaler</p>
<p># Expected: 1/1 Running</p>
<p>kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20</p>
<p># Look for: 'Successfully registered node group'</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>✓ All green?</strong></p>
<p>Both add-ons Running + both nodes Ready = cluster fully operational.</p>
<p>Proceed to Phase 5.</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>Phase 5 · Application Deployment</p>
<p><strong>Build images (optional) and apply all Kubernetes manifests in order</strong></p></td>
</tr>
</tbody>
</table>

|                                                   |
|---------------------------------------------------|
| **Step 5.1 Decide: pre-built images or your own** |

The repo manifests already reference public images on ECR Public (public.ecr.aws/w8u5e4v2/). If you haven\'t modified the app code, skip Step 5.2 entirely and go straight to Step 5.3.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>→ Use pre-built images (recommended for first run)</strong></p>
<p>Skip Step 5.2.</p>
<p>The deployment manifests already contain the correct image URIs.</p>
<p>You will be using: public.ecr.aws/w8u5e4v2/workshop-frontend:v1</p>
<p>public.ecr.aws/w8u5e4v2/workshop-backend:v1</p></td>
</tr>
</tbody>
</table>

|                                                                              |
|------------------------------------------------------------------------------|
| **Step 5.2 Build and push your own Docker images (skip if using pre-built)** |

Authenticate to ECR Public:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>aws ecr-public get-login-password --region us-east-1 \</p>
<p>| docker login --username AWS --password-stdin public.ecr.aws</p></td>
</tr>
</tbody>
</table>

Build and push the frontend (run from app/frontend/):

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>cd app/frontend</p>
<p># Linux / Windows:</p>
<p>docker build -t workshop-frontend:v1 .</p>
<p># Mac Apple Silicon — must target amd64 for EKS nodes:</p>
<p>docker buildx build --platform linux/amd64 -t workshop-frontend:v1 .</p>
<p>docker tag workshop-frontend:v1 public.ecr.aws/&lt;YOUR-ALIAS&gt;/workshop-frontend:v1</p>
<p>docker push public.ecr.aws/&lt;YOUR-ALIAS&gt;/workshop-frontend:v1</p>
<p>cd ../..</p></td>
</tr>
</tbody>
</table>

Build and push the backend (run from app/backend/):

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>cd app/backend</p>
<p>docker build -t workshop-backend:v1 . # Linux/Windows</p>
<p>docker buildx build --platform linux/amd64 -t workshop-backend:v1 . # Mac</p>
<p>docker tag workshop-backend:v1 public.ecr.aws/&lt;YOUR-ALIAS&gt;/workshop-backend:v1</p>
<p>docker push public.ecr.aws/&lt;YOUR-ALIAS&gt;/workshop-backend:v1</p>
<p>cd ../..</p></td>
</tr>
</tbody>
</table>

After pushing, update the image: lines in both deployment manifests to point to your registry.

|                                              |
|----------------------------------------------|
| **Step 5.3 Create the Kubernetes namespace** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl create namespace workshop</p>
<p># Set workshop as active namespace (saves typing -n workshop every command)</p>
<p>kubectl config set-context --current --namespace workshop</p>
<p>kubectl get namespace workshop</p>
<p># Expected: workshop Active</p></td>
</tr>
</tbody>
</table>

|                                                           |
|-----------------------------------------------------------|
| **Step 5.4 Deploy MongoDB --- apply in this exact order** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>⚠ Order is critical</strong></p>
<p>The Secret MUST exist before the Deployment reads from it.</p>
<p>Apply secrets.yaml first, always.</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>cd k8s_manifests</p>
<p>kubectl apply -f mongo/secrets.yaml # creates Secret: mongo-sec</p>
<p>kubectl apply -f mongo/deploy.yaml # creates Deployment: mongodb</p>
<p>kubectl apply -f mongo/service.yaml # creates Service: mongodb-svc</p>
<p># Wait for MongoDB to be fully ready before continuing</p>
<p>kubectl rollout status deployment/mongodb</p>
<p># Expected: deployment 'mongodb' successfully rolled out</p></td>
</tr>
</tbody>
</table>

| **File**     | **What it creates**                                                                                                                                                              |
|--------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| secrets.yaml | Secret \'mongo-sec\': username=admin, password=password123 (base64-encoded). Applied first so the Deployment can read from it.                                                   |
| deploy.yaml  | 1-replica Deployment: mongo:4.4.6. Overrides default command to add numactl (NUMA memory balancing) and caps WiredTiger cache at 100MB to avoid starving other pods on the node. |
| service.yaml | ClusterIP Service \'mongodb-svc\' on port 27017. This DNS name is what the backend uses in its MONGO_CONN_STR connection string.                                                 |

|                                     |
|-------------------------------------|
| **Step 5.5 Deploy the Backend API** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl apply -f backend-deployment.yaml</p>
<p>kubectl apply -f backend-service.yaml</p>
<p>kubectl rollout status deployment/api</p>
<p># Expected: deployment 'api' successfully rolled out</p>
<p>kubectl get pods -l role=api</p>
<p># Expected: 2/2 pods Running (replicas: 2 in the manifest)</p></td>
</tr>
</tbody>
</table>

The backend deployment: 2 replicas of the Node.js image, reads credentials from mongo-sec Secret, connects to MongoDB via mongodb://mongodb-svc:27017/todo, has liveness and readiness probes on GET /ok:8080, exposed as ClusterIP service \'api\' on port 8080.

|                                  |
|----------------------------------|
| **Step 5.6 Deploy the Frontend** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl apply -f frontend-deployment.yaml</p>
<p>kubectl apply -f frontend-service.yaml</p>
<p>kubectl rollout status deployment/frontend</p>
<p># Expected: deployment 'frontend' successfully rolled out</p>
<p>kubectl get pods -l role=frontend</p>
<p># Expected: 1/1 Running</p></td>
</tr>
</tbody>
</table>

|                                                               |
|---------------------------------------------------------------|
| **Step 5.7 Apply the Ingress --- this triggers ALB creation** |

The Ingress resource tells the AWS Load Balancer Controller to create an internet-facing Application Load Balancer. It routes / to the frontend (port 3000) and /api to the backend (port 8080).

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl apply -f full_stack_lb.yaml</p>
<p># Watch for the ALB DNS name to appear — takes 2–3 minutes</p>
<p>kubectl get ingress mainlb -w</p>
<p># Wait until ADDRESS is populated:</p>
<p># NAME CLASS HOSTS ADDRESS</p>
<p># mainlb alb app.sandipdas.in k8s-workshop-mainlb-xxxx.us-west-2.elb.amazonaws.com</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>⚠ About the host: app.sandipdas.in</strong></p>
<p>This is the original author's domain. To test without a custom domain, choose one of:</p>
<p>Option A: Add '127.0.0.1 app.sandipdas.in' to /etc/hosts and add the ALB IP (works for quick tests)</p>
<p>Option B: Remove the 'host:' line from full_stack_lb.yaml so all requests match</p>
<p>Option C: Replace with your own domain and add a CNAME record pointing to the ALB DNS name</p></td>
</tr>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>Phase 6 · Validation &amp; Cleanup</p>
<p><strong>Smoke-test the live app and tear down all resources</strong></p></td>
</tr>
</tbody>
</table>

|                                |
|--------------------------------|
| **Step 6.1 Full health check** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl get pods -n workshop</p>
<p># Expected — all READY 1/1 and STATUS Running:</p>
<p># api-xxxx-yyyy 1/1 Running</p>
<p># api-xxxx-zzzz 1/1 Running</p>
<p># frontend-xxxx-yyyy 1/1 Running</p>
<p># mongodb-xxxx-yyyy 1/1 Running</p>
<p>kubectl get svc -n workshop</p>
<p># Expected:</p>
<p># api ClusterIP &lt;ip&gt; 8080/TCP</p>
<p># frontend ClusterIP &lt;ip&gt; 3000/TCP</p>
<p># mongodb-svc ClusterIP &lt;ip&gt; 27017/TCP</p></td>
</tr>
</tbody>
</table>

|                                     |
|-------------------------------------|
| **Step 6.2 Smoke-test via the ALB** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p># Get the ALB hostname</p>
<p>ALB=$(kubectl get ingress mainlb -n workshop \</p>
<p>-o jsonpath='{.status.loadBalancer.ingress[0].hostname}')</p>
<p>echo "ALB endpoint: $ALB"</p>
<p># Backend health check</p>
<p>curl -H "Host: app.sandipdas.in" http://$ALB/ok</p>
<p># Expected: OK</p>
<p># List tasks (empty on first run)</p>
<p>curl -H "Host: app.sandipdas.in" http://$ALB/api/tasks</p>
<p># Expected: []</p>
<p># Create a task</p>
<p>curl -X POST \</p>
<p>-H "Host: app.sandipdas.in" \</p>
<p>-H "Content-Type: application/json" \</p>
<p>-d '{"title":"my first task"}' \</p>
<p>http://$ALB/api/tasks</p>
<p># Expected: {"_id":"...","title":"my first task", ...}</p></td>
</tr>
</tbody>
</table>

|                                        |
|----------------------------------------|
| **Step 6.3 Troubleshooting reference** |

| **Symptom**                    | **Diagnostic command**                                                             | **What to look for / fix**                                                             |
|--------------------------------|------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| **Pod stuck in Pending**       | kubectl describe pod \<n\>                                                         | Events section --- usually no node capacity or resource request too large              |
| **ALB ADDRESS empty**          | kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller | IRSA permission error or missing subnet tags                                           |
| **Backend CrashLoopBackOff**   | kubectl logs -l role=api                                                           | MongoDB connection refused --- check secrets.yaml was applied and mongodb pod is Ready |
| **curl returns 503**           | kubectl get pods -l role=api                                                       | Backend not ready yet --- wait for rollout status to complete                          |
| **ImagePullBackOff**           | kubectl describe pod \<n\>                                                         | ECR image path wrong in manifest or image not public                                   |
| **terraform apply fails Helm** | Re-run terraform apply                                                             | Cluster may not be fully ready when Helm runs --- apply is idempotent, safe to retry   |
| **curl: connection refused**   | kubectl get ingress mainlb                                                         | ADDRESS still empty --- ALB not provisioned yet, wait 2--3 more minutes                |

|                                       |
|---------------------------------------|
| **Step 6.4 Cleanup --- stop billing** |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>⚠ Critical order: K8s resources before terraform destroy</strong></p>
<p>Deleting the Ingress tells the LB Controller to remove the ALB from AWS.</p>
<p>If you run terraform destroy BEFORE deleting the Ingress, the ALB is orphaned</p>
<p>and terraform destroy may hang on VPC deletion.</p></td>
</tr>
</tbody>
</table>

Step 1 --- Delete K8s resources (from k8s_manifests/):

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>kubectl delete -f full_stack_lb.yaml</p>
<p># Wait 2 minutes for AWS to remove the ALB before continuing</p>
<p>kubectl delete -f frontend-service.yaml</p>
<p>kubectl delete -f frontend-deployment.yaml</p>
<p>kubectl delete -f backend-service.yaml</p>
<p>kubectl delete -f backend-deployment.yaml</p>
<p>kubectl delete -f mongo/service.yaml</p>
<p>kubectl delete -f mongo/deploy.yaml</p>
<p>kubectl delete -f mongo/secrets.yaml</p>
<p>kubectl delete namespace workshop</p></td>
</tr>
</tbody>
</table>

Step 2 --- Destroy Terraform infrastructure (from terraform/):

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>cd terraform</p>
<p>terraform destroy</p>
<p># Type 'yes' — takes 10–15 minutes</p>
<p># Expected: Destroy complete! Resources: XX destroyed.</p></td>
</tr>
</tbody>
</table>

Step 3 --- Optionally delete the S3 state bucket:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>aws s3 rm s3://&lt;YOUR-BUCKET&gt; --recursive</p>
<p>aws s3api delete-bucket --bucket &lt;YOUR-BUCKET&gt; --region us-west-2</p></td>
</tr>
</tbody>
</table>

**Quick Reference --- All Commands**

| **What**                | **Command**                                                                                             |
|-------------------------|---------------------------------------------------------------------------------------------------------|
| Init Terraform          | cd terraform && terraform init                                                                          |
| Plan Terraform          | cd terraform && terraform plan                                                                          |
| Apply Terraform         | cd terraform && terraform apply                                                                         |
| Destroy Terraform       | cd terraform && terraform destroy                                                                       |
| Connect kubectl to EKS  | aws eks update-kubeconfig \--name my-eks-cluster \--region us-west-2                                    |
| Verify AWS identity     | aws sts get-caller-identity                                                                             |
| Check all nodes         | kubectl get nodes -o wide                                                                               |
| Check all pods          | kubectl get pods -n workshop                                                                            |
| Check all services      | kubectl get svc -n workshop                                                                             |
| Get ingress + ALB DNS   | kubectl get ingress mainlb -n workshop                                                                  |
| Get ALB hostname only   | kubectl get ingress mainlb -o jsonpath=\'{.status.loadBalancer.ingress\[0\].hostname}\'                 |
| Watch pod logs          | kubectl logs -f \<POD\> -n workshop                                                                     |
| Describe a pod          | kubectl describe pod \<POD\> -n workshop                                                                |
| LB controller logs      | kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller                      |
| Autoscaler logs         | kubectl logs -n kube-system -l app=cluster-autoscaler                                                   |
| Shell into a pod        | kubectl exec -it \<POD\> -n workshop \-- /bin/sh                                                        |
| Decode a secret         | kubectl get secret mongo-sec -o jsonpath=\'{.data.password}\' \| base64 -d                              |
| Rollout status          | kubectl rollout status deployment/\<name\> -n workshop                                                  |
| Restart a deployment    | kubectl rollout restart deployment/\<name\> -n workshop                                                 |
| Check node group status | aws eks describe-nodegroup \--cluster-name my-eks-cluster \--nodegroup-name general \--region us-west-2 |
