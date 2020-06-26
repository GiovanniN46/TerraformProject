#interrogiamo il nostro provider per avere informazioni sul Default VPC dell'account AWS
data "aws_vpc" "default" {
  default = true
}

#ora possiamo leggere informazioni sulle subnets nella nostra VPC
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

#Vogliamo rilasciare un cluster di web servers, per farlo possiamo serverci dell' Amazon Autoscaling Group


#Il launch configuration specificherà come configurare ogni instanza EC2
resource "aws_launch_configuration" "example" {
  #utilizziamo una AMI gratuita di un server Ubuntu 20.04 disponibile per la nostra regione
  image_id = "ami-0b74d52f736d963d1"
  #utilizziamo un'istanza t3 a scopi generici, ovvero a prestazioni espandibili in un range basso-medio
  instance_type = var.instance_type
  #permettiamo l'accesso solo al nostro security group
  security_groups = [aws_security_group.instance.id]

  #utilizziamo lo script bash
  user_data = data.template_file.user_data.rendered

  #Nel momento in cui andassimo a cambiare qualche parametro, terraform proverà a rimpiazzare l'istanza
  #andando prima a eliminare la vecchia versione per poi creare la nuova, ma dato che l'ASG
  #fa riferimento alla vecchia versione non sarebbe in grado di eliminarla. Per risolvere il problema
  #dobbiamo prima creare e poi distruggere intervenendo su quello che è il "lifecycle"
  lifecycle {
    create_before_destroy = true
  }
}

#per permettere traffico verso la nostra EC2 instance dobbiamo creare un "security group"
resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"
}

resource "aws_security_group_rule" "allow_server_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instance.id

  from_port   = var.server_port
  to_port     = var.server_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}



resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name  #gli passiamo la nostra configurazione
  #utilizziamo le sunets della nostra VPC di Default
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn] #in questo modo il target group dell'ALB saprà quali istanze "guardare"
  health_check_type = "ELB" #controllo robusto l'istanza verrà segnata unhealthy non solo quando
                            #sarà down ma anche qaundo avrà finito memoria, avrà smesso di serviere richieste etc..

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key = "Name"
    value = var.cluster_name
    propagate_at_launch = true
  }
}


#Ora per permettere a terraform di conservare il tfstate nel bucket abbaimo bisogno di configurare il beckend
terraform {
  backend "s3" {
    bucket = "terraform-n46-state"
    key = "stage/webserver-cluster/terraform.tfstate" #il path in cui conservarlo, riproduciamo la nostra cartella locale
    region = "eu-south-1"
    dynamodb_table = "terraform-n46-locks"
    encrypt = true
    skip_region_validation = true   #da HashiCorp non è stato ancora rilasciato supporto per questa region, quindi dobbaimo aggirare la verifica
  }
}

#facciamo in modo che il cluster legga dallo state file del mio database
#come per i data, anche questo è read-only quindi non creaimo rischi di problemi al database stesso
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key = var.db_remote_state_key
    region = "eu-south-1"
    skip_region_validation = true
  }
}


data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh") #in questo modo va a prendersi il file da dove sta eseguendo

  vars = {
    server_port = var.server_port
    db_address = data.terraform_remote_state.db.outputs.address
    db_port = data.terraform_remote_state.db.outputs.port
  }
}


#LOAD BALANCING----------------------

#Ora abbiamo più server con più ip pubblici ma ai nostri utenti vorremmo fornire un unico indirizzo
#per farlo abbiamo bisogno di un Load Balancer sfruttando l' Aamazon Elastic Load Balancer (ELB)
# che è formato da un Listener, Listener-rule e Target Group

#ALB

resource "aws_lb" "example" {
  name = var.cluster_name
  load_balancer_type = "application"  #scegliamo come tipologia qeuella rivolta alle applicazioni
  subnets = data.aws_subnet_ids.default.ids  #passiamo la nostra subnet
  security_groups = [aws_security_group.alb.id]
}


#Listener

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn #lo collegiamo al nostro ALB
  port = local.http_port
  protocol = "HTTP"

  #di default ritorno una pagina 404
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }

}


#in generale le risorse AWS non consentono in/out traffico, quindi abbiamo bisogno di un security group
resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

 #Consente richieste HTTP in entrata
  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id
  #Consente tutte le richieste in uscita
  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}


#Target Group
resource "aws_lb_target_group" "asg" {
  name = var.cluster_name
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  #il target group controllerà lo stato della nostra istanza, nel momento in cui
  #qualcosa andrà storto verrà marcata come "unhelthy" e sarà stoppato il traffico verso di essa
  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

#Listener Rule
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn  #colleghiamo il nostro listener_arn
  priority = 100

  #manda richieste che combaciano con qualsiasi path del nostro target group
  condition {
    field = "path-pattern"
    values = ["*"]
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}


locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"] #tutti gli ip
}
