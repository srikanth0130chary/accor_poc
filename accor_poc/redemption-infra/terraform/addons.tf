resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_irsa.iam_role_arn
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
  set {
    name  = "region"
    value = var.aws_region
  }

  depends_on = [module.eks]
}

# Metrics server - required for HPA to read CPU/memory metrics
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"

  depends_on = [module.eks]
}

# kube-prometheus-stack - Prometheus + Grafana + Alertmanager for
# observability (D. Reliability & Observability) and to feed the
# Prometheus Adapter so HPA can scale on requests-per-second, not just CPU.
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "62.5.1"

  values = [<<-EOT
    grafana:
      persistence:
        enabled: true
        size: 10Gi
    prometheus:
      prometheusSpec:
        retention: 15d
        storageSpec:
          volumeClaimTemplate:
            spec:
              resources:
                requests:
                  storage: 50Gi
  EOT
  ]

  depends_on = [module.eks]
}

# ArgoCD - GitOps controller so Day-2 operations are "commit to main"
# rather than manual kubectl apply (reduces toil per requirement E).
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.6.8"

  depends_on = [module.eks]
}
