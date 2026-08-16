# --- IRSA: every controller and workload gets its own scoped IAM role. ---
# This is the "Least Privilege" control for AWS API access - nodes carry no
# broad IAM permissions themselves, only the pod's service account does.

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                              = "${var.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                          = "${var.cluster_name}-karpenter"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_id         = module.eks.cluster_name
  karpenter_controller_node_iam_role_arns = [module.eks.eks_managed_node_groups["baseline"].iam_role_arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
}

# App-specific role: scoped to exactly what "The Redemption" needs -
# read/write on its own DynamoDB table and its own Secrets Manager secret,
# nothing else. This is what gets referenced in k8s/serviceaccount.yaml.
data "aws_iam_policy_document" "redemption_app" {
  statement {
    sid       = "PointsTableAccess"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:ConditionCheckItem"]
    resources = [aws_dynamodb_table.points_ledger.arn, "${aws_dynamodb_table.points_ledger.arn}/index/*"]
  }
  statement {
    sid       = "AppSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:the-redemption/*"]
  }
}

resource "aws_iam_policy" "redemption_app" {
  name   = "${var.cluster_name}-app-policy"
  policy = data.aws_iam_policy_document.redemption_app.json
}

module "redemption_app_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "${var.cluster_name}-app-sa"

  role_policy_arns = {
    app_policy = aws_iam_policy.redemption_app.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["redemption:redemption-app"]
    }
  }
}
