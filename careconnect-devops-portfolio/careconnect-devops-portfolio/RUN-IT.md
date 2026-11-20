# Run It: step by step

Follow the steps in order. Every step has the same four parts:

- **Do:** the commands to type
- **You should see:** how to know it worked
- **Screenshot:** the picture to save for the portfolio (optional)
- **Remember:** the idea behind it, in one or two lines

**Also read:** [COURSE-MAP.md](COURSE-MAP.md) (every course section and where it lives), [LABS.md](LABS.md) (guided labs for Docker CLI, Dockerfile instructions, BuildKit, Terraform basics, Helm releases, DNS and HTTPS, HPA with Karpenter, OpenTelemetry on EKS, and ECR + OIDC + ArgoCD on EKS) and [INTERVIEW-QA.md](INTERVIEW-QA.md).

Run everything from the **repository root** (the folder that contains `README.md`) unless a step says otherwise. Steps 1 to 17 are **free**. Steps 20 to 26 use real AWS and cost a little money (Karpenter, Steps 22 to 25, is the optional part).

---

# PART 1: Run it with Docker

## Step 1: Get ready (10 minutes)
**Do:**
```
docker --version
kubectl version --client
helm version
kind version
git --version
gh --version
```
If something is missing, install it:
```
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install kubectl /usr/local/bin/ && rm kubectl
# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# kind
go install sigs.k8s.io/kind@latest && sudo ln -sf $(go env GOPATH)/bin/kind /usr/local/bin/kind
```
**You should see:** a version printed for each tool.
**Remember:** you are building a platform, not an app. The tools are: Docker (containers), Kubernetes (runs them), Helm (packages them), Terraform (builds the cloud), GitHub Actions and ArgoCD (deliver them).

## Step 2: Build and run one service (5 minutes)
**Do:**
```
docker build -t careconnect-doctors:dev apps/doctors
docker run -d --name doctors -p 8081:8080 careconnect-doctors:dev
curl localhost:8081/
curl localhost:8081/health
docker stop doctors && docker rm doctors
```
**You should see:** JSON with the service name and a container id, then `{"status":"UP"}`.
**Remember:** an **image** is the frozen package, a **container** is a running copy of it. `/health` is how the platform later knows a service is alive.

## Step 3: See why the image is small and safe (5 minutes)
**Do:**
```
docker images careconnect-doctors
docker build -f docker/examples/Dockerfile.go-single-stage -t careconnect-doctors:single apps/doctors
docker images careconnect-doctors
docker run --rm --entrypoint id careconnect-doctors:dev
```
**You should see:** the `single` image is much larger than `dev`, and `id` shows `uid=10001` (not root).
**Screenshot:** `docs/screenshots/01-image-size.png` (the two sizes).
**Remember:**
- **Multi-stage build:** compile in a big stage, ship only the result in a small stage. Smaller means faster and safer.
- **Non-root user:** if the app is attacked, it cannot act as root.
- **Layer order:** dependencies are copied before code, so rebuilds reuse the cache.
Open `apps/doctors/Dockerfile` and `apps/portal/Dockerfile` and find these three ideas.

## Step 4: Run the whole system with Docker Compose (10 to 15 minutes)
The first build is slow because Maven downloads dependencies.

**Do:**
```
cd compose
cp .env.example .env
docker compose up -d --build
docker compose ps
curl localhost:8080/portal/health
curl localhost:8080/doctors/health
curl localhost:8080/billing/health
```
**You should see:** every container `healthy` (give the Java services about a minute), and `{"status":"UP"}` from each URL.
**Screenshot:** `docs/screenshots/02-compose-healthy.png` (`docker compose ps`).
**Remember:**
- **Networks:** the gateway sits on `frontend`; databases sit on `backend`. The gateway cannot reach a database. This is a small copy of public and private subnets.
- **Health checks and `depends_on`:** a service starts only when what it needs is healthy.
- **Named volumes:** database data survives restarts.
Open `compose/compose.yaml` and find: networks, `healthcheck`, `depends_on`, `volumes`, `profiles`, `deploy.replicas`.

