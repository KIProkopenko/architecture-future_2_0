# Задание 4. Облачная инфраструктура IaaS + Terraform (Yandex Cloud)

Провайдер: **Yandex Cloud** (регион `ru-central1-a`). Конфигурация развёртывает инфраструктурный слой целевой архитектуры из Заданий 1–3:

- VPC с 4 подсетями по доменам: `platform`, `clinics`, `fintech`, `ai`;
- NAT-шлюз (`shared_egress_gateway`) — приватные подсети выходят в интернет, но недоступны извне;
- security groups с минимальными привилегиями (SSH только из корпоративной сети, сервисные порты только внутри VPC);
- статический публичный IP — только у портала самообслуживания;
- 3 ВМ: `portal` (4 vCPU/8 ГБ + 50 ГБ), `analytics` (8 vCPU/16 ГБ + 200 ГБ), `integration` (4 vCPU/8 ГБ);
- отдельные data-диски `network-ssd`;
- Object Storage bucket — озеро данных Bronze (private);
- Managed PostgreSQL 16 (`s2.micro`, 20 ГБ) — БД домена «Клиники» в приватной подсети.

## Предварительные требования

1. Terraform ≥ 1.5.
2. Yandex Cloud CLI (`yc init`: облако `cloud-nimbus-251`, каталог `default`, зона `ru-central1-a`).
3. Привязанный платёжный аккаунт (активирует стартовый грант; после `destroy` расходы остаются в гранте).

## Подготовка (выполняется один раз)

```bash
# 1. Сервисный аккаунт и статические ключи для Object Storage
yc iam service-account create --name terraform-sa --role editor
yc iam access-key create --service-account-name terraform-sa   # key_id и secret -> в tfvars

# 2. Зеркало провайдера (установка из РФ)
cat > ~/.terraformrc << 'EOF'
provider_installation {
  network_mirror {
    url     = "https://mirror.yandex.ru/terraform-providers/"
    include = ["yandex-cloud/yandex"]
  }
  direct {
    exclude = ["yandex-cloud/yandex"]
  }
}
EOF

# 3. Значения для tfvars
yc config list                 # folder_id
curl -s https://api.ipify.org  # ваш внешний IP -> corporate_cidr = "IP/32"
cat ~/.ssh/id_ed25519.pub      # ssh_public_key (при отсутствии: ssh-keygen -t ed25519)