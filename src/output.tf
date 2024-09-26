output "vpc_ids" {
  value = module.vpc.vpc_ids
}

output "public_subnets_ids" {
  value = module.subnets.public_subnets_ids
}

output "private_subnet_ids" {
  value = module.subnets.private_subnets_ids
}

output "public_sg_ids" {
  value = module.security-groups.public_sg_ids
}
output "private_sg_ids" {
  value = module.security-groups.private_sg_ids
}


# output "nginx_instance_ids" {
#   value = module.instances.nginx_instance_ids
# }

# output "private_instance_ids" {
#   value = module.instances.private_instance_ids
# }

output "nat_gateways_ids" {
  value = module.nat-gateway.nat_gateways_ids
}

output "internet_gateway_ids" {
  value = module.network.internet_gateway_ids
}
output "key_name" {
  value = module.my_key_pair.key_name
}

output "private_key_path" {
  value     = module.key_pair.private_key_path
  sensitive = true
}
