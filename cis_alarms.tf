module "cloudwatch_cis_alarms" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/cis-alarms"
  version = "5.7.0"

  log_group_name = module.cloudwatch_log_group.cloudwatch_log_group_name
  alarm_actions  = [module.notify_slack_cis.slack_topic_arn]

  tags = local.tags
}

module "notify_slack_cis" {
  source  = "terraform-aws-modules/notify-slack/aws"
  version = "5.6.0"

  sns_topic_name       = "notify-via-slack-cis"
  lambda_function_name = "notify-via-slack-cis"
  slack_webhook_url    = local.slack_settings.webhook_cis
  slack_username       = local.slack_settings.username
  slack_channel        = local.slack_settings.channel

  cloudwatch_log_group_retention_in_days = 30
  iam_role_name_prefix                   = "notifications-aws-cis"
  lambda_description                     = "Lambda function which sends CIS notifications to Slack"
  lambda_function_s3_bucket              = module.lambda_bucket.s3_bucket_id
  lambda_function_store_on_s3            = true
  log_events                             = true
  recreate_missing_package               = false
  tags                                   = local.tags
}

module "lambda_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.4.0"

  attach_deny_insecure_transport_policy = true
  block_public_acls                     = true
  block_public_policy                   = true
  bucket                                = "lambda-cis-${local.account_id}"
  ignore_public_acls                    = true
  restrict_public_buckets               = true
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  versioning = {
    enabled = true
  }
  tags = local.tags
}
