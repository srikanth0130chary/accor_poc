# Karpenter provisions burst nodes in seconds when the HPA fans pods out
# during a Flash Sale spike, rather than waiting on the slower managed
# node-group Cluster Autoscaler path. The always-on "baseline" managed node
# group (eks.tf) absorbs steady traffic; Karpenter only spins up NodePools
# when pod scheduling pressure exceeds that baseline capacity, and scales
# back to zero extra nodes once the spike passes.

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.0.6"

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa.iam_role_arn
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  depends_on = [module.eks]
}

# NodePool + EC2NodeClass are applied as Kubernetes manifests (not raw
# Terraform resources) since they're Karpenter CRDs - see k8s/karpenter-nodepool.yaml.
# This resource just confirms the CRDs are installed before that manifest is applied.
resource "null_resource" "karpenter_ready" {
  depends_on = [helm_release.karpenter]
}
