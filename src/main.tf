/*
locals {
    project = "assignment"
}

# Create a VPC
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
  tags = {
     Name = local.project //we could also use this like making locals but im making it simple its just for good approach 
  }

}

# creation of the public and private subnets in the us-east-1a
resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block =  "10.0.0.0/24" //this about 256 ips//
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true 
}

resource "aws_subnet" "pri-sub1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block =  "10.0.1.0/24" 
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = false
}


# creation of the public and private subnets in the us-east-1b
resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block =  "10.0.3.0/24" 
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "priv-sub2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block =  "10.0.4.0/24" 
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = false
}

#creation of igw to the vpc
resource "aws_internet_gateway" "igw" {
   vpc_id = aws_vpc.myvpc.id 
}

#elastic ip for the both of the nat gateway each in the subnet
resource "aws_eip" "nat1" {	
   depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat2" {
   depends_on = [aws_internet_gateway.igw]
}

#creation of the two nat gateway on both of the az
resource "aws_nat_gateway" "gw1" {
     allocation_id = aws_eip.nat1.id
     subnet_id  = aws_subnet.sub1.id  //allocating the nat gateway in the pub-sub-1a
   tags = {
	Name =  "nat1"
	}
}   

resource "aws_nat_gateway" "gw2" {
     allocation_id = aws_eip.nat2.id
     subnet_id  = aws_subnet.sub2.id //allocating the nat gateway in the pub-sub-1b
   tags = {
	Name =  "nat2"
	}
}

# creation of the route table, 1 for public subnet and 2 for private subnet 
resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0/0" //this is the route table directed to the igw then we are gonna attached to the public subnet//
        gateway_id =  aws_internet_gateway.igw.id     // writing the comment just for the interview purpose :/ //
    }
}

resource "aws_route_table" "private1" {
    vpc_id = aws_vpc.myvpc.id
    route {
      cidr_block = "0.0.0.0/0"	
      nat_gateway_id = aws_nat_gateway.gw1.id
  }
  tags = {
    Name = "nat-gateway for the private-sub-1a"
 }
}

resource "aws_route_table" "private2" {
    vpc_id = aws_vpc.myvpc.id
    route {
     cidr_block = "0.0.0.0/0"	
     nat_gateway_id = aws_nat_gateway.gw2.id
    }
tags = {
    Name = "nat-gateway for the private-sub-1b"
 }
}

# assiociation of the route tables which is for the public subnet
resource "aws_route_table_association" "pub-rt-1" { 
     subnet_id = aws_subnet.sub1.id
     route_table_id =  aws_route_table.rt.id
 }
 resource "aws_route_table_association" "pub-rt-2" {   
     subnet_id = aws_subnet.sub2.id
     route_table_id =  aws_route_table.rt.id
 }

# assiociation of the route tables which is for the private subnet
 resource "aws_route_table_association" "pri-rt-1" {   
     subnet_id = aws_subnet.priv-sub2.id
     route_table_id =  aws_route_table.private1.id
 }

resource "aws_route_table_association" "pri-rt-2" {   
     subnet_id = aws_subnet.priv-sub2.id
     route_table_id =  aws_route_table.private2.id
 }

#creation of the security group for the public and private instances
resource "aws_security_group" "nginx_sg" {
   vpc_id = aws_vpc.myvpc.id
   #this is for the http
   ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 #this is for the ssh
 ingress {
   description = "SSH"
   from_port = 22
   to_port = 22
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
 }	

  
  #outbound rules
  egress {
	from_port = 0 
        to_port = 0 # this could be for all available 
        protocol = "-1" # which means all protocol
        cidr_blocks = ["0.0.0.0/0"]
   }
}

resource "aws_security_group" "private_instance_sg" {
  vpc_id = aws_vpc.myvpc.id
  ingress {
    from_port   = 80  //allow for the http and if 443 then it would be https
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]  
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#creation of the ssh keypair
resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 4096   
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "assignment-key-pair"
  public_key = tls_private_key.my_key.public_key_openssh
}

output "private_key" {
  value     = tls_private_key.my_key.private_key_pem
  sensitive = true
}   //this should be in the output folder//



//creation of the public instances in the public subnet 
resource "aws_instance" "nginxserver1" {
  ami = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.sub1.id
  key_name      = aws_key_pair.my_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  // we could also write this script in userdata.sh file and can a make call like it as this is good approach  
  // user_data = base64encode(file("userdata.sh"))
  // just writing this for the interview purpose   
  associate_public_ip_address = true
  user_data = <<-EOF
                #!/bin/bash
                sudo yum install nginx -y 
                sudo systemctl start nginx
                EOF
     tags = {
      Name = "NginxServer1"
   }
}

resource "aws_instance" "nginxserver2" {
  ami = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.sub2.id
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  key_name      = aws_key_pair.my_key_pair.key_name
  associate_public_ip_address = true
  user_data = <<-EOF
                #!/bin/bash
                sudo yum install nginx -y 
                sudo systemctl start nginx
                EOF
     tags = {
      Name = "NginxServer2"
   }
}

#creation of the private instances in the private subnet which makes connection to the nat gateway
resource "aws_instance" "privserver1" {
  ami = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pri-sub1.id
  vpc_security_group_ids = [aws_security_group.private_instance_sg.id]
  associate_public_ip_address = false //it is not recommended 
     tags = {
      Name = "privateInstance1"
   }
}

resource "aws_instance" "privserver2" {
  ami = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.priv-sub2.id
  vpc_security_group_ids = [aws_security_group.private_instance_sg.id]
  associate_public_ip_address = false  //it is recommmended 
   //reason: to isolate the private instances from the internet or not being exposed as we using nat for this purpose only
     tags = {
      Name = "privateInstance1"
   }
}



//github action which is in youtube 
//then assignment is complete 

//creation of bucket s3 in which statefile is kept
//more concept for the good code and kept it as a comment 
//seperation of these code into the seperate file 
*/



