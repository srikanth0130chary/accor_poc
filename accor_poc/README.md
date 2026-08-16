# The Redemption — Cloud Engineer Assessment

Infrastructure-as-Code and Kubernetes manifests for "The Redemption," a
business-critical hotel-points-deduction microservice on AWS EKS, built for
Accor's Preliminary Technical Assessment (Cloud Engineer).

See **design-document.pdf** for the full executive summary, architectural
decisions, trade-offs, and team delegation plan. See **diagram/architecture.png**
for the data-flow / AWS component diagram.

## Repository layout

```
terraform/
  versions.tf        # providers, S3/DynamoDB remote state backend
  variables.tf        # region, cluster sizing, AZ inputs
  vpc.tf               # 3-AZ VPC: public / private / isolated data subnets
  eks.tf               # EKS cluster, baseline managed node group, core add-ons
  irsa.tf              # least-privilege IAM roles per controller/workload
  data.tf              # DynamoDB points ledger table
  karpenter.tf         # Karpenter install for burst autoscaling
  addons.tf            # ALB controller, metrics-server, kube-prometheus-stack, ArgoCD
  outputs.tf

k8s/
  00-namespace-serviceaccount.yaml   # IRSA-annotated ServiceAccount
  01-deployment.yaml                 # topology spread, probes, security context
  02-service.yaml
  03-ingress.yaml                    # ALB + WAF + TLS
  04-hpa.yaml                        # CPU / memory / custom RPS metric, 6→90 replicas
  05-pdb.yaml                        # minAvailable: 80%
  06-networkpolicy.yaml              # default-deny + explicit allow
  07-karpenter-nodepool.yaml         # burst NodePool / EC2NodeClass

diagram/
  architecture.dot     # Graphviz source
  architecture.png      # rendered diagram

design-document.pdf
```

## Deploy order

1. Create the S3 state bucket and DynamoDB lock table referenced in
   `terraform/versions.tf` (one-time, out of band).
2. `cd terraform && terraform init && terraform plan && terraform apply`
3. `aws eks update-kubeconfig --name the-redemption --region ap-southeast-1`
   (also printed as a Terraform output)
4. Fill in the placeholders in the k8s manifests before applying:
   - `<ACCOUNT_ID>` in `00-namespace-serviceaccount.yaml` — use the
     `app_irsa_role_arn` Terraform output
   - `<ECR_REPO_URI>` / `__IMAGE_TAG__` in `01-deployment.yaml`
   - `<ACM_CERT_ARN>` and `<WAFV2_ACL_ARN>` in `03-ingress.yaml`
   - `<KARPENTER_NODE_IAM_ROLE_NAME>` in `07-karpenter-nodepool.yaml` — use
     the baseline managed node group's IAM role name
5. `kubectl apply -f k8s/`

In production this last step is handled by ArgoCD syncing this repo rather
than manual `kubectl apply` — see design-document.pdf, section E.

## Notes / known placeholders

This was built for a timed technical assessment, so a few values are left as
placeholders rather than wired to a live AWS account (container image URI,
ACM certificate, WAF ACL, and the public EKS endpoint CIDR restriction). All
are called out inline in the manifests and in the design document's
trade-offs table.
