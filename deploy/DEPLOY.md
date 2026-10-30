# DigitalFix - Guía de Despliegue Centralizado y CI/CD

Esta guía documenta la arquitectura y el procedimiento de despliegue centralizado de la plataforma **DigitalFix** en AWS EC2, orquestado íntegramente desde este repositorio (`digitalfix-infrastructure`).

---

## 1. Arquitectura de Despliegue Centralizado

Para evitar dispersar credenciales SSH y scripts duplicados en los 9 repositorios del proyecto, el despliegue está **completamente centralizado en `digitalfix-infrastructure`**:

```
                                  GitHub
  [digitalfix-infrastructure]  ◄────────  Push a rama 'deploy' o 'workflow_dispatch'
              ▲
              │ (dispatches opcional)
  [digitalfix-frontend]
  [digitalfix-bff-gateway]
  [digitalfix-ms-*]
              │
              ▼ SSH Action (appleboy/ssh-action)
  ┌─────────────────────────────────────────────────────────────┐
  │                         AWS EC2                             │
  │                                                             │
  │  ~/DigitalFix/                                              │
  │    ├── digitalfix-infrastructure/  (deploy/deploy.sh)       │
  │    ├── digitalfix-bff-gateway/                              │
  │    ├── digitalfix-frontend/                                 │
  │    ├── digitalfix-ms-login/                                 │
  │    ├── digitalfix-ms-user/                                  │
  │    ├── digitalfix-ms-workorders/                            │
  │    ├── digitalfix-ms-catalog/                               │
  │    ├── digitalfix-ms-notify/                                │
  │    └── digitalfix-ms-admin-queues/                          │
  │                                                             │
  │  Docker Compose:                                            │
  │    - Frontend Angular SSR (:4200 -> :4000)                  │
  │    - BFF Gateway Spring Security (:8090)                    │
  │    - Clúster RabbitMQ 2 nodos (:15672)                      │
  │    - 6 Microservicios internos en red 'digitalfix-net'      │
  │    - Conexión Oracle Cloud Wallet mTLS                      │
  └─────────────────────────────────────────────────────────────┘
```

---

## 2. Métodos para Desplegar

### Método A: Manual desde la interfaz de GitHub (Recomendado)

