//natewaygateway output.tf//

output "nat_gateways_ids" {
  value = aws_nat_gateway.nat[*].id
}
