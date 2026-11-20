# Interview questions and short answers, by course section

Say the answer in your own words, and tie it to something you actually ran in CareConnect. If you did not run a part, say "I validated the code" instead.

## Docker (Sections 2 to 5)
| Question | Answer |
|---|---|
| Image vs container? | An image is the read-only, layered package. A container is a running instance of it with a writable layer on top. |
| `CMD` vs `ENTRYPOINT`? | ENTRYPOINT is the program that always runs. CMD supplies its default arguments, which `docker run <image> args` replaces. |
| `COPY` vs `ADD`? | Use COPY. ADD also extracts local tar files and downloads URLs, which is easy to misuse. |
| `ARG` vs `ENV`? | ARG exists only at build time. ENV is also present in the running container and can be overridden with `-e`. |
| Does `EXPOSE` publish a port? | No. It is documentation. `-p host:container` publishes it. |
| How do you make images small and safe? | Multi-stage builds, a minimal pinned base, a non-root user, no secrets in layers, `.dockerignore`. In CareConnect the Go image is just Alpine plus one static binary, and runs as uid 10001. |
| How does layer caching work? | Each instruction is a layer. If a layer changes, every later layer is rebuilt. So copy dependency files first, install, then copy the source. |
| Why a `HEALTHCHECK`? | So Docker (and Compose `depends_on: service_healthy`) knows when the app is really ready. Kubernetes uses probes instead. |
| `docker stop` vs `docker kill`? | stop sends SIGTERM and waits (10 s) then SIGKILL. kill sends SIGKILL right away. Apps must handle SIGTERM (see `booking/server.js`). |
| Volumes vs bind mounts? | Named volumes are managed by Docker and survive `down`. Bind mounts map a host path. Databases use named volumes. |
| How does Compose control start order? | `depends_on` with `condition: service_healthy` or `service_completed_successfully` (the one-shot `db-migrate` job). Plain `depends_on` only waits for the container to start. |
| Compose networks? | `frontend` and `backend` networks: the gateway cannot reach the databases directly. Services reach each other by service name. |
| Profiles, links, aliases? | Profiles start optional services only when asked (`--profile tools`). Links are legacy (names work on user-defined networks anyway). Aliases give a service extra DNS names (`db` for postgres). |
| What is BuildKit? | Docker's modern build engine: parallel stages, better cache, and `RUN --mount` for caches and secrets. buildx is its CLI. |
| How do you build for Intel and ARM? | `docker buildx build --platform linux/amd64,linux/arm64 --push`. One tag becomes a manifest list. Cross-compile with `BUILDPLATFORM` and `TARGETARCH` instead of emulating. |
| How do you pass a secret at build time safely? | BuildKit `--secret` mount. It is visible for one RUN and never stored in a layer. ARG and ENV are readable from the image. |

## Terraform (Section 6, and the AWS sections)
| Question | Answer |
|---|---|
| What is Terraform state? | The mapping between your code and the real resources. It can contain secrets, so it lives in a private, encrypted remote backend and is never committed. |
| Why remote state with locking? | Teams share one source of truth and cannot apply at the same time. We use an S3 bucket plus a DynamoDB lock table (newer Terraform versions can lock with S3 itself). |
| How do you reuse code across environments? | Variables and `*.tfvars` files (`dev.tfvars`, `prod.tfvars`), and modules (`terraform/modules/vpc`). |
| `count` vs `for_each`? | `count` is an index (removing item 0 shifts the rest). `for_each` uses stable keys (the five ECR repositories use it). |
| What is drift, and how do you handle it? | Real infrastructure changed outside Terraform. `terraform plan` shows it. Fix by applying, or `terraform import` to adopt a resource. |
| `plan` vs `apply` vs `destroy`? | Preview, build, remove. Always read the plan. |
| Public vs private subnets, NAT? | Public subnets route to the internet gateway. Private subnets have no inbound path. A NAT gateway lets private servers go out for updates. Databases and nodes live in private subnets. |
| How do you avoid secrets in Terraform? | RDS `manage_master_user_password` stores the password in Secrets Manager. Pods get AWS access with Pod Identity (no keys). |
| Why split the Terraform into several stacks? | By change frequency and blast radius: cluster, add-ons, data plane. A mistake in one cannot destroy another. |

## EKS, add-ons and data plane (Sections 14 to 16)
| Question | Answer |
|---|---|
| Pod Identity vs IRSA? | Both give pods IAM roles. Pod Identity maps a ServiceAccount to a role through an EKS association and an agent, with no OIDC provider setup per cluster, and roles are reusable across clusters. |
| How does an Ingress become a load balancer on EKS? | The AWS Load Balancer Controller watches Ingresses and creates an ALB, listeners and target groups from the annotations. `target-type: ip` sends traffic straight to pods. |
| How do 5 services share one ALB? | The annotation `group.name: careconnect` groups the Ingresses onto one load balancer, routed by path or host. This saves money. |
| What does ExternalDNS do? | Watches Ingresses and Services and creates the matching Route 53 records, with a TXT ownership record. `domainFilters` limits it to your domain, `sync` also deletes records. |
| How does ACM validate a certificate? | DNS validation: ACM gives a CNAME that Terraform creates in Route 53. The wildcard certificate covers every subdomain. TLS ends at the ALB. |
| Why is the database not in the cluster on AWS? | Managed services (RDS, ElastiCache, DynamoDB, SQS) give backups, patching and failover. Inside kind we use plain manifests only for the practice setup. |

