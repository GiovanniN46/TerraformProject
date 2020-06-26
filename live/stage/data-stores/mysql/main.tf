#creaiamo un DB servendoci di Amazon's Relational Database Services (RDS) che supporta una vastità di database, tra cui anche mysql
provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key

  region = "eu-south-1" 
}




resource "aws_db_instance" "example" {
  identifier_prefix = "terraform-n46"
  engine = "mysql"
  allocated_storage = 10
  instance_class = "db.t3.micro"
  name = "example_database"
  username = "admin"
  password = var.db_password
}

terraform {
  backend "s3" {
    bucket = "terraform-n46-state"
    key = "stage/data-store/mysql/terraform.tfstate" #il path in cui conservarlo, riproduciamo la nostra cartella locale
    region = "eu-south-1"
    dynamodb_table = "terraform-n46-locks"
    encrypt = true
    skip_region_validation = true   #da HashiCorp non è stato ancora rilasciato supporto per queste region, quindi dobbaimo aggirare la verifica
  }
}
