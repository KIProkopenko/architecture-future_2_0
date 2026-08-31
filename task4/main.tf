terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Все запросы уходят в локальный LocalStack, а не в реальное облако
provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = var.region

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    ec2 = "http://localhost:4566"
    s3  = "http://localhost:4566"
    rds = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

# ------------------------------------------------------------------
# Сеть: VPC + подсети по доменам (см. Задания 1–2)
# ------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "${var.project}-${var.env}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-${var.env}-igw" }
}

# Публичная подсеть домена «Платформа»: портал + NAT-шлюз
resource "aws_subnet" "public_platform" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project}-${var.env}-public-platform" }
}

# Приватные подсети: выход в интернет только через NAT
resource "aws_subnet" "private_platform" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "${var.project}-${var.env}-private-platform" }
}

resource "aws_subnet" "clinics_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "${var.project}-${var.env}-clinics-a" }
}

resource "aws_subnet" "clinics_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.region}b"
  tags              = { Name = "${var.project}-${var.env}-clinics-b" }
}

resource "aws_subnet" "fintech" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "${var.project}-${var.env}-fintech" }
}

resource "aws_subnet" "ai" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "${var.project}-${var.env}-ai" }
}

# NAT-шлюз: приватные узлы ходят наружу (обновления, внешние API),
# но недоступны из интернета — мед- и финконтур не выставляются наружу
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project}-${var.env}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_platform.id
  tags          = { Name = "${var.project}-${var.env}-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project}-${var.env}-rt-public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.project}-${var.env}-rt-private" }
}

resource "aws_route_table_association" "public_platform" {
  subnet_id      = aws_subnet.public_platform.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_platform" {
  subnet_id      = aws_subnet.private_platform.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "clinics_a" {
  subnet_id      = aws_subnet.clinics_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "clinics_b" {
  subnet_id      = aws_subnet.clinics_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "fintech" {
  subnet_id      = aws_subnet.fintech.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "ai" {
  subnet_id      = aws_subnet.ai.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------
# Группы безопасности: минимальные привилегии
# ------------------------------------------------------------------

resource "aws_security_group" "public_sg" {
  name        = "${var.project}-${var.env}-public-sg"
  description = "Публичный доступ только к порталу"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS к порталу самообслуживания"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_public_cidr]
  }

  ingress {
    description = "HTTP к порталу самообслуживания"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_public_cidr]
  }

  ingress {
    description = "SSH только из корпоративной сети"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.corporate_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.env}-public-sg" }
}

resource "aws_security_group" "internal_sg" {
  name        = "${var.project}-${var.env}-internal-sg"
  description = "Сервисные порты только внутри VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL/Kafka/ClickHouse внутри VPC"
    from_port   = 5432
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SSH только из корпоративной сети"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.corporate_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.env}-internal-sg" }
}

# Статический публичный IP — только для портала
resource "aws_eip" "portal" {
  domain = "vpc"
  tags   = { Name = "${var.project}-${var.env}-portal-eip" }
}

# ------------------------------------------------------------------
# SSH-ключ
# ------------------------------------------------------------------

resource "aws_key_pair" "deploy" {
  key_name   = "${var.project}-${var.env}-key"
  public_key = var.ssh_public_key
}

# ------------------------------------------------------------------
# Диски данных (отдельно от boot — меняются без пересоздания ВМ)
# ------------------------------------------------------------------

resource "aws_ebs_volume" "portal_data" {
  availability_zone = "${var.region}a"
  size              = var.portal_data_disk_size
  type              = "gp2"
  tags              = { Name = "${var.project}-${var.env}-portal-data" }
}

resource "aws_ebs_volume" "analytics_data" {
  availability_zone = "${var.region}a"
  size              = var.analytics_data_disk_size
  type              = "gp2"
  tags              = { Name = "${var.project}-${var.env}-analytics-data" }
}

# ------------------------------------------------------------------
# Виртуальные машины (EC2)
# ------------------------------------------------------------------

# Портал самообслуживания «витрина данных» — единственный публичный узел
resource "aws_instance" "portal" {
  ami                    = var.ami_id
  instance_type          = var.instance_types["portal"]
  subnet_id              = aws_subnet.public_platform.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = aws_key_pair.deploy.key_name

  root_block_device {
    volume_size = var.boot_disk_size
    volume_type = "gp2"
  }

  tags = { Name = "${var.project}-${var.env}-portal" }
}

resource "aws_volume_attachment" "portal_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.portal_data.id
  instance_id = aws_instance.portal.id
}

resource "aws_eip_association" "portal" {
  instance_id   = aws_instance.portal.id
  allocation_id = aws_eip.portal.id
}

# Аналитический узел (демо MPP-хранилища витрин) — приватный
resource "aws_instance" "analytics" {
  ami                    = var.ami_id
  instance_type          = var.instance_types["analytics"]
  subnet_id              = aws_subnet.private_platform.id
  vpc_security_group_ids = [aws_security_group.internal_sg.id]
  key_name               = aws_key_pair.deploy.key_name

  root_block_device {
    volume_size = var.boot_disk_size
    volume_type = "gp2"
  }

  tags = { Name = "${var.project}-${var.env}-analytics" }
}

resource "aws_volume_attachment" "analytics_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.analytics_data.id
  instance_id = aws_instance.analytics.id
}

# Узел интеграционной шины (Kafka) — приватный
resource "aws_instance" "integration" {
  ami                    = var.ami_id
  instance_type          = var.instance_types["integration"]
  subnet_id              = aws_subnet.private_platform.id
  vpc_security_group_ids = [aws_security_group.internal_sg.id]
  key_name               = aws_key_pair.deploy.key_name

  root_block_device {
    volume_size = var.boot_disk_size
    volume_type = "gp2"
  }

  tags = { Name = "${var.project}-${var.env}-integration" }
}

# ------------------------------------------------------------------
# Озеро данных (Bronze) — S3
# ------------------------------------------------------------------

resource "aws_s3_bucket" "lake" {
  bucket = "${var.project}-${var.env}-data-lake"
  tags   = { Name = "${var.project}-${var.env}-data-lake" }
}

# ------------------------------------------------------------------
# Управляемая БД домена «Клиники» (RDS PostgreSQL)
# ------------------------------------------------------------------

resource "aws_db_subnet_group" "clinics" {
  name       = "${var.project}-${var.env}-clinics-db-subnets"
  subnet_ids = [aws_subnet.clinics_a.id, aws_subnet.clinics_b.id]
  tags       = { Name = "${var.project}-${var.env}-clinics-db-subnets" }
}

resource "aws_db_instance" "clinics" {
  identifier             = "${var.project}-${var.env}-clinics-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_storage_gb
  db_name                = "clinics"
  username               = "clinics_admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.clinics.name
  vpc_security_group_ids = [aws_security_group.internal_sg.id]
  publicly_accessible    = false
  multi_az               = false
  skip_final_snapshot    = true

  tags = { Name = "${var.project}-${var.env}-clinics-db" }
}