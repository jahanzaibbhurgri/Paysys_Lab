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
module "instances" {
  source                    = "./instances"
  public_subnets            = module.subnets.public_subnets_ids
  private_subnets           = module.subnets.private_subnets_ids
  key_name                  = module.key_pair.key_name
  public_security_group_id  = module.security-groups.public_sg_ids
  private_security_group_id = module.security-groups.private_sg_ids
  ami                       = var.ami
  instance_type             = var.instance_type
}

module "route" {
  source               = "./route"
  vpc_id               = module.vpc.vpc_ids
  public_subnet_ids    = module.subnets.public_subnets_ids
  private_subnet_ids   = module.subnets.private_subnets_ids
  internet_gateway_ids = module.network.internet_gateway_ids
  nat_gateways_ids     = module.nat-gateway.nat_gateways_ids
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
