locals {
  account_id = data.aws_caller_identity.current.account_id

  slack_settings = {
      webhook_cis = var.webhook,
      username    = "AWSBot",
      channel     = "sys-aws-cis"
  }

  tags = {
    ManagedBy = "Terraform"
  }
}
