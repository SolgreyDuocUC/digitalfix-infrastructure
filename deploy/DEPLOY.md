# Despliegue en AWS (EC2) — estado actual del proyecto

Este documento reemplaza al plan generico que asumia un `ms-digitalfix-bff.jar`
y un unico "microservicio de catalogo/ordenes": ese BFF todavia no existe
(sigue como "componente pendiente" en el README de este repo) y de los
`digitalfix-ms-*` solo dos tienen codigo desplegable hoy. Cubre solo la parte
local (Paso 1); el resto (Security Groups, instancias EC2, Azure AD) lo haces
tu en la consola de AWS Academy siguiendo esta misma guia.

## Que hay realmente para desplegar

| Repo | Estado | Puerto contenedor | Notas |
|---|---|---|---|
| `digitalfix-frontend` | Listo, con Dockerfile + docker-compose.yml propios | 4000 (host 4200) | Angular en **modo SSR** (Express), no es un SPA estatico — no usar nginx. |
| `digitalfix-ms-login` | Listo, con Dockerfile | 8080 | Valida JWT de Azure AD (issuer/audience). |
| `digitalfix-ms-workorders` | Listo, con Dockerfile | 8080 (mapeado a 8081 en host) | **No valida JWT todavia** — ver nota de seguridad abajo. |
| `digitalfix-ms-user` | Codigo sin Dockerfile | — | No desplegable aun. |
| `digitalfix-ms-audit`, `-catalog`, `-notify`, `-report` | Repos vacios (solo `.git`) | — | No desplegable aun. |
| `ms-digitalfix-bff` | No existe | — | "Componente pendiente" segun el README de este repo. |

Los Dockerfile de `ms-login` y `ms-workorders` compilan desde codigo fuente
dentro del propio build de Docker (`mvn package` en la etapa `builder`); el
del frontend hace lo mismo con `npm run build`. Esto significa que **no hace
falta compilar nada a mano antes de subir a EC2** — basta con clonar los
repos ahi y correr `docker compose up -d --build`. El "Paso 1" del plan
original (`ng build` / `mvn package` locales) no es necesario con este setup.

### Nota de seguridad importante

`digitalfix-ms-workorders` explicitamente no valida el JWT de Azure AD (esa
validacion la hara `ms-digitalfix-bff` cuando exista — ver el comentario en su
`application.yaml`). Si abres su puerto 8081 a `0.0.0.0/0` en el Security
Group, cualquiera en internet puede leer/crear/modificar ordenes de trabajo
sin autenticarse. Mientras no exista el BFF, restringe el inbound del puerto
8081 (y del 1521 si usas Oracle en Docker, ver mas abajo) al Security Group o
a la IP publica de la instancia `ec2-frontend-login`, nunca a "Anywhere".

## Layout de instancias (adaptando el plan de 2 EC2)

- **ec2-frontend-login**: frontend (Angular SSR) + `ms-login` (+ Oracle si lo
  corres en Docker, ver abajo).
- **ec2-workorders**: `ms-workorders`, apuntando su datasource al Oracle de la
  otra instancia (o a Oracle Cloud si usan esa opcion).

### Base de datos Oracle

`ms-login` y `ms-workorders` comparten el mismo Oracle. Su
`docker-compose.yaml` local levanta un contenedor `gvenzl/oracle-free:23-slim`
propio, pero **ese contenedor pide ~2 GB de RAM**, mas de lo que tiene una
`t2.micro`/`t3.micro` (1 GB) de AWS Academy. Dos opciones:

1. **Recomendada**: usar una instancia Oracle Cloud Free Tier externa (como ya
   contemplaba el plan original con `jdbc:oracle:thin:@tu_instancia_oracle_cloud`)
   y apuntar `DB_URL` de ambos microservicios ahi. No consume RAM de las EC2.
   Si la Oracle Cloud tiene IP fija, no necesitas abrir el puerto 1521 en
   ningun Security Group de tus EC2 (solo egress saliente, que por defecto
   esta permitido).
2. Si prefieres Oracle en Docker sobre `ec2-frontend-login`: usa una instancia
   mas grande (`t3.medium` o superior, si el laboratorio de AWS Academy lo
   permite) y abre el puerto 1521 en su Security Group **solo** para el
   Security Group/IP de `ec2-workorders`.

Los `docker-compose.yml` de `deploy/ec2-frontend-login/` y
`deploy/ec2-workorders/` de este repo dejan `DB_URL`/`DB_USER`/`DB_PASSWORD`
como variables de entorno para que sirvan con cualquiera de las dos opciones.

## Paso 1 (local, hecho): archivos preparados

- [environment.prod.ts](../../digitalfix-frontend/frontend/src/app/environment/environment.prod.ts)
  en `digitalfix-frontend` — apunta `apiBaseUrl` y `workOrdersApiUrl` a
  placeholders `<EC2_..._PUBLIC_IP>`. `redirectUri` no necesita tocarse:
  ya usa `window.location.origin`, asi que se adapta solo a la IP/dominio real
  siempre que la agregues como Redirect URI en Azure AD (Paso 5).
- `angular.json` — se agrego `fileReplacements` a la configuracion
  `production` para que `ng build --configuration production` use
  `environment.prod.ts` en vez de `environment.ts`.
