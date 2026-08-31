# Задание 4. Облачная инфраструктура IaaS + Terraform (локально, LocalStack)

Провайдер: AWS (эмуляция LocalStack). Состав: VPC с подсетями по доменам, Internet Gateway + NAT Gateway, security groups, EIP портала, 3 EC2 (портал, аналитика, интеграционная шина), EBS-диски данных, S3-бакет озера данных, RDS PostgreSQL домена «Клиники».

## Запуск

1. Установите Docker и Terraform ≥ 1.5.
2. Запустите LocalStack:

```bash
docker compose up -d
curl http://localhost:4566/_localstack/health   # проверка готовности