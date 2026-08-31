variable "folder_id" {
  description = "ID каталога Yandex Cloud (yc config list)"
  type        = string
}

variable "zone" {
  description = "Зона доступности"
  type        = string
  default     = "ru-central1-a"
}

variable "project" {
  description = "Префикс имён ресурсов"
  type        = string
  default     = "future20"
}

variable "env" {
  description = "Окружение"
  type        = string
  default     = "dev"
}

variable "corporate_cidr" {
  description = "CIDR вашей сети для SSH (узнайте свой внешний IP, например на 2ip.ru, и добавьте /32)"
  type        = string
}

variable "allowed_public_cidr" {
  description = "Кому разрешён доступ к порталу"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vm_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ (cat ~/.ssh/id_ed25519.pub)"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Пароль пользователя БД клиник"
  type        = string
  sensitive   = true
}

variable "storage_access_key" {
  description = "Статический ключ доступа к Object Storage"
  type        = string
  sensitive   = true
}

variable "storage_secret_key" {
  description = "Секретный ключ Object Storage"
  type        = string
  sensitive   = true
}

variable "boot_disk_size" {
  type    = number
  default = 30
}

variable "portal_data_disk_size" {
  type    = number
  default = 50
}

variable "analytics_data_disk_size" {
  type    = number
  default = 200
}

variable "vm_sizes" {
  description = "Размеры ВМ: portal 4/8, analytics 8/16, integration 4/8"
  type = map(object({
    cores  = number
    memory = number
  }))
  default = {
    portal      = { cores = 4, memory = 8 }
    analytics   = { cores = 8, memory = 16 }
    integration = { cores = 4, memory = 8 }
  }
}