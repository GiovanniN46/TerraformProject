variable "instance_type" {
  description = "Il tipo di istanza per il nostro server EC2"
  type = string
  default = "t3.micro"

}


variable "access_key"{
  type = string
  default = ""
}

variable "secret_key"{
  type = string
  default = ""
}
