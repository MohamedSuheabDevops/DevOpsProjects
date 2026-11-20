# ---- Appointments service: DynamoDB (NoSQL) ----
resource "aws_dynamodb_table" "appointments" {
  name         = "${var.project}-appointments"
  billing_mode = "PAY_PER_REQUEST"      # no capacity planning
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "patientId"
    type = "S"
  }

  global_secondary_index {
    name            = "idx_global_patientId"
    hash_key        = "patientId"
    projection_type = "ALL"
  }
}

# ---- Booking events: SQS queue with a dead-letter queue (used by booking and billing) ----
resource "aws_sqs_queue" "booking_events_dlq" {
  name                      = "${var.project}-booking-events-dlq"
  message_retention_seconds = 1209600   # 14 days
}

resource "aws_sqs_queue" "booking_events" {
  name                       = "${var.project}-booking-events"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 10        # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.booking_events_dlq.arn
    maxReceiveCount     = 3             # after 3 failed receives, move to the DLQ
  })
}
