variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project" {
  type    = string
  default = "rtdp"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "producer_schedule_enabled" {
  type    = bool
  default = false
}

variable "aws_sdk_pandas_layer_arn" {
  type    = string
  default = "arn:aws:lambda:ap-southeast-2:336392948345:layer:AWSSDKPandas-Python312:32"
}