## Step 5: Prove load balancing and startup order (5 minutes)
**Do:**
```
for i in 1 2 3 4 5 6; do curl -s localhost:8080/appointments/; echo; done
docker compose ps -a
docker compose logs db-migrate
docker compose up -d --scale appointments=4
docker compose ps
docker compose --profile tools up -d
docker compose down -v
cd ..
```
**You should see:** the `container` value changes between replies. `db-migrate` shows `Exited (0)`. Scaling shows 4 appointment containers. Adminer (a database web page) starts only with the `tools` profile.
**Screenshot:** `docs/screenshots/03-load-balancing.png` (the curl loop).
**Remember:**
- **Replicas + a gateway** spread traffic across copies, so one failing copy does not stop the service.
- **`db-migrate` is a one-shot job:** it runs, exits successfully, and `billing` waits for it (`service_completed_successfully`).
- **Profiles** start optional tools only when asked. `down -v` also deletes volumes.

---

# PART 2: Run it on Kubernetes with Helm

## Step 6: Create a local cluster and load the images (15 minutes)
**Do:**
```
kind create cluster --name cc --config kubernetes/kind-config.yaml
kubectl get nodes
for s in portal appointments billing doctors booking; do docker build -t careconnect-$s:dev apps/$s && kind load docker-image careconnect-$s:dev --name cc; done
```
**You should see:** three nodes (one control plane, two workers) all `Ready`.
**Remember:**
- **Kubernetes** keeps your containers running. You describe what you want, and it makes reality match.
- **kind** runs a real cluster inside Docker, for free.
- `kind load` copies images into the cluster, because its nodes cannot see your local images otherwise.

## Step 7: Start the databases (3 minutes)
**Do:**
```
kubectl create namespace careconnect
kubectl apply -f kubernetes/datastores/
kubectl get pods,pvc -n careconnect
```
**You should see:** `postgres-0`, `mariadb-0` and `redis-0` becoming `1/1 Running`, and three PVCs `Bound`.
**Remember:** databases run as a **StatefulSet** (stable name, its own disk). A **PVC** is a pod's request for storage.

## Step 8: Deploy all five services with Helm (5 minutes)
**Do:**
```
for s in portal appointments billing doctors booking; do helm upgrade --install $s charts/careconnect-service -n careconnect -f gitops/envs/dev/$s.yaml; done
helm list -n careconnect
kubectl get pods -n careconnect -w
```
(Press Ctrl+C once all pods are `1/1`. Java pods take up to a minute.)
**You should see:** 5 Helm releases and 10 running pods.
**Screenshot:** `docs/screenshots/04-k8s-pods.png` (`helm list` and `kubectl get pods`).
**Remember:**
- **One Helm chart, five releases.** The chart is a template; each service's values file fills in the blanks.
- The chart also creates a Service, a ConfigMap, a ServiceAccount and a PodDisruptionBudget for each service. Run `helm template doctors charts/careconnect-service -f gitops/envs/dev/doctors.yaml | more` to see exactly what.

## Step 9: Open a service, and prove data survives (5 minutes)
**Do:**
```
kubectl port-forward svc/doctors 9001:80 -n careconnect > /dev/null 2>&1 &
sleep 2
curl localhost:9001/health
kill %1

kubectl exec postgres-0 -n careconnect -- psql -U careconnect -c "create table invoices(id int); insert into invoices values (1),(2);"
kubectl delete pod postgres-0 -n careconnect
kubectl wait --for=condition=ready pod/postgres-0 -n careconnect --timeout=120s
kubectl exec postgres-0 -n careconnect -- psql -U careconnect -c "select * from invoices;"
```
**You should see:** the two rows are still there after the pod was deleted and recreated.
**Screenshot:** `docs/screenshots/05-data-survives.png`.
**Remember:** a **Service** is a stable address in front of changing pods. Deleting a **pod** keeps the data, because the **volume** outlives it.

