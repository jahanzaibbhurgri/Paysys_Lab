//route.ts main.tf//
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_ids
  }

  tags = {
    Name = var.public_route_table_name
  }
}

resource "aws_route_table" "private" {
  count  = length(var.nat_gateways_ids)
  vpc_id = var.vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_gateways_ids[count.index]
  }

  tags = {
    Name = "${var.private_route_table_name}-${count.index + 1}"
  }
}

#route table assiociation
resource "aws_route_table_association" "public_associations" {
  count          = length(var.public_subnet_ids)
  subnet_id      = var.public_subnet_ids[count.index]
  route_table_id = aws_route_table.public.id
}



resource "aws_route_table_association" "private_associations" {
  count          = length(var.private_subnet_ids)
  subnet_id      = var.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private[count.index].id
}
