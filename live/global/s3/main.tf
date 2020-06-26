provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key

  region = "eu-south-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-n46-state"

  #facciamo in modo che non si possa cancellare accidentalmente
  lifecycle {
    prevent_destroy = true
  }

  #attiviamo il versioning, in modo da poter vedere la storia del nostro state file
  versioning {
    enabled = true
  }

  #attiviamo la crittografia server-side
  server_side_encryption_configuration{
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

}


#Ora che più membri del team possono accedere al bucket abbiamo bisogno di un meccanismo di
#gestione degli accessi tramite lock, possiamo farlo una table di DynamoDB
resource "aws_dynamodb_table" "terraform_locks" {
  name = "terraform-n46-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}



#Ora per permettere a terraform di conservare il tfstate nel bucket abbaimo bisogno di configurare il beckend
terraform {
  backend "s3" {
    bucket = "terraform-n46-state"
    key = "global/s3/terraform.tfstate" #il path in cui conservarlo, riproduciamo la nostra cartella locale
    region = "eu-south-1"
    dynamodb_table = "terraform-n46-locks"
    encrypt = true
    skip_region_validation = true   #da HashiCorp non è stato ancora rilasciato supporto per queste region, quindi dobbaimo aggirare la verifica
  }
}
