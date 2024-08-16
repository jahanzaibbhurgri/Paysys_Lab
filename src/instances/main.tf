# instances/main.tf
resource "aws_instance" "nginx_servers" {
  count = 2

  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.public_subnets[count.index]
  vpc_security_group_ids = [var.public_security_group_id]
  associate_public_ip_address = true
  user_data              = var.user_data
}

resource "aws_instance" "private_servers" {
  count = 2

  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnets[count.index]
  vpc_security_group_ids      = [var.private_security_group_id]
  associate_public_ip_address = false
}