## Step 10: Watch Kubernetes heal itself (3 minutes)
**Do:**
```
kubectl delete pod -l app.kubernetes.io/name=doctors -n careconnect
kubectl get pods -n careconnect -l app.kubernetes.io/name=doctors -w
```
**You should see:** the deleted pods are replaced within seconds.
**Screenshot:** `docs/screenshots/06-self-healing.png`.
**Remember:** a **Deployment** keeps comparing "what I want" (2 pods) with "what exists" and fixes the difference. This loop is the heart of Kubernetes.

## Step 11: A bad release, and a rollback (5 minutes)
**Do:**
```
helm upgrade doctors charts/careconnect-service -n careconnect -f gitops/envs/dev/doctors.yaml --set image.tag=does-not-exist
kubectl get pods -n careconnect -l app.kubernetes.io/name=doctors
helm rollback doctors -n careconnect
kubectl get pods -n careconnect -l app.kubernetes.io/name=doctors
```
**You should see:** one new pod in `ImagePullBackOff` while the **old pods keep running**, then everything healthy after the rollback.
**Screenshot:** `docs/screenshots/07-bad-release.png`.
**Remember:**
- A **rolling update** only removes an old pod when a new one is ready, so a broken release does not cause downtime.
- **Readiness probes** decide who receives traffic.
- `helm rollback` restores the previous release.

---

# PART 3: GitOps and CI/CD (the headline of the project)

