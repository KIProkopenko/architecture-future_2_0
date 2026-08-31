output "portal_public_ip" {
  description = "Публичный IP портала самообслуживания"
  value       = aws_eip.portal.public_ip
}

output "vm_private_ips" {
  description = "Приватные IP виртуальных машин"
  value = {
    portal      = aws_instance.portal.private_ip
    analytics   = aws_instance.analytics.private_ip
    integration = aws_instance.integration.private_ip
  }
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = {
    public_platform  = aws_subnet.public_platform.id
    private_platform = aws_subnet.private_platform.id
    clinics_a        = aws_subnet.clinics_a.id
    clinics_b        = aws_subnet.clinics_b.id
    fintech          = aws_subnet.fintech.id
    ai               = aws_subnet.ai.id
  }
}

output "nat_gateway_id" {
  value = aws_nat_gateway.nat.id
}

output "data_lake_bucket" {
  value = aws_s3_bucket.lake.bucket
}

output "clinics_db_endpoint" {
  value = aws_db_instance.clinics.endpoint
}