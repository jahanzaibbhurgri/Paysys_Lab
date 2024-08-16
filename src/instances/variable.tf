# instances/variables.tf
variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "public_security_group_id" {
  type = string
}

variable "private_security_group_id" {
  type = string
}

variable "key_name" {
  description = "The key pair name to use for SSH access"
  type        = string
}

variable "user_data" {
  type = string
  default = <<-EOF
              #!/bin/bash
              sudo yum install nginx -y
              sudo systemctl start nginx
              EOF
}
