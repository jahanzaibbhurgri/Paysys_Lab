resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-lock" # Name of the table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LOCKID"

  attribute {
    name = "LOCKID"
    type = "S"
  }

  tags = {
    Name = "terraform-lock-table"
  }
}
