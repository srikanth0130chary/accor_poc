module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  # Private subnets: EKS nodes + pods only. No route to IGW.
  private_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  # Public subnets: ALB / NAT gateways only.
  public_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]
  # Dedicated intra subnets for the RDS layer - no NAT/IGW route at all (defense in depth).
  database_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i + 4)]

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true # one NAT per AZ so an AZ outage can't take out egress for the other two
  single_nat_gateway     = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # Required tags for the AWS Load Balancer Controller / EKS to auto-discover subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
    "karpenter.sh/discovery"                     = var.cluster_name
  }

  flow_log_destination_type           = "cloud-watch-logs"
  enable_flow_log                     = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
}
