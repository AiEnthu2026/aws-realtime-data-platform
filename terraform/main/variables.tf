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