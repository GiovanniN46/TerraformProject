#Parametri opzionali
variable "server_port" {
  type = number
  default = 8080
}

#Parametri necessari--------------------------
variable "cluster_name" {
  description = "Il nome da usa per le risorse cluster"
  type = string
}

variable "db_remote_state_bucket" {
  description = "Il nome del bucket S3 per il database remote state"
  type = string
}

variable "db_remote_state_key" {
  description = "Il path del remote state del DB in S3"
  type = string
}


variable "instance_type" {
  description = "Il tipo di istanza EC2 (ad esempio t3.micro)"
  type        = string
}

variable "min_size" {
  description = "Il numero minimo di EC2 istanze nell' ASG"
  type        = number
}

variable "max_size" {
  description = "Il numero massimo di EC2 istanze nell'ASG"
  type        = number
}
