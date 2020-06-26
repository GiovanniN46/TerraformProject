output "address" {
  value       = aws_db_instance.example.address
  description = "Connette il Database a questo endpoint"
}

output "port" {
  value       = aws_db_instance.example.port
  description = "La porta su cui il Database ascolta"
}
