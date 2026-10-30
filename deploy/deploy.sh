#!/usr/bin/env bash
# ==============================================================================
# DIGITALFIX - SCRIPT CENTRALIZADO DE DESPLIEGUE (AWS EC2 / DOCKER COMPOSE)
# ==============================================================================
# Uso:
#   ./deploy.sh [servicio] [rama] [actualizar_codigo]
#
# Ejemplos:
#   ./deploy.sh all deploy true         # Despliega toda la plataforma actualizando código
#   ./deploy.sh frontend deploy true    # Despliega solo el frontend
#   ./deploy.sh bff-gateway deploy true # Despliega solo el BFF Gateway
#   ./deploy.sh ms-login deploy false   # Reconstruye ms-login sin hacer git pull
#
# Servicios disponibles:
#   all, frontend, bff-gateway, ms-login, ms-user, ms-workorders,
#   ms-catalog, ms-notify, ms-admin-queues, rabbitmq
# ==============================================================================

set -euo pipefail

TARGET_SERVICE="${1:-all}"
TARGET_BRANCH="${2:-deploy}"
UPDATE_CODE="${3:-true}"

echo "======================================================================"
echo " DigitalFix - Despliegue Centralizado"
echo " Fecha:      $(date '+%Y-%m-%d %H:%M:%S')"
echo " Servicio:   ${TARGET_SERVICE}"
echo " Rama:       ${TARGET_BRANCH}"
echo " Git Update: ${UPDATE_CODE}"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Resolver directorios
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "deploy" ]; then
  INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  INFRA_DIR="$SCRIPT_DIR"
fi
BASE_DIR="$(cd "$INFRA_DIR/.." && pwd)"

echo "==> Directorio base:           ${BASE_DIR}"
echo "==> Directorio infraestructura: ${INFRA_DIR}"

# ------------------------------------------------------------------------------
# 2. Mapeo de repositorios y servicios
# ------------------------------------------------------------------------------
get_repo_name_for_service() {
  case "$1" in
    frontend)        echo "digitalfix-frontend" ;;
    bff-gateway)     echo "digitalfix-bff-gateway" ;;
    ms-login)        echo "digitalfix-ms-login" ;;
    ms-user)         echo "digitalfix-ms-user" ;;
    ms-workorders)   echo "digitalfix-ms-workorders" ;;
    ms-catalog)      echo "digitalfix-ms-catalog" ;;
    ms-notify)       echo "digitalfix-ms-notify" ;;
    ms-admin-queues) echo "digitalfix-ms-admin-queues" ;;
    rabbitmq)        echo "digitalfix-infrastructure" ;;
    *)               echo "" ;;
  esac
}

get_repo_url() {
  case "$1" in
    digitalfix-infrastructure) echo "https://github.com/SolgreyDuocUC/digitalfix-infrastructure.git" ;;
    digitalfix-bff-gateway)    echo "https://github.com/SolgreyDuocUC/digitalfix-bff-gateway.git" ;;
    digitalfix-frontend)       echo "https://github.com/Blacknight3648/digitalfix-frontend.git" ;;
    digitalfix-ms-admin-queues)echo "https://github.com/Blacknight3648/digitalfix-ms-admin-queues.git" ;;
    digitalfix-ms-catalog)     echo "https://github.com/SolgreyDuocUC/digitalfix-ms-catalog.git" ;;
    digitalfix-ms-login)       echo "https://github.com/Blacknight3648/digitalfix-ms-login.git" ;;
    digitalfix-ms-notify)      echo "https://github.com/Blacknight3648/digitalfix-ms-notify.git" ;;
    digitalfix-ms-user)        echo "https://github.com/Blacknight3648/digitalfix-ms-user.git" ;;
    digitalfix-ms-workorders)  echo "https://github.com/Blacknight3648/digitalfix-ms-workorders.git" ;;
    *)                         echo "" ;;
  esac
}

ALL_REPOS=(
  "digitalfix-infrastructure"
  "digitalfix-bff-gateway"
  "digitalfix-frontend"
  "digitalfix-ms-admin-queues"
  "digitalfix-ms-catalog"
  "digitalfix-ms-login"
  "digitalfix-ms-notify"
  "digitalfix-ms-user"
  "digitalfix-ms-workorders"
)

# ------------------------------------------------------------------------------
# 3. Función de clonado / actualización de repositorios
# ------------------------------------------------------------------------------
sync_repo() {
  local repo_name="$1"
  local branch="$2"
  local repo_url
  repo_url="$(get_repo_url "$repo_name")"
  local target_path="$BASE_DIR/$repo_name"

  echo "--> Sincronizando: ${repo_name}..."

  if [ ! -d "$target_path/.git" ]; then
    echo "    Clonando ${repo_name} desde ${repo_url} (rama ${branch})..."
    if ! git clone --branch "$branch" --single-branch "$repo_url" "$target_path" 2>/dev/null; then
      echo "    Rama ${branch} no encontrada al clonar, clonando por defecto..."
      git clone "$repo_url" "$target_path"
      cd "$target_path"
      git checkout "$branch" 2>/dev/null || true
    fi
  else
    cd "$target_path"
    echo "    Actualizando ${repo_name} a lo último de origin/${branch}..."
    git fetch origin "$branch" 2>/dev/null || git fetch origin
    git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch" 2>/dev/null || true
    git reset --hard "origin/$branch" 2>/dev/null || git reset --hard "origin/main" 2>/dev/null || true
  fi

  # Garantizar que el directorio wallet exista si el servicio usa Oracle
  case "$repo_name" in
    digitalfix-ms-login|digitalfix-ms-user|digitalfix-ms-workorders|digitalfix-ms-catalog|digitalfix-ms-notify)
      mkdir -p "$target_path/wallet"
      ;;
  esac

  cd "$INFRA_DIR"
}

