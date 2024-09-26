//nat-gateway variable//
variable "vpc_id" {
  type = string
}

variable "subnets_ids" {
  type = list(string)
}

variable "internet_gateway_ids" {
  type = string
}
