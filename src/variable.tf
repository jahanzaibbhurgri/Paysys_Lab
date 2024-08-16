
variable "cidr" {
  description = "The cidr of the vpc"
  type        = string
  default     = "10.0.0.0/16"
}
//this is about 65000 ips//
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}


variable "availability_zones" {
  description = "The availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}


variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}


variable "instance_type" {
  description = "The instance type to use for EC2 instances"
  type        = string
  default     = "t2.micro"
}

variable "ami" {
  description = "The AMI ID to use for EC2 instances"
  type        = string
  default     = "ami-04a81a99f5ec58529"
}

variable "project" {
  description = "The name of the project"
  type        = string
  default     = "terraform project"
}
