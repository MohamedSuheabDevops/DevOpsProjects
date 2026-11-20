output "appointments_table" {
  value = aws_dynamodb_table.appointments.name
}

output "booking_events_queue_url" {
  value = aws_sqs_queue.booking_events.url
}

output "booking_events_dlq_arn" {
  value = aws_sqs_queue.booking_events_dlq.arn
}

output "doctors_mysql_endpoint" {
  value = var.create_rds ? aws_db_instance.doctors_mysql[0].address : null
}

output "billing_postgres_endpoint" {
  value = var.create_rds ? aws_db_instance.billing_postgres[0].address : null
}

output "redis_endpoint" {
  value = var.create_elasticache ? aws_elasticache_replication_group.booking[0].primary_endpoint_address : null
}
