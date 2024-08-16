

resource "aws_eip" "eip" {
  depends_on = [var.internet_gateway_ids]
  count = length(var.subnets_ids)
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.subnets_ids)
  allocation_id = aws_eip.eip[count.index].id
  subnet_id     = var.subnets_ids[count.index]
}