variable "aws_region" {
  description = "AWS region for the cluster"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "the-redemption"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.40.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread the cluster across (min 3 for zero-downtime target)"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "baseline_node_min" {
  description = "Minimum nodes in the always-on baseline managed node group"
  type        = number
  default     = 3
}

variable "baseline_node_desired" {
  description = "Desired nodes in the baseline managed node group (steady traffic)"
  type        = number
  default     = 6
}

variable "baseline_node_max" {
  description = "Max nodes the baseline group can reach before Karpenter burst nodes take over"
  type        = number
  default     = 9
}

variable "baseline_instance_types" {
  description = "Instance types for the always-on baseline node group"
  type        = list(string)
  default     = ["m6i.large", "m6a.large"]
}
