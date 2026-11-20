# Screenshots

Save each screenshot here with the file name used in [RUN-IT.md](../../RUN-IT.md). Take the ones for the steps you actually did.

| File | Step | Shows |
|---|---|---|
| 01-image-size.png | 3 | Single-stage vs multi-stage image size |
| 02-compose-healthy.png | 4 | `docker compose ps`, everything healthy |
| 03-load-balancing.png | 5 | Different container ids in the curl loop |
| 04-k8s-pods.png | 8 | `helm list` and the running pods |
| 05-data-survives.png | 9 | Database rows still there after the pod was deleted |
| 06-self-healing.png | 10 | A deleted pod replaced |
| 07-bad-release.png | 11 | A failing new pod while old pods keep serving |
| 08-argocd-green.png | 14 | ArgoCD, all applications Synced and Healthy |
| 09-actions-release.png | 15 | Green release run (5 builds) |
| 10-bot-commit.png | 15 | The bot's `ci: deploy ...` commit |
| 11-git-revert-rollback.png | 17 | The revert commit and the app healthy again |
| 12-terraform-plan.png | 18 | `terraform plan` |
| 13-eks-nodes.png | 20 | `kubectl get nodes` on EKS (optional) |
| 14-alb-curl.png | 21 | Services answering through the ALB (optional) |
| 15-jaeger.png | 27 | Traces in the local lab (optional) |
| 16-karpenter-running.png | 22 | Karpenter pod running, EventBridge rules listed (optional) |
| 17-consolidation.png | 23 | On-Demand node added, then consolidated after scale-down (optional) |
| 18-spot-nodes.png | 24 | `kubectl get nodes` showing spot capacity type and mixed instance types (optional) |
| 19-spot-interruption.png | 25 | Simulated Spot warning: drain, replacement node, deployment stays available (optional) |
| 20-https-domain.png | Lab 15-16 | Padlock on `https://portal.<domain>` (optional) |
| 21-hpa-karpenter.png | Lab 18 | HPA, Pending pods and a new nodeclaim (optional) |
| 22-xray-service-map.png | Lab 20 | `booking` to `appointments` service map (optional) |
| 23-ecr-images.png | Lab 21 | Five ECR repositories with the new tag (optional) |
| 24-argocd-eks.png | Lab 21 | ArgoCD on EKS, all Synced and Healthy (optional) |
