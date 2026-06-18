variable "TEST_RUN_ID" {
  default = "detached"
}

provider "aws" {
  default_tags {
    tags = {
      environment  = var.ENVIRONMENT
      repo         = var.REPO
      branch       = var.BRANCH
      build        = var.BUILD_ID
      created_date = var.CREATED_DATE
    }
  }
}

resource "aws_s3_bucket" "kolide" {
  bucket = "elastic-package-kolide-auth-bucket-${var.TEST_RUN_ID}"
}

resource "aws_sqs_queue" "kolide_queue" {
  name   = "elastic-package-kolide-auth-queue-${var.TEST_RUN_ID}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:*:*:elastic-package-kolide-auth-queue-${var.TEST_RUN_ID}",
      "Condition": {
        "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.kolide.arn}" }
      }
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_notification" "kolide_notification" {
  bucket = aws_s3_bucket.kolide.id

  queue {
    queue_arn = aws_sqs_queue.kolide_queue.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.kolide.id
  key    = "auth_logs/test-auth.log"
  source = "./files/test-auth.log"

  etag       = filemd5("./files/test-auth.log")
  depends_on = [aws_s3_bucket_notification.kolide_notification]
}

output "queue_url" {
  value = aws_sqs_queue.kolide_queue.url
}
