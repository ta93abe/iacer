output "role_arn" {
  description = "ARN for trust relationship role"
  value       = aws_iam_role.iacer_role.arn
}
