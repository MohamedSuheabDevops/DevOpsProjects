# Show It: demo script and concepts to remember

Use this when you present the project (interview, call, or recording). For more questions and answers by topic, see [INTERVIEW-QA.md](INTERVIEW-QA.md). Do the steps in [RUN-IT.md](RUN-IT.md) at least once first, so everything on screen is familiar.

## Before you present (5 minutes)
- [ ] The kind cluster and ArgoCD are running, all applications Synced and Healthy (`kubectl get applications -n argocd`).
- [ ] Two browser tabs open: the GitHub repository (Actions tab) and the ArgoCD page.
- [ ] One terminal in the repository root, font size large.
- [ ] You know your two scope sentences (bottom of this page).

## The 6-minute demo

| Time | Show | Say |
|---|---|---|
| 0:00 | README diagram | "CareConnect is a clinic booking platform with five microservices in Java, Go and Node. The services are minimal on purpose. What I built is the platform: containers, Terraform, Kubernetes, GitOps and CI/CD." |
| 0:45 | `apps/doctors/Dockerfile` | "Multi-stage build: compile in one stage, ship a tiny runtime image. Runs as a non-root user and has a health check." |
| 1:15 | `docker compose ps` in `compose/` | "Locally the whole stack runs in Compose: separate frontend and backend networks, health checks, and startup order so a service waits for its database." |
| 2:00 | `charts/careconnect-service` and a values file in `gitops/envs/dev` | "One Helm chart deploys all five services. Each service's values file says which image and settings it uses." |
| 2:30 | ArgoCD page | "ArgoCD runs in the cluster and watches this Git repository. Everything you see here was deployed from Git, not by hand." |
| 3:00 | `git tag v1.0.1 && git push origin v1.0.1` and the Actions tab | "A version tag starts the pipeline: build the five images, push them, then commit the new version into Git. The pipeline never touches the cluster." |
| 4:00 | The bot commit, then ArgoCD updating | "ArgoCD sees the commit and rolls the pods out with a rolling update, so there is no downtime." |
| 4:45 | Edit a tag to something that does not exist, push, show the pod failing, then `git revert` | "A bad release does not take the service down, because old pods keep serving until new ones are ready. Rollback is a Git revert, so the history stays honest." |
| 5:30 | `terraform/eks-cluster/eks.tf` | "The cloud side is Terraform: the network, the EKS cluster, IAM roles and add-ons, split into separate stacks. I validated it, and ran it on AWS in a practice account." (Say only what is true.) |
| 6:00 | Finish | "Everything is in the repository with a step-by-step guide." |

## Concepts to remember (one line each)

| Concept | Remember |
|---|---|
| Image and container | An image is the frozen package, a container is a running copy. |
| Multi-stage build | Build in one stage, ship only the result: smaller and safer. |
| Non-root | If the app is attacked, it cannot act as root. |
| Health check | `/health` tells Docker and Kubernetes whether to send traffic or wait. |
| Compose networks | Frontend and backend networks keep databases out of reach of the gateway. |
| Kubernetes | You say what you want; it keeps reality matching, forever. |
| Deployment | Keeps N pods running and replaces failed ones. |
| Readiness probe | Decides who receives traffic, so a broken pod gets none. |
| Rolling update | New pods must be ready before old ones are removed: no downtime. |
| Service | A stable address in front of pods that come and go. |
| StatefulSet and PVC | A database pod keeps its name and its disk, so data survives. |
| Helm | One template, many deployments; values per service. |
| GitOps | Git is the control panel; a tool in the cluster makes reality match it. |
| Pull, not push | The cluster pulls from Git, so CI needs no cluster credentials. |
| CI/CD | CI builds and tests, CD delivers. Here CI commits the new version to Git and ArgoCD delivers it. |
| Versioned tags | `v1.0.1`, never `latest`, so you know what runs and can go back. |
| Rollback | `git revert` is the safe rollback. Live edits get undone by ArgoCD. |
| Terraform | Cloud resources written as files; `plan` previews, `apply` builds. |
| State | Terraform's notebook of what exists. It can hold secrets, never commit it. |
| VPC | A private network: public subnets, private subnets, NAT for outbound only. |
| IAM roles | Each component gets its own role with only what it needs. |
| Pod Identity | Pods get AWS permissions without access keys. |
| Ingress and ALB | One entry point routing to many services; the controller builds the real load balancer. |
| Autoscaling | HPA adds pods; Karpenter adds nodes. |
| Karpenter | Watches for pods that cannot be scheduled and launches the cheapest right-sized node for them. No fixed node groups. |
| NodePool | The rules: allowed instance types, Spot or On-Demand, a CPU cap, expiry, when to consolidate. |
| EC2NodeClass | The AWS details: AMI, subnets, security group, disk, node IAM role. |
| Right-sizing | Nodes are picked from the pods' **requests**, so set requests. |
| Consolidation | Karpenter removes empty or underused nodes and repacks pods. This is the saving. |
| Spot | Spare AWS capacity, often around 70% cheaper, but AWS can reclaim it with a 2-minute warning. |
| Diversification | Allow many instance types and zones so Spot capacity rarely runs out. |
| Interruption flow | EC2 warning, EventBridge, SQS, Karpenter, drain the node, reschedule, replacement node ready. |
| PodDisruptionBudget | Limits how many pods a drain may take at once, so a Spot reclaim causes no downtime. |
| Observability | Traces show where time goes, logs say what happened, metrics show trends. |

