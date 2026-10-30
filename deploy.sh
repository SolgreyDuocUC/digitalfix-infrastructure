#!/usr/bin/env bash
# Acceso directo al script centralizado de despliegue
exec "$(dirname "$0")/deploy/deploy.sh" "$@"
