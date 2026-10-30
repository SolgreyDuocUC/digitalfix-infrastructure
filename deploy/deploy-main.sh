#!/usr/bin/env bash
# ==============================================================================
# DIGITALFIX - DESPLIEGUE DEL BACKEND DESDE LA RAMA main
# ==============================================================================
# Lo ejecuta .github/workflows/deploy-main.yml dentro de la EC2.
#
# Uso:
#   bash deploy/deploy-main.sh [servicio] [dominio]
#
#   servicio: config|all|bff-gateway|ms-login|ms-user|
#             ms-workorders|ms-catalog|ms-notify|ms-admin-queues
#   dominio:  opcional. Sin dominio se usa <ip-publica>.sslip.io.
#
#   config: no compila. Solo ajusta CORS y aplica cambios de configuracion.
#   all:    actualiza y compila todos los servicios, uno a la vez.
#
# El frontend no pasa por aqui: se despliega con el workflow de su propio repo
# en ~/frontend/digitalfix-frontend, en su propia instancia. Caddy (HTTPS) vive
# en esa instancia y enruta /api/* al puerto 8090 de esta por su IP privada.
# ==============================================================================

set -euo pipefail

TARGET="${1:-config}"
SITE_DOMAIN="${2:-}"
INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="$(dirname "$INFRA_DIR")"

ORACLE_WAIT_SECONDS="${ORACLE_WAIT_SECONDS:-360}"
BACKEND_SERVICES="ms-login ms-user ms-catalog ms-workorders ms-notify ms-admin-queues bff-gateway"
INFRA_SERVICES="rabbitmq rabbitmq-node2"

repo_for_service() {
  case "$1" in
    bff-gateway)     echo "SolgreyDuocUC/digitalfix-bff-gateway" ;;
    ms-catalog)      echo "SolgreyDuocUC/digitalfix-ms-catalog" ;;
    ms-login)        echo "Blacknight3648/digitalfix-ms-login" ;;
    ms-user)         echo "Blacknight3648/digitalfix-ms-user" ;;
    ms-workorders)   echo "Blacknight3648/digitalfix-ms-workorders" ;;
    ms-notify)       echo "Blacknight3648/digitalfix-ms-notify" ;;
    ms-admin-queues) echo "Blacknight3648/digitalfix-ms-admin-queues" ;;
    *)               echo "" ;;
  esac
}

case "$TARGET" in
  config)
    BUILD_LIST=""
    ;;
  all)
    BUILD_LIST="$BACKEND_SERVICES"
    ;;
  *)
    if [ -z "$(repo_for_service "$TARGET")" ]; then
      echo "ERROR: servicio desconocido '$TARGET'" >&2
      exit 1
    fi
    BUILD_LIST="$TARGET"
    ;;
esac

sync_repo() {
  local service="$1"
  local slug path
  slug="$(repo_for_service "$service")"
  path="$BASE_DIR/$(basename "$slug")"

  if [ ! -d "$path/.git" ]; then
    git clone --branch main "https://github.com/$slug.git" "$path"
    return
  fi

  # El refspec explicito cubre clones hechos con --single-branch. Los archivos
  # ignorados por Git (wallet, .env) no se tocan.
  git -C "$path" fetch origin +refs/heads/main:refs/remotes/origin/main
  git -C "$path" checkout -f -B main origin/main
}

check_wallet() {
  local service="$1" wallet
  case "$service" in
    ms-login|ms-user|ms-catalog|ms-workorders)
      wallet="$BASE_DIR/digitalfix-$service/wallet/tnsnames.ora"
      if [ ! -f "$wallet" ]; then
        echo "ERROR: falta el wallet de Oracle en $wallet" >&2
        exit 1
      fi
      # Los contenedores corren sin root: el wallet montado debe ser legible.
      chmod -R a+rX "$(dirname "$wallet")"
      stat -c "    wallet %a %U %n" "$wallet"
      ;;
  esac
}

# Espera a que los servicios con Oracle terminen de arrancar. Falla si alguno
# reporta un error ORA- durante el arranque o no arranca a tiempo.
verify_oracle() {
  local pending="ms-login-service ms-user-service ms-catalog-service ms-workorders-service"
  local deadline=$((SECONDS + ORACLE_WAIT_SECONDS))
  local container logs still

  while [ -n "$pending" ]; do
    still=""
    for container in $pending; do
      logs="$(docker logs --since "$(docker inspect -f '{{.State.StartedAt}}' "$container")" "$container" 2>&1 || true)"
      if grep -qE 'Started [A-Za-z]+ in ' <<<"$logs"; then
        echo "    $container arriba"
      elif grep -m1 'ORA-' <<<"$logs"; then
        echo "ERROR: $container no se conecta a Oracle" >&2
        return 1
      else
        still="$still $container"
      fi
    done
    pending="$still"

    if [ -n "$pending" ]; then
      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "ERROR: no arrancaron a tiempo:$pending" >&2
        return 1
      fi
      sleep 10
    fi
  done
}
detect_public_ip() {
  local token ip=""
  token="$(curl -s -m 2 -X PUT http://169.254.169.254/latest/api/token \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' || true)"
  if [ -n "$token" ]; then
    ip="$(curl -s -m 2 -H "X-aws-ec2-metadata-token: $token" \
      http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
  fi
  if [ -z "$ip" ]; then
    ip="$(curl -s -m 5 https://checkip.amazonaws.com || true)"
  fi
  echo "$ip" | tr -d '[:space:]'
}

update_cors() {
  local ip="$1" domain="$2"
  sed -i 's/\r$//' .env
  sed -i "s#^CORS_ALLOWED_ORIGINS=.*#CORS_ALLOWED_ORIGINS=http://localhost:4200,http://localhost:4000,http://$ip:4200,https://$domain#" .env
}

cd "$INFRA_DIR"

if [ ! -f .env ]; then
  echo "ERROR: falta $INFRA_DIR/.env (copia .ec2.env a la instancia)" >&2
  exit 1
fi

echo "==> Objetivo: $TARGET"

for service in $BUILD_LIST; do
  echo "==> Actualizando $service"
  sync_repo "$service"
done

for service in $BACKEND_SERVICES; do
  check_wallet "$service"
done

PUBLIC_IP="$(detect_public_ip)"
if [ -z "$PUBLIC_IP" ]; then
  echo "ERROR: no se pudo detectar la IP publica de la instancia" >&2
  exit 1
fi
DOMAIN="${SITE_DOMAIN:-${PUBLIC_IP//./-}.sslip.io}"

echo "==> Ajustando CORS para $DOMAIN"
update_cors "$PUBLIC_IP" "$DOMAIN"

# Se compila de a un servicio para no agotar la memoria de la instancia.
for service in $BUILD_LIST; do
  echo "==> Compilando $service"
  docker compose build "$service"
done

# Compose solo recrea los contenedores con imagen o configuracion distinta.
echo "==> Levantando el backend"
# shellcheck disable=SC2086
docker compose up -d $INFRA_SERVICES $BACKEND_SERVICES

docker image prune -f
docker compose ps

echo "==> Verificando la conexion a Oracle"
verify_oracle

echo "======================================================================"
echo " Despliegue finalizado"
echo " URL:      https://$DOMAIN"
echo " Azure AD: esa URL debe estar registrada como Single-page application"
echo "======================================================================"
