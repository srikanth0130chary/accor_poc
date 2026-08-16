# DynamoDB over RDS for the points ledger: point deductions are simple
# key-value read/write/conditional-update patterns, and DynamoDB's on-demand
# capacity mode absorbs a 10x Flash Sale spike without any manual scaling
# step - which a relational engine would need read replicas/provisioned
# IOPS changes to match. Multi-AZ durability is inherent, not something we configure.

resource "aws_dynamodb_table" "points_ledger" {
  name         = "the-redemption-points-ledger"
  billing_mode = "PAY_PER_REQUEST" # scales automatically through the 10x spike, no capacity planning
  hash_key     = "memberId"
  range_key    = "transactionId"

  attribute {
    name = "memberId"
    type = "S"
  }
  attribute {
    name = "transactionId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = true
}