1. Ve a: [Acciones de digitalfix-infrastructure](https://github.com/SolgreyDuocUC/digitalfix-infrastructure/actions).
2. Selecciona el workflow **"Despliegue Centralizado DigitalFix a EC2"**.
3. Haz clic en **"Run workflow"**.
4. Configura las opciones:
   - **Servicio a desplegar**:
     - `all`: reconstruye y actualiza la plataforma completa.
     - `frontend`: despliega solo el frontend Web Angular SSR.
     - `bff-gateway`: despliega solo el BFF / API Gateway.
     - `ms-login`: despliega el microservicio de autenticación.
     - `ms-user`: despliega el microservicio de usuarios.
     - `ms-workorders`: despliega el microservicio de órdenes de trabajo.
     - `ms-catalog`: despliega el microservicio de catálogo y repuestos.
     - `ms-notify`: despliega el microservicio de notificaciones.
     - `ms-admin-queues`: despliega el microservicio de colas.
     - `rabbitmq`: despliega el clúster RabbitMQ de 2 nodos.
   - **Rama de Git**: `deploy` (o la rama que desees probar).
   - **Actualizar código desde Git**: `true` (por defecto).
5. Haz clic en el botón verde **Run workflow**.

---

### Método B: Automático por Git Push

Al hacer `git push origin deploy` sobre el repositorio `digitalfix-infrastructure`, GitHub Actions disparará automáticamente el despliegue de toda la plataforma a la instancia EC2.

---

### Método C: Ejecución directa en el servidor EC2

Si te encuentras conectado a la instancia EC2 por SSH, puedes ejecutar el despliegue directamente:

```bash
# Entrar a la carpeta de infraestructura
cd ~/DigitalFix/digitalfix-infrastructure

# Dar permisos de ejecución (si no los tiene)
chmod +x deploy/deploy.sh deploy.sh

# Desplegar toda la plataforma
./deploy.sh all deploy true

# O desplegar un microservicio específico:
./deploy.sh frontend deploy true
./deploy.sh bff-gateway deploy true
./deploy.sh ms-login deploy true
```

---

### Método D: Despliegue desde repositorios individuales

Cada microservicio (`digitalfix-frontend`, `digitalfix-bff-gateway`, `digitalfix-ms-*`) ejecuta su propio job de **Build & Test** (Maven / Angular) en su Pull Request o Push.

Para activar el despliegue automático desde esos repositorios hacia la infraestructura:
1. Agrega el secreto `INFRA_DISPATCH_TOKEN` (un GitHub Personal Access Token con permiso `repo`) en el repositorio individual.
2. Al terminar el build exitosamente, el workflow notificará a `digitalfix-infrastructure` mediante `repository_dispatch` para que ejecute el despliegue de ese microservicio de forma automática.

---

## 3. Configuración de Secretos en GitHub (Solo en este Repositorio)

Los secretos de despliegue ahora se configuran **una única vez** en `digitalfix-infrastructure` (`Settings > Secrets and variables > Actions`):

| Secreto | Descripción | Obligatorio | Ejemplo |
|---|---|---|---|
| `EC2_HOST` | IP pública o nombre DNS de la instancia EC2 | **Sí** | `54.210.123.45` |
| `EC2_USERNAME` | Usuario SSH de la instancia | **Sí** | `ec2-user` o `ubuntu` |
| `EC2_SSH_KEY` | Contenido completo de la llave privada `.pem` | **Sí** | `-----BEGIN RSA PRIVATE KEY-----...` |
| `EC2_APP_DIR` | Ruta raíz donde se ubican los proyectos en la EC2 | No | `/home/ec2-user/DigitalFix` |
| `EC2_PORT` | Puerto SSH | No | `22` |

> [!TIP]
> Si la IP de tu laboratorio de AWS Academy cambia, solo debes actualizar `EC2_HOST` en este repositorio (`digitalfix-infrastructure`). No necesitas tocar los otros repositorios.

---

## 4. Puertos y Servicios Expuestos en la EC2

| Servicio | Puerto Host | Puerto Contenedor | Acceso | Notas |
|---|---|---|---|---|
| **Frontend Web** | `4200` | `4000` | Público | Angular SSR con MSAL |
| **BFF Gateway** | `8090` | `8090` | Público | Valida JWT de Entra ID y enruta a microservicios |
| **RabbitMQ Web** | `15672` | `15672` | localhost / SSH | Consola web de administración |
| **ms-login** | — | `8081` | Interno | Red `digitalfix-net` |
| **ms-user** | — | `8082` | Interno | Red `digitalfix-net` |
| **ms-workorders** | — | `8080` | Interno | Red `digitalfix-net` |
| **ms-catalog** | — | `8080` | Interno | Red `digitalfix-net` |
| **ms-notify** | — | `8083` | Interno | Red `digitalfix-net` |
| **ms-admin-queues** | — | `8084` | Interno | Red `digitalfix-net` |

---

## 5. Script de Despliegue (`deploy/deploy.sh`)

El script se encarga automáticamente de:
1. Verificar y resolver rutas de todos los repositorios.
2. Clonar cualquier repositorio que no exista en el servidor.
3. Actualizar a la rama especificada (`git fetch` y `git reset --hard`).
4. Crear carpetas de wallet Oracle en los microservicios que lo requieren.
5. Detectar la IP pública de la EC2 (mediante IMDSv2 / IMDSv1) y configurar `CORS_ALLOWED_ORIGINS` en `.env`.
6. Compilar y levantar los contenedores con `docker compose up -d --build`.
7. Limpiar imágenes huérfanas (`docker image prune -f`).
8. Imprimir el estado de salud de todos los contenedores y los enlaces de acceso.
