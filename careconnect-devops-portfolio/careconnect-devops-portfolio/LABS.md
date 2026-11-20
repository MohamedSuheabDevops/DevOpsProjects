# Labs: the course topics that need a guided run

[RUN-IT.md](RUN-IT.md) is the main path (Steps 1 to 28). This file adds one lab for each course section that RUN-IT only touches lightly. Same format: **Do**, **You should see**, **Remember**, **Say in an interview**. Run everything from the repository root unless a lab says otherwise.

| Lab | Course section | Cost | Needs |
|---|---|---|---|
| [Lab 2](#lab-2-docker-cli-and-docker-on-ec2-section-2) | 2: Docker commands | Free (EC2 part: pennies) | Docker |
| [Lab 3](#lab-3-every-dockerfile-instruction-security-and-layer-caching-section-3) | 3: Dockerfile mastery | Free | Docker |
| [Lab 5](#lab-5-buildkit-and-buildx-section-5) | 5: BuildKit | Free | Docker |
| [Lab 6](#lab-6-terraform-tools-and-the-six-examples-section-6) | 6: Terraform basics | Free (emulator) | Terraform |
| [Lab 19](#lab-19-helm-release-management-section-19) | 19: Helm | Free | kind cluster (Steps 6 and 7) |
| [Lab 15-16](#lab-15-16-externaldns-route-53-and-https-with-acm-sections-15-and-16) | 15 and 16: DNS and HTTPS | Domain + AWS | EKS (Steps 20, 21) |
| [Lab 18](#lab-18-hpa-and-karpenter-together-section-18) | 18: HPA | AWS | EKS and Karpenter (Steps 20 to 24) |
| [Lab 20](#lab-20-opentelemetry-on-eks-section-20) | 20: Observability | AWS | EKS (Steps 20, 21) |
| [Lab 21](#lab-21-ci-with-ecr-and-oidc-then-argocd-on-eks-section-21) | 21: CI/CD | AWS | EKS (Steps 20, 21) |

**Every AWS lab has its own cleanup, and [Step 26](RUN-IT.md) deletes all of it in the right order.** Do the cleanup the same day.

---

# FREE LABS

## Lab 2: Docker CLI and Docker on EC2 (Section 2)

**Part A: install Docker on Amazon Linux 2023 (an EC2 `t3.micro`)**
**Do:** (on the EC2 instance)
```
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
exit
```
Log in again (so the group applies), then:
```
docker --version
docker run --rm hello-world
```
**You should see:** a version, then "Hello from Docker!".
**Remember:** `dnf` is the package manager on Amazon Linux 2023. Adding your user to the `docker` group avoids typing `sudo` on every command. **Terminate the instance when you finish.**

**Part B: the commands, one by one**
**Do:**
```
docker pull nginx:1.27-alpine
docker images
docker run -d --name web -p 8088:80 nginx:1.27-alpine
docker ps
curl localhost:8088
docker logs web
docker exec -it web sh          # type: ls /usr/share/nginx/html   then: exit
docker inspect web --format '{{.State.Status}}  {{.NetworkSettings.IPAddress}}'
docker stop web
docker start web
docker rm -f web
docker rmi nginx:1.27-alpine
```
**You should see:** nginx's welcome page, its access log line, a shell inside the container, then everything removed.
**Remember (container lifecycle):**
| State | Command that gets you there |
|---|---|
| created | `docker create` |
| running | `docker run` (create + start), `docker start` |
| stopped | `docker stop` (graceful, SIGTERM then SIGKILL after 10 s), `docker kill` (immediate) |
| removed | `docker rm` (container), `docker rmi` (image) |

`-p 8088:80` means host port 8088 to container port 80. `exec` runs a new process inside a running container. `logs` shows its stdout and stderr. `inspect` shows everything as JSON.

**Part C: build an image and push it to a registry**
**Do:**
```
docker login
docker build -t YOUR_DOCKERHUB_NAME/careconnect-doctors:1.0.0 apps/doctors
docker push YOUR_DOCKERHUB_NAME/careconnect-doctors:1.0.0
docker rmi YOUR_DOCKERHUB_NAME/careconnect-doctors:1.0.0
docker pull YOUR_DOCKERHUB_NAME/careconnect-doctors:1.0.0
docker tag YOUR_DOCKERHUB_NAME/careconnect-doctors:1.0.0 YOUR_DOCKERHUB_NAME/careconnect-doctors:stable
```
**You should see:** the image uploaded, deleted locally, then downloaded again.
**Remember:** an image name is `registry/user/name:tag`. A tag is a label, not a version guarantee, which is why releases use `1.0.0` and never `latest`. For AWS ECR the login is:
```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```
**Say in an interview:** "A container is a running instance of an image. I manage the lifecycle with run, stop, start and rm, debug with logs, exec and inspect, and ship images by tagging and pushing to a registry."

---

## Lab 3: Every Dockerfile instruction, security and layer caching (Section 3)

**Do:** (one image with every instruction)
```
cd docker/examples/all-instructions
docker build -t instructions-demo:1.0 .
docker run --rm instructions-demo:1.0
docker run --rm instructions-demo:1.0 world
docker run --rm -e APP_ENV=prod instructions-demo:1.0
docker build --build-arg APP_VERSION=2.0.0 -t instructions-demo:2.0 .
docker run --rm instructions-demo:2.0
docker run --rm --entrypoint sh instructions-demo:1.0 -c 'id -u; ls -R /app'
docker inspect instructions-demo:2.0 --format '{{json .Config.Labels}}  user={{.Config.User}}'
cd ../../..
```
**You should see:** `args: hello`, then `args: world` (CMD replaced, ENTRYPOINT kept), `APP_ENV: prod` (ENV overridden at run time), `APP_VERSION: 2.0.0` (ARG set at build time), `user: 10001`, and the files extracted from the tar by `ADD`.
**Remember (the pairs people get wrong):**
| Pair | Difference |
|---|---|
| `CMD` vs `ENTRYPOINT` | ENTRYPOINT is the program. CMD is its default arguments, replaced by anything after the image name. |
| `COPY` vs `ADD` | Use COPY. ADD also extracts local tar files and can fetch URLs, which is surprising. |
| `ARG` vs `ENV` | ARG exists only during the build. ENV also exists in the running container. |
| `EXPOSE` vs `-p` | EXPOSE is documentation. `-p` actually publishes the port. |
| `RUN` vs `CMD` | RUN runs at build time and creates a layer. CMD runs when the container starts. |

**Do:** (layer caching: good order vs bad order)
```
docker build -t portal:good apps/portal
docker build -f docker/examples/Dockerfile.java-bad-cache -t portal:bad apps/portal
# now change one line of Java (add a comment) and rebuild both:
echo "// touch" >> apps/portal/src/main/java/com/careconnect/portal/PortalApplication.java
docker build -t portal:good apps/portal
docker build -f docker/examples/Dockerfile.java-bad-cache -t portal:bad apps/portal
git checkout apps/portal/src/main/java/com/careconnect/portal/PortalApplication.java
docker history portal:good
docker images | grep portal
```
**You should see:** on the second build the good Dockerfile prints `CACHED` for the dependency download and finishes fast. The bad one downloads every dependency again.
**Remember:**
- Docker caches each layer. A changed layer invalidates **every layer after it**. So: copy the rarely-changing file (`pom.xml`, `package.json`) first, install dependencies, then copy the source that changes all the time.
- `.dockerignore` keeps `target/`, `node_modules/` and `.git` out of the build context.

**Security best practices (the checklist):**
- Run as a **non-root** user (`USER 10001`).
- Use a **small, pinned base image** (`alpine:3.20`, `eclipse-temurin:21-jre-alpine`), never `latest`.
- Use **multi-stage builds** so compilers and build tools never reach the final image.
- **No secrets in layers.** Anything copied or set with ENV or ARG can be read from the image history. Use BuildKit secret mounts (Lab 5) or runtime secrets.
- Add a `HEALTHCHECK`, and scan images (`docker scout quickview` or Trivy; ECR scans on push).
- Prefer `COPY` over `ADD`. Handle SIGTERM so `docker stop` is fast (see `apps/booking/server.js`).

**Say in an interview:** "I order Dockerfile instructions from least to most frequently changing to maximise layer cache hits, use multi-stage builds to keep the runtime image small, run as non-root, pin base images, and keep secrets out of layers."

---

## Lab 5: BuildKit and buildx (Section 5)

**Do:**
```
docker buildx version
docker buildx create --name multi --driver docker-container --use
docker buildx inspect --bootstrap

# 1. Cache mount: the Maven download folder survives between builds
DOCKER_BUILDKIT=1 docker build -f docker/examples/Dockerfile.buildkit-cache -t portal:bk apps/portal
echo "// touch" >> apps/portal/src/main/java/com/careconnect/portal/PortalApplication.java
DOCKER_BUILDKIT=1 docker build -f docker/examples/Dockerfile.buildkit-cache -t portal:bk apps/portal
git checkout apps/portal/src/main/java/com/careconnect/portal/PortalApplication.java

# 2. Secret mount: available during one RUN, never stored in a layer
echo "s3cr3t-token" > /tmp/token.txt
docker build --secret id=api_token,src=/tmp/token.txt -f docker/examples/Dockerfile.buildkit-secret -t secret-demo docker/examples
docker history secret-demo
rm /tmp/token.txt

# 3. Multi-platform image (Intel and ARM) in one tag
docker buildx build --platform linux/amd64,linux/arm64 -f docker/Dockerfile.go-multiarch -t YOUR_DOCKERHUB_NAME/careconnect-doctors:multi --push apps/doctors
docker buildx imagetools inspect YOUR_DOCKERHUB_NAME/careconnect-doctors:multi
```
**You should see:** the second cache-mount build does not download dependencies again even though the source changed. The secret build prints `secret was available`, and `docker history` does not contain the token. The last command lists **two platforms** under one tag.
**Remember:**
- **BuildKit** is Docker's modern build engine: parallel stages, better caching, `--mount` for caches and secrets, and cleaner output. **buildx** is the CLI that exposes it, including multi-platform builds.
- A **manifest list** is one tag that points to one image per CPU type, so the same tag runs on an Intel server and an ARM (Graviton) server.
- `docker/Dockerfile.go-multiarch` cross-compiles with `FROM --platform=$BUILDPLATFORM` and `TARGETARCH`, so it does not need slow CPU emulation.
- Multi-stage builds for production: build tools stay in stage 1, only the result ships.

**Say in an interview:** "I use BuildKit cache mounts to speed up dependency downloads, secret mounts so credentials never land in a layer, and buildx to publish one tag for both amd64 and arm64, because Graviton nodes are cheaper."

---

## Lab 6: Terraform tools and the six examples (Section 6)

**Do:** (install the tools; skip any you already have)
```
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip && unzip -q awscliv2.zip && sudo ./aws/install && rm -rf aws awscliv2.zip
aws --version
# Terraform: see the install commands in RUN-IT Step 18.   kubectl: see RUN-IT Step 1.
terraform version
kubectl version --client
aws sts get-caller-identity       # only if you have real AWS credentials
```
Then run the examples in order. They point at a local AWS emulator by default, so `validate` always works and `plan` works when the emulator is running:
```
for d in 01-foundation 02-vpc 03-vpc-tfvars 04-remote-backend-bootstrap 05-vpc-remote-backend 06-vpc-module; do
  echo "== $d"; (cd terraform/examples/$d && terraform init -backend=false >/dev/null && terraform validate)
done
```
**You should see:** `Success! The configuration is valid.` six times.
**Remember (what each example teaches):**
| Example | Concept |
|---|---|
| `01-foundation` | Providers, resources, variables, outputs |
| `02-vpc` | A production-style VPC: public and private subnets, internet gateway, NAT gateway, route tables |
| `03-vpc-tfvars` | The same code for many environments with `dev.tfvars` and `prod.tfvars` |
| `04-remote-backend-bootstrap` | Creates the **S3 bucket** (state) and **DynamoDB table** (lock) |
| `05-vpc-remote-backend` | Uses that backend: state stored remotely, locked while someone applies |
| `06-vpc-module` | A reusable **module** called from the root code |

- The workflow is `init`, `validate`, `plan`, `apply`, `destroy`.
- **State** maps your code to real resources. Remote state with locking stops two people applying at once. Never commit state (it can contain secrets).
- Variable values are read from `-var`, `-var-file` (`*.tfvars`), `TF_VAR_*` environment variables, then defaults.
- Bootstrap problem: the bucket that holds the state must exist before the code that uses it, which is why `04` is a separate step.

**Say in an interview:** "I keep state in S3 with locking, one set of code for every environment through tfvars, and reusable pieces like the VPC in modules. Newer Terraform versions can also lock with S3 itself, but DynamoDB locking is what most teams still run."

*(Your screenshots skip part of Section 6, including its 7th demo. Send those pages and I will map them too.)*

---

## Lab 19: Helm release management (Section 19)

Needs the kind cluster from Steps 6 and 7.
**Do:**
```
helm lint charts/careconnect-service
helm template doctors charts/careconnect-service -f gitops/envs/dev/doctors.yaml | head -50
diff <(helm template doctors charts/careconnect-service -f gitops/envs/dev/doctors.yaml) \
     <(helm template doctors charts/careconnect-service -f gitops/envs/eks/doctors.yaml)

helm upgrade --install doctors charts/careconnect-service -n careconnect --create-namespace -f gitops/envs/dev/doctors.yaml
helm upgrade doctors charts/careconnect-service -n careconnect -f gitops/envs/dev/doctors.yaml --set replicaCount=3
helm history doctors -n careconnect
helm get values doctors -n careconnect
helm rollback doctors 1 -n careconnect
helm history doctors -n careconnect
kubectl get pods -n careconnect -l app.kubernetes.io/instance=doctors

helm package charts/careconnect-service
ls careconnect-service-*.tgz
```
Then bump `version: 0.3.0` to `0.4.0` in `charts/careconnect-service/Chart.yaml`, run `helm package charts/careconnect-service` again, and compare. Delete the `.tgz` files and undo the version bump when done.
**You should see:** the dev and EKS renders differ only in values (image, ingress, autoscaling). `helm history` shows revisions 1, 2, then 3 after the rollback. A rollback **creates a new revision** with the old content.
**Remember:**
- **Environment-specific values:** one chart, one values file per service per environment (`gitops/envs/dev`, `gitops/envs/eks`).
- **Chart versioning:** `version` changes when the **chart** changes. `appVersion` is the application's version (the default image tag). Package, publish and pin chart versions so releases are repeatable.
- **Release management:** every `helm upgrade` is a numbered revision, so `history` and `rollback` work. `--install` makes a command that works for first install and upgrades. `helm template` and `helm lint` check the result without touching a cluster.
- **One chart or one per microservice?** The course builds a chart per microservice. CareConnect uses **one reusable chart** for all five, because the services have the same shape and only the values differ, which means one place to fix a bug. The trade-off: a service with very different needs (for example a StatefulSet database) gets its own chart or a sub-chart. Know both answers.
- **The AWS data plane** (DynamoDB, RDS, ElastiCache, SQS) is owned by Terraform (`terraform/data-plane`), not Helm. Helm values carry the endpoints and table names to the services as environment variables and Secrets. Inside kind, the databases are plain manifests in `kubernetes/datastores`.

**Say in an interview:** "One Helm chart, values per service and per environment, versioned chart and app, and every release is a numbered revision I can roll back. In GitOps, ArgoCD renders the same chart, so the rollback is a Git revert."

---

# AWS LABS (real AWS, costs money, clean up the same day)

Before you start: set an AWS **Budget alert** and do Steps 20 and 21 of RUN-IT first.

## Lab 15-16: ExternalDNS, Route 53 and HTTPS with ACM (Sections 15 and 16)

Needs a domain. Use one registered in Route 53, or a subdomain (for example `careconnect.yourdomain.com`) that you delegate to Route 53. The hosted zone costs about $0.50 a month.
**Do:**
```
export DOMAIN=careconnect.example.com        # EDIT

# 1. Hosted zone
cd terraform/dns-and-tls/domain-and-certificate
terraform init
terraform apply -var domain_name=$DOMAIN
terraform output name_servers
cd ../../..
```
If the domain is not registered in Route 53, put the 4 name servers at your registrar (or add NS records for the subdomain at its parent zone). Wait until this answers with those servers: `dig NS $DOMAIN +short`.
```
# 2. Certificate (waits until ACM sees the DNS validation records, up to about 45 minutes)
cd terraform/dns-and-tls/domain-and-certificate
terraform apply -var domain_name=$DOMAIN -var create_certificate=true
CERT_ARN=$(terraform output -raw certificate_arn)
ZONE_ID=$(terraform output -raw zone_id)
cd ../../..

# 3. ExternalDNS (Pod Identity role limited to this one zone)
cd terraform/dns-and-tls/external-dns
terraform init
terraform apply -var domain_name=$DOMAIN -var zone_id=$ZONE_ID
cd ../../..
kubectl get pods -n kube-system | grep external-dns

# 4. Put the portal on your domain over HTTPS
sed -i "s|<DOMAIN>|$DOMAIN|; s|<CERT_ARN>|$CERT_ARN|" terraform/dns-and-tls/domain-and-certificate/values-https.yaml
helm upgrade --install portal charts/careconnect-service -n careconnect \
  -f gitops/envs/eks/portal.yaml -f terraform/dns-and-tls/domain-and-certificate/values-https.yaml
kubectl get ingress -n careconnect
kubectl logs -n kube-system deploy/external-dns --tail=20
dig +short portal.$DOMAIN
curl -I http://portal.$DOMAIN/health
curl -I https://portal.$DOMAIN/health
```
**You should see:** ExternalDNS logs say it created records for `portal.<domain>`, `dig` returns the load balancer, the `http://` request answers `301` to `https://`, and the `https://` request answers `200` with a valid certificate.
**Screenshot:** `docs/screenshots/20-https-domain.png` (browser padlock on `https://portal.<domain>`).
**Remember:**
- **ExternalDNS** watches Ingresses and Services and writes the matching records in Route 53 (plus a **TXT ownership record**, `txtOwnerId`, so it only touches records it created).
- `domainFilters` limits it to your domain. **Never leave it empty.** `policy: sync` also deletes records when the Ingress is deleted. `upsert-only` never deletes (safer in production).
- **ACM** issues the certificate. **DNS validation** proves ownership with a CNAME record that Terraform creates. The wildcard (`*.domain`) covers every service.
- The **AWS Load Balancer Controller** builds the ALB from the Ingress annotations (`certificate-arn`, `listen-ports`, `ssl-redirect`). **TLS ends at the ALB.** Ingress, ALB controller and ExternalDNS work together.

**Cleanup:**
```
helm uninstall portal -n careconnect          # ExternalDNS removes the portal record (wait a minute)
(cd terraform/dns-and-tls/external-dns && terraform destroy -var domain_name=$DOMAIN -var zone_id=$ZONE_ID)
(cd terraform/dns-and-tls/domain-and-certificate && terraform destroy -var domain_name=$DOMAIN -var create_certificate=true)
git checkout terraform/dns-and-tls/domain-and-certificate/values-https.yaml
```
**Say in an interview:** "I deploy an Ingress with a hostname and ExternalDNS creates the Route 53 record, ACM issues a wildcard certificate through DNS validation, and the ALB terminates TLS and redirects HTTP to HTTPS. No manual DNS or certificate steps."

---

## Lab 18: HPA and Karpenter together (Section 18)

Needs Steps 20 to 24 (EKS and Karpenter). This is the "HPA scales pods, Karpenter scales nodes" demo.
**Do:**
```
# 1. Metrics Server (HPA reads CPU and memory from it)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl top nodes                                   # works after about a minute

# 2. The demo app, with real CPU requests, and the CPU + memory HPA
kubectl apply -f kubernetes/hpa/01-php-apache.yaml
kubectl set resources deployment php-apache -n careconnect --requests=cpu=500m,memory=64Mi --limits=cpu=500m,memory=128Mi
kubectl apply -f kubernetes/hpa/03-hpa-cpu-memory-behavior.yaml

# 3. Karpenter pools ready (skip lines already applied in Steps 23 and 24)
kubectl apply -f karpenter/manifests/ec2nodeclass.yaml -f karpenter/manifests/nodepool-spot.yaml -f karpenter/manifests/nodepool-ondemand.yaml

# 4. Load: three load generators
for i in 1 2 3; do
  kubectl run load-$i -n careconnect --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://php-apache >/dev/null; done"
done
```
Watch in separate terminals:
```
kubectl get hpa -n careconnect -w
kubectl get pods -n careconnect -l app=php-apache -w
kubectl get nodeclaims -w
```
Stop the load and watch it shrink:
```
kubectl delete pod load-1 load-2 load-3 -n careconnect
```
**You should see:** CPU rises, the HPA adds pods (up to 10), some pods sit `Pending` because the cluster is full, **Karpenter launches a node**, the pods start. After you stop the load the HPA removes pods slowly (the scale-down settings in file `03`), and Karpenter later **consolidates** the extra node away.
**Screenshot:** `docs/screenshots/21-hpa-karpenter.png` (HPA, Pending pods and a new nodeclaim in one view).
**Remember:**
- **HPA formula:** desired pods = ceil(current pods x current metric / target metric). With several metrics (CPU and memory) it uses the one that asks for **more** pods.
- Utilisation is measured **against the pod's request**, so a pod without requests cannot be autoscaled.
- `<unknown>` in `kubectl get hpa` means Metrics Server is missing or the pod has no requests.
- `behavior` controls speed: here scale-up may double every 15 s, scale-down waits 2 minutes and removes one pod per 30 s, which avoids flapping.
- The link between the two: **HPA creates pods, pods that do not fit become Pending, Karpenter reacts to Pending pods.** The real services get the same HPA from the chart (`autoscaling.enabled: true` in `gitops/envs/eks`).

**Cleanup:**
```
kubectl delete -f kubernetes/hpa/03-hpa-cpu-memory-behavior.yaml -f kubernetes/hpa/01-php-apache.yaml
```
**Say in an interview:** "HPA adds pods based on CPU and memory against their requests. When there is no room, the pods go Pending and Karpenter adds a right-sized node. When load drops, HPA removes pods and Karpenter consolidates the nodes."

---

## Lab 20: OpenTelemetry on EKS (Section 20)

The free version (local Jaeger) is Step 27. This lab is the AWS version: ADOT, X-Ray, CloudWatch Logs, Managed Prometheus and Grafana.
The demo apps use the same names as the Helm releases, so remove those first:
```
helm uninstall appointments booking -n careconnect
```
(If ArgoCD already manages them from Lab 21, do this lab first, or delete the ArgoCD applications for those two.)

**Demo 1: EKS environment with ADOT**
**Do:**
```
cd observability
terraform init
terraform apply
terraform output
cd ..
aws eks describe-addon --cluster-name careconnect-eks --addon-name adot --query addon.status
kubectl get pods -A | grep -i -E "cert-manager|opentelemetry"
```
**You should see:** the add-on `ACTIVE`, cert-manager pods and the OpenTelemetry operator pod `Running`, and an Amazon Managed Prometheus workspace id in the outputs.
**Remember:** **ADOT** is AWS's supported build of the OpenTelemetry Collector. The **operator** manages collectors and injects instrumentation. It needs **cert-manager** for its webhooks. The collector gets AWS access through **Pod Identity** (no keys).

**Demo 2: traces with X-Ray (auto-instrumentation, sampling, filtering)**
**Do:**
```
sed -i "s|<AMP_REMOTE_WRITE_URL>|$(terraform -chdir=observability output -raw amp_remote_write_url)|" observability/manifests/collector.yaml
kubectl apply -f observability/manifests/collector.yaml -f observability/manifests/instrumentation.yaml
kubectl apply -f observability/manifests/demo-apps.yaml
kubectl get pods -n careconnect
kubectl port-forward svc/booking -n careconnect 8083:80 &
for i in $(seq 1 60); do curl -s localhost:8083/ >/dev/null; curl -s localhost:8083/health >/dev/null; done
```
Open the AWS console: **CloudWatch, Application Signals or X-Ray traces, Service map** (region us-east-1). Find `booking` calling `appointments`.
**You should see:** a service map with two nodes and an arrow, and traces for `/` that show both services. There are **no traces for `/health`**.
**Screenshot:** `docs/screenshots/22-xray-service-map.png`.
**Remember:**
- **Auto-instrumentation:** the annotation `instrumentation.opentelemetry.io/inject-java` (or `inject-nodejs`) makes the operator inject an agent. No code change. The apps' own code never mentions OpenTelemetry.
- **Filtering:** the `filter/health` processor drops health-probe spans before export. Probes are most of the traffic, which is where the course's large cost reduction comes from.
- **Sampling:** the Instrumentation sets `argument: "1"` (keep 100%) for learning. In production use `0.05` to `0.25`. Change it, `kubectl apply` it, then `kubectl rollout restart deployment booking appointments -n careconnect`.
- **Trace analysis:** the service map shows who calls whom, errors and latency. A trace shows where one request spent its time.

**Demo 3: logs with CloudWatch**
**Do:**
```
terraform -chdir=observability apply -var enable_container_logs=true
aws logs describe-log-groups --log-group-name-prefix /aws/containerinsights/careconnect-eks --query "logGroups[].logGroupName"
```
In the console open **CloudWatch, Logs Insights**, choose the `.../application` log group, and run:
```
fields @timestamp, @message | sort @timestamp desc | limit 20
```
```
fields @timestamp, @message | filter @message like /booking/ | stats count(*) as requests by bin(1m)
```
```
fields @timestamp, @message | filter @message like /error/ or @message like /ERROR/ | sort @timestamp desc
```
**You should see:** the JSON log lines that `booking` prints, and a count per minute. (Field names such as `kubernetes.pod_name` can differ by add-on version: click a log event to see the real ones.)
**Remember:** the add-on runs Fluent Bit on every node and ships container stdout to CloudWatch Logs. **Logs Insights** is the query language: `fields`, `filter`, `stats`, `sort`, `limit`. Logs cost per GB ingested, so this is optional (`enable_container_logs` defaults to false).

**Demo 4: metrics with Managed Prometheus (AMP) and Managed Grafana (AMG)**
The collector already turns spans into **rate, error and duration metrics** (`spanmetrics`) and writes them to AMP.
**Do:** (Grafana needs IAM Identity Center enabled in your account and costs per user)
```
terraform -chdir=observability apply -var create_grafana=true
terraform -chdir=observability output grafana_endpoint
```
In Grafana: add **Amazon Managed Service for Prometheus** as a data source, open **Explore**, search for the span metrics (names start with `calls` and `duration`, exact names depend on the collector version), and build a panel such as the request rate per service.
**You should see:** a graph that moves when you run the `curl` loop again.
**Remember:** **AMP** stores Prometheus metrics (queried with PromQL). **AMG** draws dashboards on top of AMP, CloudWatch and X-Ray. The three pillars: **traces** (where), **logs** (what happened), **metrics** (trends). The minimal CareConnect services do not emit custom business metrics. In a real application you would add them (for example a counter of bookings created) with the OpenTelemetry SDK, and they would arrive in AMP through the same pipeline. Say this honestly if asked.

**Cleanup:**
```
kill %1 2>/dev/null
kubectl delete -f observability/manifests/
terraform -chdir=observability destroy -var enable_container_logs=true -var create_grafana=true
for g in $(aws logs describe-log-groups --log-group-name-prefix /aws/containerinsights/careconnect-eks --query "logGroups[].logGroupName" --output text); do aws logs delete-log-group --log-group-name $g; done
git checkout observability/manifests/collector.yaml
```
**Say in an interview:** "Collector pipeline: receivers take OTLP, processors filter health checks and batch, exporters send traces to X-Ray and metrics to Prometheus. The operator injects agents into Java and Node pods, so teams get traces without touching code, and filtering plus sampling control the cost."

---

## Lab 21: CI with ECR and OIDC, then ArgoCD on EKS (Section 21)

The main path (Steps 12 to 17) does this with Docker Hub on kind. This lab is the course version: **ECR, OIDC (no access keys) and ArgoCD on EKS.**

**Part A: OIDC role and five ECR repositories**
**Do:**
```
cd terraform/ci-oidc
terraform init
terraform apply -var github_repo=YOUR_GITHUB_USER/careconnect-devops-portfolio
terraform output
gh secret set AWS_ROLE_ARN --body "$(terraform output -raw role_arn)"
cd ../..
git mv .github/workflows/release.yml ci/release-dockerhub.yml.example
cp ci/ecr-oidc-release.yml.example .github/workflows/release-ecr.yml
git add -A && git commit -m "ci: release to ECR with OIDC" && git push
```
(If `apply` says the OIDC provider already exists, add `-var create_oidc_provider=false`.)
**You should see:** a role ARN, a registry name, and five repositories (`aws ecr describe-repositories --query "repositories[].repositoryName"`).
**Remember:**
- **OIDC:** GitHub gives each workflow run a short-lived signed token. AWS trusts GitHub's identity provider and exchanges that token for temporary credentials of one role. **No access keys exist anywhere to leak.**
- The role's trust policy limits who can assume it: this repository only (`sub` claim), and only runs from a version tag.
- ECR tags are **immutable** here and images are scanned on push. The workflow needs `id-token: write` permission to request the token.
- Only one release workflow may be active (both would run on the same tag and both would commit), which is why the Docker Hub one is moved aside.

**Part B: ArgoCD on EKS (GitOps)**
This switches your repository from "kind mode" to "EKS mode" (EKS values, no local datastores). To go back to kind later, `git revert` this commit.
**Do:**
```
sed -i 's|<your-user>|YOUR_GITHUB_USER|g' gitops/argocd/root-app.yaml gitops/apps/services.yaml
sed -i 's|envs/dev/|envs/eks/|' gitops/apps/services.yaml
git rm gitops/apps/datastores.yaml        # EKS uses the AWS data plane instead
git commit -am "gitops: EKS environment" && git push

helm uninstall portal appointments billing doctors booking -n careconnect
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
kubectl apply -f gitops/argocd/root-app.yaml
kubectl get applications -n argocd -w
```
Open the ArgoCD page as in Step 14 (`kubectl port-forward svc/argocd-server -n argocd 8443:443`).
**You should see:** ArgoCD, the `root` app and five `careconnect-*` apps, all **Synced** and **Healthy**.
**Remember:**
- **ArgoCD components:** API server (UI and CLI), repo server (clones Git and renders Helm), application controller (compares Git to the cluster and syncs), plus Redis and Dex (login).
- **Auto-sync** applies Git changes. **self-heal** reverts manual changes. **prune** deletes what was removed from Git.
- The `root` app creates the **ApplicationSet**, which generates one Application per service from a list (the "app of apps" pattern).

**Part C: the complete flow, then rollback**
**Do:**
```
git tag v1.1.0 && git push origin v1.1.0
gh run watch
git pull --rebase
kubectl get applications -n argocd
kubectl get pods -n careconnect -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' | sort -u
kubectl scale deployment portal -n careconnect --replicas=5      # a manual change: ArgoCD reverts it
git revert HEAD --no-edit && git push                             # rollback = revert the bot's deploy commit
```
**You should see:** the Actions run builds and pushes five images to ECR, a bot commit `ci: deploy v1.1.0 to eks`, ArgoCD rolling the pods to `…dkr.ecr…/careconnect/<service>:1.1.0`, the manual scale-up undone within a minute (self-heal), and the revert returning the previous version.
**Screenshot:** `docs/screenshots/23-ecr-images.png` and `docs/screenshots/24-argocd-eks.png`.
**Remember:** **code commit, build, push to ECR, update the Helm values in Git, ArgoCD deploys.** CI never touches the cluster. **Semantic versioning with Git tags:** `v1.1.0` becomes image tags `1.1.0` and a short commit id (`type=sha`), so every deployed version traces back to a commit. **Rollback strategies:** `git revert` (the safe one, history stays honest), `argocd app rollback` (temporary, Git is not changed, so with auto-sync on it is undone), or `helm rollback` (not for ArgoCD-managed releases).

**Cleanup:**
```
kubectl delete applicationset careconnect-services -n argocd
kubectl delete applications --all -n argocd
kubectl delete namespace argocd
terraform -chdir=terraform/ci-oidc destroy -var github_repo=YOUR_GITHUB_USER/careconnect-devops-portfolio
```
(Delete the ApplicationSet before the Applications, or it recreates them.)
**Say in an interview:** "GitHub Actions authenticates to AWS with OIDC, so there are no stored keys. A version tag builds and pushes immutable images to ECR, the pipeline commits the new tag into the Helm values, and ArgoCD syncs it. Rollback is a git revert."

---

# One screenshot list for the labs
| File | Lab | Shows |
|---|---|---|
| 20-https-domain.png | 15-16 | Padlock on `https://portal.<domain>` |
| 21-hpa-karpenter.png | 18 | HPA, Pending pods and a new nodeclaim |
| 22-xray-service-map.png | 20 | `booking` to `appointments` service map |
| 23-ecr-images.png | 21 | Five ECR repositories with the new tag |
| 24-argocd-eks.png | 21 | ArgoCD on EKS, all Synced and Healthy |
