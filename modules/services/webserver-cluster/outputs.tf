output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "Il Domain Name del Load Balancer"
}
#ci serve per poter scalare in produzione la nostra infrastruttura
output "asg_name" {
  value       = aws_autoscaling_group.example.name
  description = "Il nome dell'Auto Scaling Group"
}

#in questo modo nelle nostre varie fasi potremmo aggiungere e testare anche altre porte
output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "l' ID del Security Group del load balancer"
}
