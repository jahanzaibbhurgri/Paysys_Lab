variable "vpc_id" {
  type = string
}



variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}


variable "public_route_table_name" {
  type    = string
  default = "public-route-table"
}

variable "private_route_table_name" {
  type    = string
  default = "private-route-table"
}

variable "internet_gateway_ids" {
  type = string

}

variable "nat_gateways_ids" {
  type = list(string)
}
