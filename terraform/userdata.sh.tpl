#!/bin/bash
# ==============================================================================
# DIGITALFIX - USER DATA (bootstrap de la EC2)
# ==============================================================================
# Este script se ejecuta como root al primer inicio de la instancia.
# Log completo en: /var/log/digitalfix-bootstrap.log
# ==============================================================================
set -euo pipefail
exec > >(tee /var/log/digitalfix-bootstrap.log | logger -t digitalfix-bootstrap) 2>&1

echo "======================================================"
echo " DigitalFix Bootstrap - $(date)"
echo "======================================================"

# ------------------------------------------------------------------------------
# 1. Actualizar el sistema e instalar dependencias
# ------------------------------------------------------------------------------
echo "==> [1/6] Actualizando paquetes del sistema..."
dnf update -y

echo "==> [1/6] Instalando Docker, Git y utilidades..."
dnf install -y docker git

# Habilitar y arrancar Docker
systemctl enable docker
systemctl start docker

# Instalar Docker Compose plugin (v2)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Agregar ec2-user al grupo docker para que pueda correr docker sin sudo
usermod -aG docker ec2-user

echo "==> Docker $(docker --version)"
echo "==> Docker Compose $(docker compose version)"

# ------------------------------------------------------------------------------
# 2. Crear estructura de directorios
# ------------------------------------------------------------------------------
echo "==> [2/6] Creando directorio /home/ec2-user/DigitalFix..."
APP_DIR="/home/ec2-user/DigitalFix"
mkdir -p "$APP_DIR"

# ------------------------------------------------------------------------------
# 3. Clonar digitalfix-infrastructure (rama deploy)
# ------------------------------------------------------------------------------
echo "==> [3/6] Clonando digitalfix-infrastructure (rama deploy)..."
git clone --branch deploy --single-branch \
  "${git_repo_infrastructure}" \
  "$APP_DIR/digitalfix-infrastructure"

# ------------------------------------------------------------------------------
# 4. Clonar repos de microservicios y frontend (rama deploy)
# ------------------------------------------------------------------------------
echo "==> [4/6] Clonando repositorios de servicios (rama deploy)..."
%{ for name, url in git_repos ~}
echo "    -> Clonando ${name}..."
git clone --branch deploy --single-branch "${url}" "$APP_DIR/${name}" || \
  echo "WARN: No se pudo clonar ${name}, continuando..."
%{ endfor ~}

# ------------------------------------------------------------------------------
# 5. Escribir el archivo .env centralizado
# ------------------------------------------------------------------------------
echo "==> [5/6] Escribiendo .env en digitalfix-infrastructure..."
cat > "$APP_DIR/digitalfix-infrastructure/.env" <<'ENVEOF'
# ==============================================================================
# DIGITALFIX - VARIABLES DE ENTORNO (generado por Terraform)
# ==============================================================================

# --- Base de Datos Oracle Autonomous (OCI) ---
SPRING_DATASOURCE_URL=${spring_datasource_url}
SPRING_DATASOURCE_USERNAME=${spring_datasource_username}
SPRING_DATASOURCE_PASSWORD=${spring_datasource_password}
DB_URL=${spring_datasource_url}
DB_USERNAME=${spring_datasource_username}
DB_PASSWORD=${spring_datasource_password}

# --- Microsoft Entra ID ---
AZURE_TENANT_ID=${azure_tenant_id}
AZURE_CLIENT_ID=${azure_client_id}

# --- CORS (se actualiza con la IP publica de la EC2 al arrancar) ---
CORS_ALLOWED_ORIGINS=http://PUBLIC_IP_PLACEHOLDER:${frontend_port},http://localhost:${frontend_port}

# --- Puertos ---
FRONTEND_PORT=${frontend_port}
BFF_PORT=${bff_port}

# --- RabbitMQ ---
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_ADDRESSES=rabbitmq-node1:5672,rabbitmq-node2:5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_USERNAME=admin
RABBITMQ_PASSWORD=${rabbitmq_password}
RABBITMQ_VIRTUAL_HOST=/
RABBITMQ_ERLANG_COOKIE=${rabbitmq_erlang_cookie}
RABBITMQ_NODE2_MANAGEMENT_PORT=15673

# --- SMTP ---
SPRING_MAIL_HOST=${spring_mail_host}
SPRING_MAIL_PORT=${spring_mail_port}
SPRING_MAIL_USERNAME=${spring_mail_username}
SPRING_MAIL_PASSWORD=${spring_mail_password}

# --- JVM ---
JAVA_OPTS=-Djava.net.preferIPv4Stack=true
ENVEOF

# Reemplazar el placeholder de IP con la IP pública real de la instancia
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
sed -i "s/PUBLIC_IP_PLACEHOLDER/$PUBLIC_IP/g" "$APP_DIR/digitalfix-infrastructure/.env"
echo "    IP publica detectada: $PUBLIC_IP"

# Ajustar permisos
chown -R ec2-user:ec2-user "$APP_DIR"

# ------------------------------------------------------------------------------
# 6. Levantar la plataforma completa con Docker Compose
# ------------------------------------------------------------------------------
echo "==> [6/6] Ejecutando docker compose up -d --build..."
cd "$APP_DIR/digitalfix-infrastructure"
docker compose up -d --build

echo ""
echo "======================================================"
echo " DigitalFix Bootstrap COMPLETO - $(date)"
echo " Frontend:  http://$PUBLIC_IP:${frontend_port}"
echo " BFF:       http://$PUBLIC_IP:${bff_port}"
echo " RabbitMQ:  http://$PUBLIC_IP:15672"
echo "======================================================"
