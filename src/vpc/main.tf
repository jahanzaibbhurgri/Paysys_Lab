# Create a VPC in one way
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
  tags = {
    Name = var.project
  }
}