## Step 12: Put the project on GitHub with your names (10 minutes)
**Do:**
```
ME=$(gh api user -q .login)
grep -rl '<your-user>' gitops .github | xargs -r sed -i "s/<your-user>/$ME/g"
grep -rl '<dockerhub-user>' gitops kubernetes karpenter observability | xargs -r sed -i "s/<dockerhub-user>/YOUR_DOCKERHUB_NAME/g"
git init -b main
git add . && git commit -m "CareConnect DevOps portfolio"
gh repo create careconnect-devops-portfolio --public --source=. --push
```
(If this folder is inside another git repo, add its name to that repo's `.gitignore` first.)
**You should see:** the repo on GitHub, and a `pr-checks` workflow listed under Actions.
**Remember:** ArgoCD and GitHub Actions both read from GitHub, so this project must be the root of its own repository. Make it **public** so the cluster can read it without credentials.

## Step 13: Give GitHub permission to push images (5 minutes)
**Do:** create a free Docker Hub account and an access token (Docker Hub, Account settings, Security). Then:
```
gh secret set DOCKERHUB_USERNAME --body "YOUR_DOCKERHUB_NAME"
gh secret set DOCKERHUB_TOKEN
```
(The second command asks you to paste the token.)
**You should see:** both secrets listed with `gh secret list`.
**Remember:** secrets live in GitHub, never in files. Anything committed to Git is public history.

## Step 14: Let ArgoCD take over (10 minutes)
First remove what you installed by hand, so ArgoCD can own it:
**Do:**
```
helm uninstall portal appointments billing doctors booking -n careconnect
kubectl delete -f kubernetes/datastores/
kubectl delete pvc --all -n careconnect

kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
kubectl apply -f gitops/argocd/root-app.yaml
kubectl get applications -n argocd -w
```
Open the ArgoCD page:
```
kubectl port-forward svc/argocd-server -n argocd 8443:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```
In Codespaces, open the forwarded port 8443 (HTTPS). User: `admin`.
**You should see:** applications `root`, `careconnect-datastores` and one per service, all **Synced** and **Healthy**.
**Screenshot:** `docs/screenshots/08-argocd-green.png`.
**Remember:**
- **GitOps:** Git is the control panel. A tool inside the cluster (ArgoCD) compares Git with the cluster and makes them match.
- **App of apps:** you apply one file by hand (`root-app.yaml`); it creates everything else.
- Nobody runs `kubectl apply` or `helm install` for the services any more.

## Step 15: Make a release (15 minutes)
**Do:**
```
git tag v1.0.0
git push origin v1.0.0
gh run watch
git pull
git log --oneline -3
kubectl get deploy -n careconnect -o wide
```
The first release builds five images, including three Maven builds, so allow 8 to 12 minutes. On Docker Hub, make sure the new repositories are **Public**. Then press Refresh on the apps in ArgoCD (or wait about three minutes).
**You should see:** a green workflow with 5 builds, a new commit `ci: deploy v1.0.0 to dev` from a bot, and pods now running your Docker Hub images.
**Screenshots:** `docs/screenshots/09-actions-release.png`, `docs/screenshots/10-bot-commit.png`.
**Remember:**
- **CI never touches the cluster.** The workflow builds images, pushes them, and **commits the new version into Git**. ArgoCD sees that commit and deploys it.
- **Versioned tags** (`v1.0.0`), never `latest`, so you always know what runs and can go back.
- Always `git pull` after a release, because the bot made a commit.

## Step 16: Prove self-healing (3 minutes)
**Do:**
```
kubectl scale deploy appointments -n careconnect --replicas=5
kubectl get deploy appointments -n careconnect -w
```
**You should see:** ArgoCD puts it back to 2 within a few minutes (press Refresh to speed it up).
**Remember:** `selfHeal` undoes manual changes, so Git stays the truth. `prune` deletes things you removed from Git. To change anything, change Git.

## Step 17: A bad release, rolled back with Git (5 minutes)
**Do:** edit `gitops/envs/dev/portal.yaml`, set `tag: does-not-exist`, then:
```
git add -A && git commit -m "bad release" && git push
kubectl get pods -n careconnect -l app.kubernetes.io/name=portal -w
git revert HEAD --no-edit
git push
```
**You should see:** an `ImagePullBackOff` pod while the old ones keep serving, then everything healthy again after the revert.
**Screenshot:** `docs/screenshots/11-git-revert-rollback.png`.
**Remember:** the safest rollback in GitOps is `git revert`. It keeps the history honest. `kubectl rollout undo` would be reverted by ArgoCD straight away.

---

# PART 4: Infrastructure as code with Terraform

## Step 18: Plan a network (10 minutes)
**Do:**
```
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

cd terraform/examples/03-vpc-tfvars
terraform init
terraform validate
terraform plan -var-file=dev.tfvars
cd ../../..
```
**You should see:** a plan that lists a VPC, subnets, an internet gateway and route tables, ending with "Plan: N to add". (These examples point at a local AWS emulator by default; if `plan` complains about credentials, `validate` alone is fine.)
**Screenshot:** `docs/screenshots/12-terraform-plan.png`.
**Remember:**
- **Terraform** describes cloud resources in files and builds them for you. `plan` shows what will change, `apply` does it.
- **State** is Terraform's notebook of what exists. It can hold secrets, so it is never committed.
- **A VPC** is your private network: public subnets (can reach the internet), private subnets (for servers and databases), and a NAT gateway so private things can go out without being reachable.

## Step 19: Check the AWS cluster code without spending money (5 minutes)
**Do:**
```
cd terraform/eks-cluster && terraform init -backend=false && terraform validate && cd ../..
cd terraform/data-plane && terraform init -backend=false && terraform validate && cd ../..
cd terraform/eks-addons && echo '{}' > iam_policy.json && terraform init -backend=false && terraform validate && rm iam_policy.json && cd ../..
cd karpenter && terraform init -backend=false && terraform validate && cd ..
```
**You should see:** `Success! The configuration is valid.` four times.
**Remember:** the code is split by how often it changes and how risky it is: `eks-cluster` (network + cluster), `eks-addons` (software installed in the cluster), `data-plane` (databases and queues). Read `terraform/eks-cluster/eks.tf`: two IAM roles (one for the cluster, one for the worker nodes), a managed node group in **private** subnets, and the add-ons.

---

# PART 5: Real AWS (optional, costs money, do it in one sitting)

Before you start: create an AWS **Budget alert**, and check `aws sts get-caller-identity`. Expect roughly **$0.25 per hour** for the cluster, plus a little for the load balancer. You must finish with Step 26 (teardown).

## Step 20: Create the EKS cluster (20 minutes)
**Do:**
```
cd terraform/eks-cluster
terraform init
terraform apply
$(terraform output -raw update_kubeconfig)
kubectl get nodes
cd ../..
```
**You should see:** two worker nodes `Ready`, running in AWS.
**Screenshot:** `docs/screenshots/13-eks-nodes.png`.
**Remember:** EKS is Kubernetes with the control plane run by AWS. You own the worker nodes, the add-ons and your workloads.

## Step 21: Deploy CareConnect with a real load balancer (20 minutes)
**Do:**
```
cd terraform/eks-addons
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
terraform init
terraform apply -var vpc_id=$(terraform -chdir=../eks-cluster output -raw vpc_id)
cd ../..

for s in portal appointments billing doctors booking; do helm upgrade --install $s charts/careconnect-service -n careconnect --create-namespace -f gitops/envs/eks/$s.yaml; done
kubectl get ingress -n careconnect
```
Wait 2 to 3 minutes for an ADDRESS, then:
```
curl http://<the-address>/portal/
curl http://<the-address>/doctors/
```
(The images must exist on Docker Hub from Step 15, with the version named in `gitops/envs/eks/*.yaml`.)
**You should see:** each service answering with its name and container id, through one AWS Application Load Balancer. (The load balancer sends the path on unchanged, so the services answer on any path.)
**Screenshot:** `docs/screenshots/14-alb-curl.png`.
**Remember:**
- The **AWS Load Balancer Controller** turns an Ingress into a real ALB.
- **Pod Identity** gives each add-on its own AWS role with no access keys.
- All five services share **one** ALB (`group.name`), which saves money.

---

# PART 6: Karpenter, pod-driven node autoscaling (optional, real AWS, 4 demos)

**Do Steps 20 and 21 first** (Karpenter needs the EKS cluster and the Pod Identity add-on). Costs a little extra: Karpenter nodes are real EC2 instances, capped at **8 vCPUs per pool** in the manifests. Finish with Step 26.

**The big idea:** HPA adds **pods**. Karpenter adds **nodes**, but only when a pod cannot be scheduled, and it picks the cheapest instance that fits. It also removes nodes that are empty or underused.

## Step 22: Demo 1, install Karpenter with Terraform (15 minutes)
**Do:**
```
cd karpenter
terraform init
terraform apply
terraform output
cd ..
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
aws events list-rules --query "Rules[?contains(Name,'Karpenter')].Name"
```
**You should see:** one Karpenter pod `Running` (it runs on your managed node group, because Karpenter cannot create the node it runs on). The outputs show `node_role_name` and `interruption_queue`. The EventBridge list shows the rules that watch for Spot warnings, rebalance notices, instance state changes and health events.
**Screenshot:** `docs/screenshots/16-karpenter-running.png`.
**Remember:**
- **Architecture:** the controller watches for pods that are `Pending`, asks EC2 for a right-sized instance, and the node joins the cluster.
- **IAM:** two roles. The **controller role** (Pod Identity, no access keys) may create and terminate instances. The **node role** is what the new nodes use to join the cluster.
- **Discovery tags:** `karpenter.sh/discovery` on the private subnets and security group tell Karpenter where it may launch nodes.
- **EventBridge and SQS:** AWS events go into an SQS queue, and the controller reads the queue. The setting `interruptionQueue` in `karpenter/main.tf` is what turns Spot handling on.

## Step 23: Demo 2, On-Demand nodes, right-sizing and consolidation (10 minutes)
**Do:**
```
kubectl apply -f karpenter/manifests/ec2nodeclass.yaml -f karpenter/manifests/nodepool-ondemand.yaml
kubectl apply -f karpenter/manifests/inflate.yaml
kubectl scale deployment inflate --replicas=6
kubectl get nodeclaims -w
```
(Press Ctrl+C when a new node appears.)
```
kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type
```
Now shrink the demand and watch Karpenter clean up:
```
kubectl scale deployment inflate --replicas=1
kubectl get nodeclaims -w
```
**You should see:** 6 pods that each ask for 1 CPU make Karpenter launch one or two `on-demand` nodes sized to fit them (not a fixed node size). After you scale down, the extra node is **consolidated** (removed) after about a minute.
**Screenshot:** `docs/screenshots/17-consolidation.png`.
**Remember:**
- **EC2NodeClass** = the "how" (AMI, subnets, security group, disk, node role). **NodePool** = the "what and how much" (allowed instance types, capacity type, a CPU limit, expiry, consolidation rules).
- **Right-sizing:** Karpenter reads the pod **requests** and picks the best-fit instance. Pods without requests give it nothing to work with.
- **Consolidation:** `WhenEmptyOrUnderutilized` means it moves pods and deletes nodes that are empty or can be packed tighter. This is where the savings come from.
- **`limits.cpu: "8"`** is the safety cap so a mistake cannot launch a huge bill.

## Step 24: Demo 3, Spot nodes and instance diversification (10 minutes)
**Do:**
```
kubectl apply -f karpenter/manifests/nodepool-spot.yaml
kubectl scale deployment inflate --replicas=8
kubectl get nodeclaims -w
```
(Press Ctrl+C when new nodes appear.)
```
kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type,topology.kubernetes.io/zone
aws ec2 describe-spot-price-history --instance-types m5.large --product-descriptions "Linux/UNIX" --max-items 3 --query "SpotPriceHistory[].[AvailabilityZone,SpotPrice]"
```
**You should see:** the new nodes are `spot` (the Spot pool has a higher `weight`, so it is preferred), possibly of different instance types and zones. The price list shows the current Spot price. Compare it with the On-Demand price for the same type on the AWS pricing page: Spot is often around 70% cheaper, but the saving changes by type, zone and day.
**Screenshot:** `docs/screenshots/18-spot-nodes.png`.
**Remember:**
- **Spot** = spare AWS capacity at a big discount, but AWS can take it back with a **2-minute warning**.
- **Diversify:** allow many instance categories (`c`, `m`, `r`, `t`), sizes and zones. More choices means a lower chance that one capacity shortage hurts you, and better prices.
- Keep On-Demand as the fallback pool (the lower `weight`) for things that cannot be interrupted.

## Step 25: Demo 4, Spot interruption handling with zero downtime (15 minutes)
**Do:**
```
kubectl scale deployment inflate --replicas=0
kubectl apply -f karpenter/manifests/spot-workload-pdb.yaml
kubectl get pods -n careconnect -l app=appointments-spot -o wide
kubectl get pdb -n careconnect
```
Wait until the 4 pods are `Running`, then **simulate the AWS 2-minute Spot warning** for the node that hosts one of them:
```
NODE=$(kubectl get pods -n careconnect -l app=appointments-spot -o jsonpath='{.items[0].spec.nodeName}')
INSTANCE=$(kubectl get node $NODE -o jsonpath='{.spec.providerID}' | cut -d/ -f5)
ZONE=$(kubectl get node $NODE -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
QUEUE_URL=$(aws sqs get-queue-url --queue-name $(terraform -chdir=karpenter output -raw interruption_queue) --query QueueUrl --output text)
aws sqs send-message --queue-url $QUEUE_URL --message-body "{\"version\":\"0\",\"id\":\"11111111-2222-3333-4444-555555555555\",\"detail-type\":\"EC2 Spot Instance Interruption Warning\",\"source\":\"aws.ec2\",\"account\":\"$ACCOUNT\",\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"region\":\"us-east-1\",\"resources\":[\"arn:aws:ec2:$ZONE:$ACCOUNT:instance/$INSTANCE\"],\"detail\":{\"instance-id\":\"$INSTANCE\",\"instance-action\":\"terminate\"}}"
kubectl get deployment appointments-spot -n careconnect -w
```
In a second terminal:
```
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=30 | grep -i -E "interrupt|disrupt|drain"
kubectl get pods -n careconnect -l app=appointments-spot -o wide -w
```
**You should see:** Karpenter reads the message, starts a **replacement node**, **drains** the old one, and the pods are rescheduled. The deployment's `AVAILABLE` count never drops below 3 (75% of 4), because the **PodDisruptionBudget** does not allow more pods than that to be removed at once.
**Screenshot:** `docs/screenshots/19-spot-interruption.png`.
**Remember:**
- **The flow:** EC2 warning, EventBridge rule, SQS queue, Karpenter, cordon and drain the node, pods rescheduled, replacement node launched early.
- **PodDisruptionBudget** (`minAvailable: 75%`) is the zero-downtime promise during any voluntary drain.
- **Production-ready Spot:** several replicas, spread across zones (`topologySpreadConstraints`), a PDB, a readiness probe, a short `terminationGracePeriodSeconds`, diversified instance types, and an On-Demand fallback.
- Be exact about this demo: the message is a **simulation** (the instance is not really reclaimed). The official way to trigger a real one is AWS Fault Injection Service (FIS). Say "simulated" when you present it.

---

# PART 7: Tear down real AWS

## Step 26: Tear everything down (do not skip, 15 minutes)
**First:** if you did any AWS labs from [LABS.md](LABS.md), run each lab's **Cleanup** now, in this order: **Lab 21** (ArgoCD and ECR), **Lab 20** (observability), **Lab 18** (HPA), **Lab 15-16** (DNS and certificate). ArgoCD recreates anything you delete, so it goes first.
**Do:**
```
# If you did the Karpenter steps, remove its nodes FIRST:
kubectl delete -f karpenter/manifests/spot-workload-pdb.yaml --ignore-not-found
kubectl delete -f karpenter/manifests/inflate.yaml --ignore-not-found
kubectl delete nodepool --all
kubectl get nodeclaims          # wait until the list is empty (2 to 5 minutes)
kubectl delete ec2nodeclass --all
cd karpenter && terraform destroy && cd ..

# Then everything else:
helm uninstall portal appointments billing doctors booking -n careconnect
kubectl get svc,ingress,pvc -A
cd terraform/eks-addons && terraform destroy -var vpc_id=$(terraform -chdir=../eks-cluster output -raw vpc_id)
cd ../eks-cluster && terraform destroy
cd ../..
aws eks list-clusters
aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn"
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query "NatGateways[].NatGatewayId"
aws ec2 describe-instances --filters "Name=tag-key,Values=karpenter.sh/nodepool" "Name=instance-state-name,Values=pending,running" --query "Reservations[].Instances[].InstanceId"
aws ecr describe-repositories --query "repositories[].repositoryName"
aws logs describe-log-groups --log-group-name-prefix /aws/containerinsights/careconnect-eks --query "logGroups[].logGroupName"
aws route53 list-hosted-zones --query "HostedZones[].Name"
```
**You should see:** nothing left in those lists (the Route 53 zone only if you chose to keep your domain).
**Remember:** load balancers created by Kubernetes are **not** in Terraform's state. Delete the Kubernetes objects (Helm uninstall) **before** `terraform destroy`, or they are left behind, keep costing money and block the network from being deleted. Nodes created by Karpenter are **not** in Terraform's state either: delete the NodePools first so Karpenter terminates its own instances, otherwise they keep costing money and block the VPC from being deleted. (If you used ArgoCD on EKS, delete its Applications first, because ArgoCD recreates anything you delete.)

---

# PART 8: Observability (optional)

## Step 27: See traces for free (5 minutes)
**Do:**
```
cd observability/local-lab
docker compose up -d
```
Open the forwarded port **16686** (Jaeger). Pick the service `checkout`.
```
docker compose down
cd ../..
```
**You should see:** traces for `checkout`, and no traces from `health-probe`.
**Screenshot:** `docs/screenshots/15-jaeger.png`.
**Remember:**
- **Traces** show where a request spent time across services; **logs** say what happened; **metrics** show trends.
- The **collector** sits between apps and the backend: it batches, **filters noise** (health checks) and **samples**, which cuts cost.
- On EKS the same idea uses AWS X-Ray and Managed Prometheus: see `observability/manifests/`.

## Step 28: Clean up locally
**Do:**
```
kind delete cluster --name cc
docker system prune -f
```

---

# Extras (when you have time)

Each is small and self-contained. Do the ones you want to talk about.

**Multi-architecture image** (one tag for Intel and ARM). Needs `docker login`.
```
docker buildx create --name multi --driver docker-container --use
docker buildx build --platform linux/amd64,linux/arm64 -f docker/Dockerfile.go-multiarch -t YOUR_DOCKERHUB_NAME/careconnect-doctors:multi --push apps/doctors
docker buildx imagetools inspect YOUR_DOCKERHUB_NAME/careconnect-doctors:multi
```
Remember: a **manifest list** is one tag pointing to an image per CPU type.

**Ingress on kind** (one entry point, two services):
```
kind create cluster --name ing --config kubernetes/ingress/local-kind/kind-ingress.yaml
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s
for s in portal doctors; do docker build -t careconnect-$s:dev apps/$s && kind load docker-image careconnect-$s:dev --name ing; done
kubectl create namespace careconnect
kubectl apply -f kubernetes/ingress/local-kind/apps.yaml -f kubernetes/ingress/local-kind/ingress.yaml
curl localhost/portal/health && curl localhost/doctors/health
```
Remember: an **Ingress** routes by path or host to many Services. A controller (nginx here, the AWS controller on EKS) makes it real.

**Autoscaling (HPA)** with a CPU-hungry demo app:
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch -n kube-system deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl create namespace careconnect
kubectl apply -f kubernetes/hpa/01-php-apache.yaml -f kubernetes/hpa/02-hpa-cpu.yaml
kubectl run load -n careconnect --rm -it --image=busybox:1.36 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
kubectl get hpa -n careconnect -w
```
Remember: the **HPA** adds pods when CPU is high and removes them when it drops; pods need resource **requests** for this to work.

**Secrets**:
```
kubectl apply -f kubernetes/secrets/01-secret.yaml
kubectl get secret billing-db-credentials -n careconnect -o jsonpath="{.data.DB_PASSWORD}" | base64 -d; echo
```
Remember: base64 is **encoding, not encryption**. Real protection is RBAC, encryption at rest, and AWS Secrets Manager (`kubernetes/secrets/eks-only/`).

**Kubernetes building blocks** one by one (pod, deployment, service, ConfigMap, StatefulSet): `kubernetes/basics/`. **Storage** (PV, PVC, StorageClass): `kubernetes/storage/`.

**Terraform examples** (variables, remote state in S3 with locking, a reusable module): `terraform/examples/01-foundation` to `06-vpc-module`.

**Karpenter** now has its own guided steps (22 to 25) and a short explainer in `karpenter/README.md`. **DNS with HTTPS** needs real AWS and a domain: see `terraform/dns-and-tls/`. Mark each one "run" or "documented, not run" in the README, whichever is true.

---

# If something goes wrong

| Problem | Fix |
|---|---|
| `docker compose up` is very slow the first time | Maven is downloading dependencies. Wait, or build one service at a time |
| Pods stuck `ImagePullBackOff` on kind | The image was not loaded (`kind load docker-image ...`) or the Docker Hub repository is private |
| Java pods restart or are `OOMKilled` | Not enough memory for the cluster. Use a bigger Codespace or set `replicaCount: 1` in `gitops/envs/dev/*.yaml` |
| `kind create cluster` fails or is slow | Remove one `- role: worker` from `kubernetes/kind-config.yaml` |
| ArgoCD application shows an error | `repoURL` still has `<your-user>`, or the repository is private. Fix and push |
| `git push` is rejected after a release | The bot committed. Run `git pull --rebase` |
| `terraform plan` complains about credentials | You are using the emulator examples. Run `validate`, or use real AWS credentials |
