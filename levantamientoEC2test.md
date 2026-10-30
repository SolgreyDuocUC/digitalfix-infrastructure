# Levantamiento tras reiniciar las EC2

URL: <https://digitalfix.duckdns.org>

| Instancia | IP privada | Corre |
|---|---|---|
| Frontend | La suya (ver `~/caddy/Caddyfile`) | nginx (`:4200`), Caddy (`:80`, `:443`) |
| Backend | `172.31.30.23` | BFF (`:8090`), microservicios, RabbitMQ |

Al arrancar se levantan solos los contenedores y DuckDNS actualiza el dominio con la IP nueva del frontend. Solo hay que hacer lo siguiente.

## 1. Encender y actualizar GitHub

1. En AWS, inicia ambas instancias y anota sus IP públicas nuevas.
2. Actualiza `EC2_HOST` (solo afecta a los despliegues, no a lo que ya corre):

```powershell
gh secret set EC2_HOST -R Blacknight3648/digitalfix-frontend --body "<IP_PUBLICA_FRONTEND>"
gh secret set EC2_HOST -R SolgreyDuocUC/digitalfix-infrastructure --body "<IP_PUBLICA_BACKEND>"
```

No hay que cambiar Azure, CORS, `SITE_DOMAIN` ni Caddy.

## 2. Esperar y verificar

Espera unos 5 minutos: los servicios Java arrancan lento (hasta 3 minutos cada uno).

En el backend:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
curl -s localhost:8090/actuator/health
```

Los 9 contenedores deben llevar varios minutos arriba, y el BFF debe responder `"status":"UP"`.

En el frontend:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
curl -s -o /dev/null -w 'web: %{http_code}\n' https://digitalfix.duckdns.org/
curl -s -o /dev/null -w 'api: %{http_code}\n' https://digitalfix.duckdns.org/api/v1/login/me
```

Debe imprimir `web: 200` y `api: 401`. Luego entra a la URL e inicia sesión.

## Despliegues

Se hacen desde `main`. Con `EC2_HOST` al día, un push despliega solo:

| Push a `main` en | Resultado |
|---|---|
| `digitalfix-frontend` | Despliega el frontend |
| `digitalfix-ms-*` o `digitalfix-bff-gateway` | Despliega ese servicio |
| `digitalfix-infrastructure` (script, compose o `mq/`) | Aplica la configuración, sin compilar |

A mano: Actions, **Deploy Backend to AWS EC2**, **Run workflow**. Tarda varios minutos: espera a que los 4 servicios con Oracle arranquen, y el workflow queda en rojo si alguno falla.

## Si algo falla

| Síntoma | Solución |
|---|---|
| El dominio no carga | Espera 5 minutos. Para forzarlo, en el frontend: `eval "$(crontab -l \| grep -m1 '^\*/5' \| cut -d' ' -f6-)"` |
| Falta un contenedor del frontend | `cd ~/frontend/digitalfix-frontend && docker compose up -d` y `docker start caddy` |
| Falta un contenedor del backend | Ver el bloque de abajo |
| 502 en la página | Revisa `digitalfix-frontend` en `docker ps` y luego `docker logs caddy --tail 20` |
| 502 en `/api` | El BFF sigue arrancando o el backend no acepta el `8090` desde el frontend |
| Rol `Cliente` u órdenes de demostración (Comercial Rojas) | Los servicios no terminaron de arrancar o no conectan a Oracle: `docker logs ms-user-service --tail 40`. Luego cierra sesión y vuelve a entrar |
| `ORA-` en los logs | Revisa que la base Oracle esté encendida y que el wallet esté en cada `digitalfix-ms-*/wallet` |
| Contenedor reiniciándose o `Exit 137` | Falta memoria: sube el tipo de instancia |

Levantar el backend a mano (sin `frontend`, que está en la otra instancia):

```bash
cd ~/DigitalFix/digitalfix-infrastructure
docker compose up -d rabbitmq rabbitmq-node2 ms-login ms-user ms-catalog ms-workorders ms-notify ms-admin-queues bff-gateway
```

## Si se recrea una instancia

Reiniciar no borra nada, pero una instancia nueva sí pierde su disco.

- **Backend nuevo:** cambia la IP privada; actualízala en `~/caddy/Caddyfile` del frontend y ejecuta `docker restart caddy`.
- **Frontend nuevo:** vuelve a crear Caddy y el cron de DuckDNS.
- **Ambos casos:** hay que reinstalar Docker y copiar `.env` y los wallets.
