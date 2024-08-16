output "nginx_instance_ids" {
  value = aws_instance.nginx_servers[*].id
}

output "private_instance_ids" {
  value = aws_instance.private_servers[*].id
}