# ------------------------------------------------------------------------------
# 4. Actualizar repositorios según selección
# ------------------------------------------------------------------------------
if [ "$UPDATE_CODE" = "true" ]; then
  echo ""
  echo "==> Paso 1: Sincronizando código fuente desde GitHub..."

  # Siempre actualizamos el repo de infraestructura
  sync_repo "digitalfix-infrastructure" "$TARGET_BRANCH"

  if [ "$TARGET_SERVICE" = "all" ]; then
    for repo in "${ALL_REPOS[@]}"; do
      if [ "$repo" != "digitalfix-infrastructure" ]; then
        sync_repo "$repo" "$TARGET_BRANCH"
      fi
    done
  else
    target_repo="$(get_repo_name_for_service "$TARGET_SERVICE")"
    if [ -n "$target_repo" ] && [ "$target_repo" != "digitalfix-infrastructure" ]; then
      sync_repo "$target_repo" "$TARGET_BRANCH"
    fi
  fi
else
  echo ""
  echo "==> Paso 1: Omitiendo actualización de código (UPDATE_CODE=false)"
fi

# ------------------------------------------------------------------------------
# 5. Asegurar variables de entorno (.env)
# ------------------------------------------------------------------------------
echo ""
echo "==> Paso 2: Verificando variables de entorno (.env)..."
cd "$INFRA_DIR"

if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    echo "    AVISO: .env no existía. Copiando desde .env.example..."
    cp .env.example .env
  else
    echo "    ERROR: No se encontró ni .env ni .env.example en $INFRA_DIR" >&2
    exit 1
  fi
fi

# Detección automática de IP pública en AWS EC2 para configuración de CORS
detect_public_ip() {
  local ip=""
  # IMDSv2
  local token
  token=$(curl -s -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
  if [ -n "$token" ]; then
    ip=$(curl -s -m 2 -H "X-aws-ec2-metadata-token: $token" "http://169.254.169.254/latest/meta-data/public-ipv4" 2>/dev/null || true)
  fi
  # IMDSv1 fallback
  if [ -z "$ip" ]; then
    ip=$(curl -s -m 2 "http://169.254.169.254/latest/meta-data/public-ipv4" 2>/dev/null || true)
  fi
  # Fallback externo
  if [ -z "$ip" ]; then
    ip=$(curl -s -m 2 "https://ifconfig.me" 2>/dev/null || true)
  fi
  echo "$ip"
}

EC2_PUBLIC_IP="$(detect_public_ip)"
if [ -n "$EC2_PUBLIC_IP" ]; then
  echo "    IP pública detectada: ${EC2_PUBLIC_IP}"
  # Reemplazar placeholder si existe
  if grep -q "PUBLIC_IP_PLACEHOLDER" .env; then
    sed -i "s/PUBLIC_IP_PLACEHOLDER/${EC2_PUBLIC_IP}/g" .env
  fi
  # Asegurar que la IP pública esté en CORS_ALLOWED_ORIGINS si no está
  if ! grep -q "${EC2_PUBLIC_IP}" .env; then
    echo "    Agregando http://${EC2_PUBLIC_IP}:4200 a CORS_ALLOWED_ORIGINS..."
    sed -i "s|CORS_ALLOWED_ORIGINS=\(.*\)|CORS_ALLOWED_ORIGINS=\1,http://${EC2_PUBLIC_IP}:4200,http://${EC2_PUBLIC_IP}:4000|" .env
  fi
fi

# ------------------------------------------------------------------------------
# 6. Reconstrucción y arranque con Docker Compose
# ------------------------------------------------------------------------------
echo ""
echo "==> Paso 3: Ejecutando Docker Compose para '${TARGET_SERVICE}'..."

if [ "$TARGET_SERVICE" = "all" ]; then
  echo "    Construyendo y levantando todos los servicios..."
  docker compose up -d --build
elif [ "$TARGET_SERVICE" = "rabbitmq" ]; then
  echo "    Construyendo y levantando clúster RabbitMQ..."
  docker compose up -d --build rabbitmq rabbitmq-node2
else
  echo "    Construyendo y levantando servicio '${TARGET_SERVICE}'..."
  docker compose up -d --build "$TARGET_SERVICE"
fi

# ------------------------------------------------------------------------------
# 7. Limpieza de imágenes huérfanas
# ------------------------------------------------------------------------------
echo ""
echo "==> Paso 4: Limpiando imágenes y capas obsoletas..."
docker image prune -f || true

# ------------------------------------------------------------------------------
# 8. Estado final y resumen
# ------------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo " Estado de los Contenedores DigitalFix"
echo "======================================================================"
docker compose ps

echo ""
echo "======================================================================"
echo " Despliegue finalizado con éxito"
if [ -n "$EC2_PUBLIC_IP" ]; then
  echo " Frontend Web:   http://${EC2_PUBLIC_IP}:4200"
  echo " BFF Gateway:    http://${EC2_PUBLIC_IP}:8090"
  echo " RabbitMQ Admin: http://${EC2_PUBLIC_IP}:15672 (o via túnel SSH)"
else
  echo " Frontend Web:   http://localhost:4200"
  echo " BFF Gateway:    http://localhost:8090"
  echo " RabbitMQ Admin: http://localhost:15672"
fi
echo "======================================================================"
