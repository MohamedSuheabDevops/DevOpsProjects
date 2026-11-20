# Course map: every section of the course, and where it lives in CareConnect

Use this as your checklist. **Run** = a guided step you can do. **Read** = code in the repository that you should be able to explain. [RUN-IT.md](RUN-IT.md) is the main path, [LABS.md](LABS.md) has the deep-dive labs, and [INTERVIEW-QA.md](INTERVIEW-QA.md) has the questions.

## Section 1: the application
The course builds a **retail store**. CareConnect is the same architecture with clinic names, so you can tell the same story.

| Course service | CareConnect service | Language | Data store |
|---|---|---|---|
| UI | `portal` | Java (Spring Boot) | none |
| Carts | `appointments` | Java (Spring Boot) | DynamoDB |
| Catalog | `doctors` | Go | MySQL / MariaDB (Amazon RDS MySQL on AWS) |
| Orders | `billing` | Java (Spring Boot) | PostgreSQL (Amazon RDS on AWS) + SQS |
| Checkout | `booking` | Node.js | Redis (ElastiCache on AWS) + SQS |

The services are intentionally minimal. The platform around them is the project.

## Sections 2 to 21

| Section | Course topic | In CareConnect | Run it | Notes |
|---|---|---|---|---|
| 2 | Docker commands, Docker on EC2 | `apps/*/Dockerfile` | LABS: **Lab 2** | |
| 3 | Dockerfile mastery: every instruction, security, multi-stage, layer caching | `docker/examples/all-instructions/`, `apps/*/Dockerfile`, `docker/examples/Dockerfile.java-bad-cache` | RUN-IT Step 3, LABS: **Lab 3** | |
| 4 | Docker Compose: volumes, networks, health checks, scaling, `depends_on`, profiles, links, aliases | `compose/compose.yaml` (all of these are in the file, each commented) | RUN-IT Steps 4, 5 | |
| 5 | BuildKit, buildx, multi-platform, multi-stage | `docker/Dockerfile.go-multiarch`, `docker/examples/Dockerfile.buildkit-*` | LABS: **Lab 5** | |
| 6 | Terraform basics: tools, foundation, VPC, tfvars, remote backend (S3 + DynamoDB), VPC module | `terraform/examples/01` to `06`, `terraform/modules/vpc` | RUN-IT Steps 18, 19, LABS: **Lab 6** | Your screenshots skip part of this section (demos 6 and 7). Send them and I will map them. |
| 7 to 13 | Not visible in your screenshots | EKS, Kubernetes fundamentals, storage, secrets, ingress and similar are in `terraform/eks-cluster`, `terraform/eks-addons`, `kubernetes/` | RUN-IT Steps 6 to 11, 20, 21 | Send the screenshots for these sections and I will map them exactly. |
| 14 | Microservices with the AWS data plane (DynamoDB, RDS, ElastiCache, SQS) | `terraform/data-plane/`, `gitops/envs/eks/*.yaml` | Read the code. To run it: `terraform apply` in `terraform/data-plane` | Costs money (RDS, ElastiCache) |
| 15 | ExternalDNS with Terraform, Route 53, custom domain, ALB controller | `terraform/dns-and-tls/external-dns/` | LABS: **Lab 15-16** | Needs a domain |
| 16 | Production DNS and HTTPS: ACM certificates, custom domains | `terraform/dns-and-tls/domain-and-certificate/`, `kubernetes/ingress/eks-alb/ingress-https.yaml` | LABS: **Lab 15-16** | Needs a domain |
| 17 | Karpenter: install, On-Demand, Spot, Spot interruption handling | `karpenter/` | RUN-IT Steps 22 to 25 | AWS |
| 18 | HPA: Metrics Server, CPU and memory autoscaling, HPA + Karpenter | `kubernetes/hpa/`, chart `hpa.yaml` | RUN-IT "Extras" (local HPA), LABS: **Lab 18** | AWS for the Karpenter part |
| 19 | Helm: charts, values per environment, versioning, release management | `charts/careconnect-service/`, `gitops/envs/{dev,eks}` | RUN-IT Step 8, LABS: **Lab 19** | **Differs from the course:** one reusable chart for all five services, not one chart per service. Explained in Lab 19. |
| 20 | OpenTelemetry: ADOT, X-Ray traces, auto-instrumentation, sampling and filtering, CloudWatch logs and Insights, AMP and AMG | `observability/` | RUN-IT Step 27 (free, local), LABS: **Lab 20** | AWS. Custom business KPI metrics are not emitted by the minimal services |
| 21 | CI/CD: GitHub Actions + ECR + OIDC, ArgoCD on EKS, auto-sync and self-heal, end-to-end flow, rollback | `.github/workflows/`, `ci/ecr-oidc-release.yml.example`, `terraform/ci-oidc/`, `gitops/` | RUN-IT Steps 12 to 17 (Docker Hub + kind), LABS: **Lab 21** (ECR + OIDC + EKS) | |

## What is run and what is only read
Be exact about this in an interview. Mark each line true or false for yourself:
- [ ] Docker, Compose and BuildKit labs run on my machine
- [ ] Kubernetes and Helm run on kind
- [ ] GitOps and CI/CD run with Docker Hub on kind (RUN-IT Steps 12 to 17)
- [ ] Terraform examples validated (and planned against the emulator)
- [ ] Real AWS: EKS cluster, load balancer, Karpenter, DNS/HTTPS, observability, ECR + OIDC (mark each one separately)

## Course topics this project deliberately keeps small
- **Business logic:** the services only answer `/health` and report the container that served them.
- **Custom application metrics (business KPIs):** the platform pipeline for metrics exists (OpenTelemetry to Managed Prometheus), the services do not emit custom ones.
- **Separate charts per microservice:** replaced by one reusable chart (see Lab 19 for the trade-off).
