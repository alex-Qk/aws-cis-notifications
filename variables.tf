variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "webhook" {
  description = "Slack webhook URL"
  type        = string
  default     = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
}
