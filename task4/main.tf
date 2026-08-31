terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.128.0"
    }
  }
}

# Аутентификация через авторизованный ключ сервисного аккаунта terraform-sa
provider "yandex" {
  folder_id = var.folder_id
  zone      = var.zone

  service_account_key_file = "/home/user/key.json"

  # Статические ключи для Object Storage
  storage_access_key = var.storage_access_key
  storage_secret_key = var.storage_secret_key
}

# ------------------------------------------------------------------
# Сеть: VPC + подсети по доменам (см. Задания 1–2)
# ------------------------------------------------------------------

resource "yandex_vpc_network" "main" {
  name = "${var.project}-${var.env}-network"
}

# NAT-шлюз: приватные подсети выходят в интернет, но недоступны извне
resource "yandex_vpc_gateway" "nat" {
  name = "${var.project}-${var.env}-egress-nat"
  shared_egress_gateway {}
}

# Таблица маршрутизации для выхода в интернет через NAT
resource "yandex_vpc_route_table" "nat_rt" {
  name       = "${var.project}-${var.env}-nat-rt"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

resource "yandex_vpc_subnet" "platform" {
  name           = "${var.project}-${var.env}-platform"
  network_id     = yandex_vpc_network.main.id
  zone           = var.zone
  v4_cidr_blocks = ["10.0.1.0/24"]
  route_table_id = yandex_vpc_route_table.nat_rt.id
}

resource "yandex_vpc_subnet" "clinics" {
  name           = "${var.project}-${var.env}-clinics"
  network_id     = yandex_vpc_network.main.id
  zone           = var.zone
  v4_cidr_blocks = ["10.0.2.0/24"]
  route_table_id = yandex_vpc_route_table.nat_rt.id
}

resource "yandex_vpc_subnet" "fintech" {
  name           = "${var.project}-${var.env}-fintech"
  network_id     = yandex_vpc_network.main.id
  zone           = var.zone
  v4_cidr_blocks = ["10.0.3.0/24"]
  route_table_id = yandex_vpc_route_table.nat_rt.id
}

resource "yandex_vpc_subnet" "ai" {
  name           = "${var.project}-${var.env}-ai"
  network_id     = yandex_vpc_network.main.id
  zone           = var.zone
  v4_cidr_blocks = ["10.0.4.0/24"]
  route_table_id = yandex_vpc_route_table.nat_rt.id
}

# ------------------------------------------------------------------
# Группы безопасности: минимальные привилегии
# ------------------------------------------------------------------

resource "yandex_vpc_security_group" "public_sg" {
  name       = "${var.project}-${var.env}-public-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    description    = "HTTPS к порталу самообслуживания"
    v4_cidr_blocks = [var.allowed_public_cidr]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP к порталу самообслуживания"
    v4_cidr_blocks = [var.allowed_public_cidr]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH только из корпоративной сети"
    v4_cidr_blocks = [var.corporate_cidr]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Исходящий трафик через NAT"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "internal_sg" {
  name       = "${var.project}-${var.env}-internal-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    description    = "Сервисные порты внутри VPC (PG, Kafka, ClickHouse)"
    v4_cidr_blocks = ["10.0.0.0/16"]
    from_port      = 5432
    to_port        = 9092
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH только из корпоративной сети"
    v4_cidr_blocks = [var.corporate_cidr]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Исходящий трафик через NAT"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Статический публичный IP — только для портала
resource "yandex_vpc_address" "portal" {
  name = "${var.project}-${var.env}-portal-ip"
  external_ipv4_address {
    zone_id = var.zone
  }
}

# ------------------------------------------------------------------
# Образ ОС
# ------------------------------------------------------------------

data "yandex_compute_image" "ubuntu" {
  family    = "ubuntu-2204-lts"
  folder_id = "standard-images"
}

# ------------------------------------------------------------------
# Диски данных (отдельно от boot)
# ------------------------------------------------------------------

resource "yandex_compute_disk" "portal_data" {
  name = "${var.project}-${var.env}-portal-data"
  type = "network-ssd"
  size = var.portal_data_disk_size
}

resource "yandex_compute_disk" "analytics_data" {
  name = "${var.project}-${var.env}-analytics-data"
  type = "network-ssd"
  size = var.analytics_data_disk_size
}

# ------------------------------------------------------------------
# Виртуальные машины
# ------------------------------------------------------------------

# Портал самообслуживания «витрина данных» — единственный публичный узел
resource "yandex_compute_instance" "portal" {
  name        = "${var.project}-${var.env}-portal"
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = var.vm_sizes["portal"].cores
    memory = var.vm_sizes["portal"].memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-ssd"
      size     = var.boot_disk_size
    }
  }

  secondary_disk {
    disk_id = yandex_compute_disk.portal_data.id
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.platform.id
    security_group_ids = [yandex_vpc_security_group.public_sg.id]
    nat                = true
    nat_ip_address     = yandex_vpc_address.portal.external_ipv4_address[0].address
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
  }
}

# Аналитический узел (демо MPP-хранилища витрин) — приватный
resource "yandex_compute_instance" "analytics" {
  name        = "${var.project}-${var.env}-analytics"
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = var.vm_sizes["analytics"].cores
    memory = var.vm_sizes["analytics"].memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-ssd"
      size     = var.boot_disk_size
    }
  }

  secondary_disk {
    disk_id = yandex_compute_disk.analytics_data.id
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.platform.id
    security_group_ids = [yandex_vpc_security_group.internal_sg.id]
    nat                = false
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
  }
}

# Узел интеграционной шины (Kafka) — приватный
resource "yandex_compute_instance" "integration" {
  name        = "${var.project}-${var.env}-integration"
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = var.vm_sizes["integration"].cores
    memory = var.vm_sizes["integration"].memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-ssd"
      size     = var.boot_disk_size
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.platform.id
    security_group_ids = [yandex_vpc_security_group.internal_sg.id]
    nat                = false
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
  }
}

# ------------------------------------------------------------------
# Озеро данных (Bronze) — Object Storage
# ------------------------------------------------------------------

resource "yandex_storage_bucket" "lake" {
  bucket = "${var.project}-${var.env}-data-lake"
  acl    = "private"
}

# ------------------------------------------------------------------
# Управляемая БД домена «Клиники» (PostgreSQL)
# ------------------------------------------------------------------

resource "yandex_mdb_postgresql_cluster" "clinics" {
  name                = "${var.project}-${var.env}-clinics-db"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.main.id
  deletion_protection = false

  config {
    version = 16
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 20
    }
  }

  host {
    zone             = var.zone
    subnet_id        = yandex_vpc_subnet.clinics.id
    assign_public_ip = false
  }
}

# Пользователь создаётся до базы; блок permission не нужен:
# владелец базы (owner ниже) автоматически получает полные права
resource "yandex_mdb_postgresql_user" "clinics_app" {
  cluster_id = yandex_mdb_postgresql_cluster.clinics.id
  name       = "clinics_app"
  password   = var.db_password
}

resource "yandex_mdb_postgresql_database" "clinics_db" {
  cluster_id = yandex_mdb_postgresql_cluster.clinics.id
  name       = "clinics"
  owner      = yandex_mdb_postgresql_user.clinics_app.name
}