## Optional 2-minute Karpenter add-on (only if you ran Steps 22 to 25)
| Show | Say |
|---|---|
| `kubectl scale deployment inflate --replicas=8`, then `kubectl get nodeclaims -w` | "Pods asked for more CPU than the cluster had. Karpenter launched right-sized Spot nodes within a minute." |
| `kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type` | "Spot first, On-Demand as fallback, and a mix of instance types so one shortage does not hurt." |
| Scale down, nodes disappear | "Consolidation removes nodes that are not needed, so I stop paying for them." |
| The deployment during the simulated Spot warning | "I simulated the 2-minute warning. Karpenter drained the node and replaced it, and the PodDisruptionBudget kept 3 of 4 pods available." |

## Say it in 30 seconds
"I built CareConnect, a clinic booking platform with five microservices, to practise platform engineering end to end. The services are containerised with multi-stage, non-root images. A Helm chart deploys them to Kubernetes, and ArgoCD deploys from Git, so a release is a version tag and a rollback is a Git revert. Terraform builds the AWS network and EKS cluster. I wrote step-by-step run instructions and an incident-style teardown so it is repeatable."

## Questions you will get, with one-line answers
| Question | Answer |
|---|---|
| Why GitOps instead of deploying from the pipeline? | The cluster pulls from Git, so CI holds no cluster credentials, every change is a reviewable commit, and drift is corrected automatically. |
| How do you roll back? | Revert the deploy commit in Git; ArgoCD reconciles. |
| Why did a broken release not cause downtime? | Rolling updates and readiness probes keep old pods serving until new ones are ready. |
| Why one Helm chart for five services? | Consistency and less duplication; per-service values hold the differences. |
| Why private subnets and a NAT gateway? | Servers have no inbound internet path, but can still reach out for updates. |
| How do pods get AWS access? | Pod Identity maps a ServiceAccount to an IAM role: no stored keys. |
| Where are secrets kept? | Not in Git. In AWS Secrets Manager, delivered by the CSI driver; GitHub secrets for CI. |
| What would you improve? | Image scanning, network policies, external secrets, HTTPS on a custom domain, tracing and SLO alerts, and two Karpenter replicas plus a pinned AMI for production. |
| Karpenter or Cluster Autoscaler? | Karpenter reacts to pending pods and picks any fitting instance type directly, instead of scaling pre-defined node groups. It is usually faster and cheaper, and it consolidates nodes. |
| What happens when a Spot node is reclaimed? | AWS sends a 2-minute warning. EventBridge puts it in SQS, Karpenter reads it, starts a replacement, drains the node, and the pods reschedule. The PodDisruptionBudget keeps enough replicas serving. |
| Is Spot safe for production? | For stateless services, yes, with several replicas, zone spread, a PDB, diversified instance types and an On-Demand fallback. Not for single-replica or stateful work. |
| Where does Karpenter run? | On a small managed node group, because it cannot create the node it runs on. |
| What went wrong while building it? | Use your own real story from [the README](README.md), for example a pod stuck in ImagePullBackOff, or a teardown that left a load balancer behind. |

## Be exact about scope
Write two honest sentences and use them:
- "I built and ran X locally on Docker and Kubernetes (kind)."
- "I validated the AWS Terraform code, and (if true) deployed it to a practice AWS account and destroyed it afterwards."
- "For Karpenter, I ran the Spot interruption demo with a simulated warning message." (Say only what is true.)
Interviewers respect precise claims far more than big ones.