provider "aws" {
  region = var.aws_region
}


module "s3" {
  source = "./simpleservicestorage"
}

module "dynamodb" {
  source = "./dynamodb"
}
module "vpc" {
  source  = "./vpc"
  cidr    = var.cidr
  project = var.project
}

module "subnets" {
  source               = "./subnets"
  vpc_id               = module.vpc.vpc_ids
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "key_pair" {
  source   = "./key_pair"
  key_name = "keypair007"
}

module "nat-gateway" {
  source               = "./nat-gateway"
  vpc_id               = module.vpc.vpc_ids
  subnets_ids          = module.subnets.public_subnets_ids
  internet_gateway_ids = module.network.internet_gateway_ids
}

module "security-groups" {
  source = "./security-groups"
  vpc_id = module.vpc.vpc_ids
}

module "my_key_pair" {
  source = "./key_pair"

}


module "route" {
  source               = "./route"
  vpc_id               = module.vpc.vpc_ids
  public_subnet_ids    = module.subnets.public_subnets_ids
  private_subnet_ids   = module.subnets.private_subnets_ids
  internet_gateway_ids = module.network.internet_gateway_ids
  nat_gateways_ids     = module.nat-gateway.nat_gateways_ids
}

module "eks" {
  source             = "./eks"
  vpc_id             = module.vpc.vpc_ids
  public_subnet_ids  = module.subnets.public_subnets_ids
  private_subnet_ids = module.subnets.private_subnets_ids

}

module "network" {
  source = "./network"
  vpc_id = module.vpc.vpc_ids
}


/*
terraform {
  backend "s3" {
    bucket         = "jahanzaib"
    key            = "jahanzaib/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
  }
}
*/
//first create the resources and then uncomment it and then apply the terraform apply 
//it will apply the lock if someone is locking so it would make that person to wait until or unless that person execution is done
