provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key

  region = "eu-south-1"
}


module "webserver_cluster" {
  source = "C:/Users/giann/Desktop/Tesi/modules/services/webserver-cluster" 
  cluster_name = "webserver-stage"
  db_remote_state_bucket = "terraform-n46-state"
  db_remote_state_key = "stage/data-store/mysql/terraform.tfstate"

  instance_type = "t3.micro"
  min_size = 2
  max_size = 10

}


#Questo andrebbe fatto per la PRODUZIONE: aumentare e diminuire il numero delle istanze EC2 a seconda
#dell'orario, in modo da gestire meglio i carichi di lavoro
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  scheduled_action_name = "scale-out-during-business-hours"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 10
  recurrence            = "0 9 * * *" #dalle 9 di ogni giorno (cron syntax)

  autoscaling_group_name = module.webserver_cluster.asg_name #colleghiamo il nostro asg

}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  scheduled_action_name = "scale-in-at-night"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 2
  recurrence            = "0 17 * * *" #dalle 17 di ogni giorno (cron syntax)

  autoscaling_group_name = module.webserver_cluster.asg_name

}


#decidiamo di testare un'altra porta
resource "aws_security_group_rule" "allow_testing_inbound" {
  type              = "ingress"
  security_group_id = module.webserver_cluster.alb_security_group_id

  from_port   = 12345
  to_port     = 12345
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
