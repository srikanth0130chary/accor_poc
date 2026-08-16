module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # nodes only ever live in private subnets

  # Least privilege networking on the control plane itself
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # tighten to corp CIDR / VPN range in real deployment
  cluster_endpoint_private_access      = true

  enable_irsa = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  cluster_encryption_config = {
    resources = ["secrets"]
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2023_x86_64_STANDARD"
    disk_size      = 50
    subnet_ids     = module.vpc.private_subnets
  }

  eks_managed_node_groups = {
    # Always-on baseline capacity for steady traffic. Karpenter (see karpenter.tf)
    # handles the elastic burst on top of this during Flash Sale spikes.
    baseline = {
      min_size     = var.baseline_node_min
      max_size     = var.baseline_node_max
      desired_size = var.baseline_node_desired

      instance_types = var.baseline_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "baseline"
      }

      # Spread the managed node group itself evenly across AZs
      subnet_ids = module.vpc.private_subnets

      taints = []
    }
  }

  # Node security group rules - default deny, explicit allow only what's needed
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_https = {
      description = "Egress HTTPS for pulling images / calling AWS APIs"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# Cluster-critical add-ons managed as EKS add-ons rather than hand-rolled manifests
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"
  depends_on   = [module.eks]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name                = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
  depends_on                = [module.eks]
}
