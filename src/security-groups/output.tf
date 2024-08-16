output "public_sg_ids" {
  value = aws_security_group.public.id
}

output "private_sg_ids" {
  value = aws_security_group.private.id
}