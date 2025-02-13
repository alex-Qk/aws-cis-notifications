//---------------cloudwatch---------------//

module "cloudwatch_log_group" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/log-group"
  version = "4.2.1"

  name              = "DefaultLogGroup"
  retention_in_days = 182
  tags              = local.tags
}

//---------------KMS---------------//

module "cloudtrail_cmk" {
  source  = "terraform-aws-modules/kms/aws"
  version = "2.1.0"

  description = "KMS key for encrypting/decrypting cloudtrail logs"

  # Policy
  override_policy_documents = [data.aws_iam_policy_document.cloudtrail_cmk_policy.json]
  key_owners                = ["arn:aws:iam::0123456789:user/alex"]
  key_administrators        = ["arn:aws:iam::0123456789:user/alex"]
  key_users                 = ["arn:aws:iam::0123456789:user/alex"]

  # Aliases
  aliases = ["cloudtrail-cmk"]

  tags = local.tags
}

data "aws_iam_policy_document" "cloudtrail_cmk_policy" {
  statement {
    sid    = "Allow CloudTrail to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
  }
}


//--------------- cloudtrail bucket---------------//

module "cloudtrail_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.6.0"

  attach_policy                         = true
  attach_deny_insecure_transport_policy = true
  block_public_acls                     = true
  block_public_policy                   = true
  bucket                                = "cloudtrail-${local.account_id}"
  ignore_public_acls                    = true
  policy                                = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
  restrict_public_buckets               = true
  control_object_ownership              = true
  object_ownership                      = "BucketOwnerPreferred"
  tags                                  = local.tags
}

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["arn:aws:s3:::cloudtrail-${local.account_id}"]
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com",
        "config.amazonaws.com"
      ]
    }
    resources = ["arn:aws:s3:::cloudtrail-${local.account_id}/*"]

    condition {
      test     = "StringEquals"
      values   = ["bucket-owner-full-control"]
      variable = "s3:x-amz-acl"
    }
  }
}

//---------------cloudtrail---------------//

module "cloudtrail" {
  source  = "cloudposse/cloudtrail/aws"
  version = "0.22.0"

  name                          = "audit"
  s3_bucket_name                = module.cloudtrail_bucket.s3_bucket_id
  cloud_watch_logs_group_arn    = "${module.cloudwatch_log_group.cloudwatch_log_group_arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch_role.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  kms_key_arn                   = module.cloudtrail_cmk.key_arn
  tags                          = local.tags
}

data "aws_iam_policy_document" "cloudtrail_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  name               = "cloudtrail-cis-${local.account_id}"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role.json
  tags               = local.tags
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch_logs" {
  statement {
    sid = "WriteCloudWatchLogs"

    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${module.cloudwatch_log_group.cloudwatch_log_group_arn}:*"]
  }
}

resource "aws_iam_policy" "cloudtrail_cloudwatch_logs" {
  name   = "cloudtrail-cis-${local.account_id}"
  policy = data.aws_iam_policy_document.cloudtrail_cloudwatch_logs.json
}

resource "aws_iam_policy_attachment" "cloudtrail_cloudwatch_logs" {
  name       = "cloudtrail-cis-${local.account_id}"
  policy_arn = aws_iam_policy.cloudtrail_cloudwatch_logs.arn
  roles      = [aws_iam_role.cloudtrail_cloudwatch_role.name]
}
