output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_bucket" {
  value = aws_s3_bucket.private_data.id
}

output "public_bucket" {
  value = aws_s3_bucket.public_website.id
}
