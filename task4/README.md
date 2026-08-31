# Задание 4. Облачная инфраструктура IaaS + Terraform (Yandex Cloud)

Провайдер: **Yandex Cloud** (`yandex-cloud/yandex` v0.128.0, регион `ru-central1-a`). Конфигурация развёртывает инфраструктурный слой целевой архитектуры из Заданий 1–3 (всего 19 ресурсов):

- VPC с 4 подсетями по доменам: `platform`, `clinics`, `fintech`, `ai`;
- NAT-шлюз (`shared_egress_gateway`) + таблица маршрутизации со статическим маршрутом `0.0.0.0/0` — приватные подсети выходят в интернет, но недоступны извне;
- security groups с минимальными привилегиями (SSH только из корпоративной сети, сервисные порты только внутри VPC);
- статический публичный IP — только у портала самообслуживания;
- 3 ВМ: `portal` (4 vCPU/8 ГБ + 50 ГБ), `analytics` (8 vCPU/16 ГБ + 200 ГБ), `integration` (4 vCPU/8 ГБ);
- отдельные data-диски `network-ssd`;
- Object Storage bucket — озеро данных Bronze (private);
- Managed PostgreSQL 16 (`s2.micro`, 20 ГБ) — БД домена «Клиники» в приватной подсети; кластер, база и пользователь описаны отдельными ресурсами (`yandex_mdb_postgresql_cluster` / `_database` / `_user`).

## Предварительные требования

1. Terraform ≥ 1.5.
2. Yandex Cloud CLI: `yc init` (облако, каталог `default`, зона `ru-central1-a`).
3. Привязанный платёжный аккаунт (активирует стартовый грант; после `destroy` расходы остаются в гранте).

## Подготовка (один раз)

```bash
# 1. Сервисный аккаунт и ключи
yc iam service-account create --name terraform-sa --role editor
yc iam access-key create --service-account-name terraform-sa        # key_id/secret -> tfvars (Object Storage)
yc iam key create --service-account-name terraform-sa --output ~/key.json   # авторизованный ключ провайдера

# 2. Провайдер: registry.terraform.io недоступен, поэтому v0.128.0 ставится в локальное filesystem-зеркало
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/yandex-cloud/yandex/0.128.0/linux_amd64
cd ~/.terraform.d/plugins/registry.terraform.io/yandex-cloud/yandex/0.128.0/linux_amd64
curl -L -O https://github.com/yandex-cloud/terraform-provider-yandex/releases/download/v0.128.0/terraform-provider-yandex_0.128.0_linux_amd64.zip
unzip terraform-provider-yandex_0.128.0_linux_amd64.zip
rm terraform-provider-yandex_0.128.0_linux_amd64.zip
chmod +x terraform-provider-yandex*

cat > ~/.terraformrc << 'EOF'
provider_installation {
  filesystem_mirror {
    path    = "/home/user/.terraform.d/plugins"
    include = ["yandex-cloud/yandex"]
  }
  direct {
    exclude = ["yandex-cloud/yandex"]
  }
}
EOF

# 3. Значения для tfvars
yc config list                 # folder_id
curl -s https://api.ipify.org  # внешний IP -> corporate_cidr = "IP/32"
cat ~/.ssh/id_ed25519.pub      # ssh_public_key