## Karpenter (Section 17)
| Question | Answer |
|---|---|
| Karpenter vs Cluster Autoscaler? | Karpenter launches a fitting instance directly for Pending pods and consolidates nodes. The Cluster Autoscaler resizes pre-defined node groups. |
| NodePool vs EC2NodeClass? | NodePool: what and how much (types, Spot or On-Demand, limits, consolidation). EC2NodeClass: the AWS details (AMI, subnets, security group, disk, role). |
| What is consolidation? | Removing empty or underused nodes and repacking pods so you pay for less. |
| How is Spot interruption handled? | EC2 sends a 2-minute warning, EventBridge puts it into SQS, Karpenter drains the node and starts a replacement. PodDisruptionBudgets keep enough replicas serving. |
| Is Spot safe in production? | For stateless services with several replicas, zone spread, a PDB, diversified instance types and an On-Demand fallback. |
| Why does Karpenter itself run on a managed node group? | It cannot create the node it is running on. |

## HPA (Section 18)
| Question | Answer |
|---|---|
| How does HPA decide? | desired = ceil(current replicas x current metric / target). With CPU and memory it takes the larger result. |
| Why must pods have requests? | Utilisation is a percentage of the request. No request, no percentage. |
| What do you need installed? | Metrics Server. Without it HPA shows `<unknown>`. |
| How do you stop flapping? | The `behavior` block: a stabilisation window and rate limits for scaling down. |
| HPA vs Karpenter? | HPA scales pods. Karpenter scales nodes. Pods that do not fit are Pending, and that is Karpenter's trigger. |
| HPA vs VPA vs KEDA? | HPA: more replicas. VPA: bigger requests. KEDA: scale on events such as queue length, even to zero. |

## Helm (Section 19)
| Question | Answer |
|---|---|
| Why Helm? | Templates plus values give one package deployed many times and many ways, with versions, history and rollback. |
| Chart `version` vs `appVersion`? | `version` is the chart's own version. `appVersion` is the application version (our default image tag). |
| How do you handle environments? | One values file per environment: `gitops/envs/dev`, `gitops/envs/eks`. |
| How do you roll back? | `helm rollback <release> <revision>` creates a new revision. Under ArgoCD you revert in Git instead. |
| One chart or one chart per service? | Course: one per service. CareConnect: one reusable chart, because the services have the same shape. Split when a service differs a lot. |
| Useful commands? | `helm lint`, `helm template`, `helm upgrade --install`, `helm history`, `helm get values`, `helm package`. |

## Observability (Section 20)
| Question | Answer |
|---|---|
| Three pillars? | Traces (where time went), logs (what happened), metrics (trends). |
| What is the OpenTelemetry Collector? | A pipeline: receivers (OTLP), processors (filter, batch, memory limit), exporters (X-Ray, Prometheus, CloudWatch). |
| What is ADOT? | AWS Distro for OpenTelemetry, AWS's supported build, installed as an EKS add-on with an operator. |
| How do you trace without changing code? | The operator injects an agent when a pod has `instrumentation.opentelemetry.io/inject-java` or `inject-nodejs`. |
| How do you control tracing cost? | Filter noise (health checks) in the collector, and sample (keep 5 to 25% in production). |
| Head vs tail sampling? | Head: decided at the start of the trace (cheap, blind to errors). Tail: decided after the trace finishes (can keep all errors, needs more memory). |
| Where do logs go? | A CloudWatch agent (Fluent Bit) ships container stdout to CloudWatch Logs, queried with Logs Insights. |
| AMP vs AMG? | Amazon Managed Prometheus stores metrics. Amazon Managed Grafana draws dashboards on them (and CloudWatch, X-Ray). |

## CI/CD and GitOps (Section 21)
| Question | Answer |
|---|---|
| Why OIDC instead of access keys? | GitHub gives each run a short-lived token and AWS exchanges it for temporary credentials. Nothing long-lived to leak or rotate. The trust policy pins the repository and tag pattern. |
| Why immutable ECR tags? | A version tag can never be overwritten, so what is deployed is always what was built. |
| Semantic versioning with Git tags? | `v1.2.3` triggers the release, and the image gets tags `1.2.3` and the commit sha. Every running version traces to a commit. |
| Push vs pull deployment? | Push: the pipeline holds cluster credentials. Pull (GitOps): the cluster pulls from Git, so CI holds none. |
| ArgoCD components? | API server, repo server (renders Helm), application controller (compares and syncs), Redis, Dex. |
| Auto-sync, self-heal, prune? | Auto-sync applies Git changes. Self-heal reverts manual changes. Prune deletes what was removed from Git. |
| What is an ApplicationSet? | A template that generates one Application per list item: five services from one file. |
| How do you roll back? | `git revert` the deploy commit. ArgoCD syncs the old version, and history stays honest. |
| What happens on a bad release? | Rolling update and readiness probes keep old pods serving until new ones are ready, so there is no downtime. |
| What would you add next? | Image scanning in CI, network policies, external secrets, progressive delivery, SLO alerts. |
