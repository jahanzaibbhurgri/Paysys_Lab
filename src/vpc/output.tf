#vpc output.tf
output "vpc_ids" {
  value = aws_vpc.myvpc.id
}
