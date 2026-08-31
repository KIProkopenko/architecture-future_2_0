variable "region" {
  description = "Регион (для LocalStack любой, например us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Префикс имён ресурсов"
  type        = string
  default     = "future20"
}

variable "env" {
  description = "Окружение (dev / test / prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR всей VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "corporate_cidr" {
  description = "CIDR корпоративной сети для SSH"
  type        = string
}

variable "allowed_public_cidr" {
  description = "Кому разрешён доступ к порталу"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ami_id" {
  description = "AMI для ВМ (LocalStack не валидирует; для реального AWS подставьте актуальный Ubuntu 22.04)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0"
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ для доступа к ВМ"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Пароль администратора БД клиник"
  type        = string
  sensitive   = true
}

variable "boot_disk_size" {
  description = "Размер загрузочного диска, ГБ"
  type        = number
  default     = 30
}

variable "portal_data_disk_size" {
  description = "Диск данных портала, ГБ"
  type        = number
  default     = 50
}

variable "analytics_data_disk_size" {
  description = "Диск данных аналитики, ГБ"
  type        = number
  default     = 200
}

variable "instance_types" {
  description = "Типы инстансов по ролям (c5.xlarge = 4 vCPU/8 ГБ, c5.2xlarge = 8 vCPU/16 ГБ)"
  type        = map(string)
  default = {
    portal      = "c5.xlarge"
    analytics   = "c5.2xlarge"
    integration = "c5.xlarge"
  }
}

variable "db_instance_class" {
  description = "Класс инстанса RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_storage_gb" {
  description = "Объём диска RDS, ГБ"
  type        = number
  default     = 20
}