- [deploy/ec2-frontend-login/docker-compose.yml](ec2-frontend-login/docker-compose.yml)
  y [deploy/ec2-workorders/docker-compose.yml](ec2-workorders/docker-compose.yml)
  — listos para copiar a cada instancia (ver Paso 4).

Antes de compilar el frontend, reemplaza los dos placeholders en
`environment.prod.ts` por las IP publicas reales una vez que existan las EC2.

## Paso 2: Security Groups (a definir en consola AWS por ti)

**sg-frontend-login** (instancia `ec2-frontend-login`):
- Inbound `TCP 4200` — Source `0.0.0.0/0` (frontend).
- Inbound `TCP 8080` — Source `0.0.0.0/0` (`ms-login`, lo llama el navegador
  directo, no hay BFF todavia).
- Inbound `TCP 22` — Source: tu IP.
- (Si corres Oracle en esta instancia) Inbound `TCP 1521` — Source:
  `sg-workorders` (no `0.0.0.0/0`).

**sg-workorders** (instancia `ec2-workorders`):
- Inbound `TCP 8081` — Source: `sg-frontend-login` (no `0.0.0.0/0`, ver nota
  de seguridad arriba).
- Inbound `TCP 22` — Source: tu IP.

## Paso 3: Instancias EC2 (a definir en consola AWS por ti)

Igual que el plan original: Ubuntu Server 24.04 LTS, `t2.micro`/`t3.micro`
(salvo que uses Oracle en Docker, ver arriba), key pair propio, Auto-assign
Public IP en `Enable`, cada instancia con su Security Group correspondiente.

## Paso 4: Instalar Docker y clonar los repos en cada EC2

```bash
ssh -i "tu-llave.pem" ubuntu@<IP_PUBLICA_EC2>

sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-v2 git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

En `ec2-frontend-login`:

```bash
mkdir -p ~/digitalfix && cd ~/digitalfix
git clone https://github.com/Blacknight3648/digitalfix-frontend.git
git clone https://github.com/Blacknight3648/digitalfix-ms-login.git
# copia (scp) o pega aqui el docker-compose.yml de deploy/ec2-frontend-login/
```

En `ec2-workorders`:

```bash
mkdir -p ~/digitalfix && cd ~/digitalfix
git clone https://github.com/Blacknight3648/digitalfix-ms-workorders.git
# copia (scp) o pega aqui el docker-compose.yml de deploy/ec2-workorders/
```

Repos privados: usa un Personal Access Token de GitHub en la URL del clone, o
`ssh` con una deploy key — no subas credenciales al `docker-compose.yml`.

## Paso 5: variables de entorno y arranque

En cada instancia, junto al `docker-compose.yml`, crea un `.env`:

`ec2-frontend-login/.env`:
```
DB_URL=jdbc:oracle:thin:@//<ORACLE_HOST>:1521/<SERVICE_NAME>
DB_USER=...
DB_PASSWORD=...
AZURE_TENANT_ID=3fb8463e-0e33-4b7d-adc1-2a47c707831e
AZURE_CLIENT_ID=9494b59c-9c6e-4a0f-91ae-ae90212882e7
CORS_ALLOWED_ORIGINS=http://<EC2_FRONTEND_LOGIN_PUBLIC_IP>:4200
```

`ec2-workorders/.env`:
```
DB_URL=jdbc:oracle:thin:@//<ORACLE_HOST>:1521/<SERVICE_NAME>
DB_USER=...
DB_PASSWORD=...
CORS_ALLOWED_ORIGINS=http://<EC2_FRONTEND_LOGIN_PUBLIC_IP>:4200
```

Luego, en cada instancia:

```bash
cd ~/digitalfix && docker compose up -d --build
docker compose ps
docker compose logs -f
```

Con las IPs publicas ya asignadas, vuelve al repo del frontend, actualiza los
dos placeholders en `environment.prod.ts` y reconstruye el contenedor del
frontend (`docker compose up -d --build frontend` en `ec2-frontend-login`).

## Paso 6: Azure AD

Agrega `http://<IP_PUBLICA_EC2_FRONTEND_LOGIN>:4200` como Redirect URI en la
App Registration del frontend (mismo tenant que ya usa `ms-login`). No hace
falta tocar `redirectUri` en el codigo: ya se calcula solo desde
`window.location.origin`.

## Paso 7: verificacion

1. Abrir `http://<IP_PUBLICA_EC2_FRONTEND_LOGIN>:4200`.
2. Iniciar sesion con Microsoft.
3. DevTools (F12) → Network → confirmar `Authorization: Bearer ...` en las
   requests hacia `:8080` (`ms-login`).
4. Probar una accion contra `ms-workorders` (`:8081`) y confirmar en los logs
   del contenedor (`docker compose logs -f ms-workorders`) que la peticion
   llega — recordando que hoy ese servicio no exige el token.

## Pendiente para cuando exista `ms-digitalfix-bff`

Cuando se incorpore el BFF (y, si la pauta de tu evaluacion lo exige, el API
Gateway con JWT Authorizer delante de todo), este layout cambia: el frontend
dejara de llamar a `ms-login`/`ms-workorders` directo y pasara a llamar solo
al BFF, y `ms-workorders` podra cerrar su puerto al publico por completo
(solo accesible desde el BFF). Aviso para no dejarlo como deuda tecnica
silenciosa: hoy ese es el diseno "final" documentado en el README de este
repo, esto es un despliegue intermedio mientras el BFF no existe.
