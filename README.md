# DigitalFix - Infraestructura Central

## 1. Descripcion general

DigitalFix es una plataforma para la gestion de ordenes de trabajo de mantencion electrica y field service, destinada a una red de empresas de mantencion que hoy coordinan su operacion por telefono y chat, sin trazabilidad ni visibilidad de estado para el cliente.

La plataforma centraliza:

- La creacion, asignacion y seguimiento de ordenes de trabajo.
- La administracion del catalogo de servicios tecnicos y el stock de repuestos.
- La notificacion al cliente (email/push) y el despacho de tickets a los tecnicos en terreno.
- Un panel de operaciones con KPIs en tiempo real (ordenes por hora, tiempo de resolucion, estados activos).
- La auditoria de eventos tecnicos del ciclo de vida de cada orden.

El acceso a la plataforma se realiza mediante login corporativo con Azure AD (IDaaS). El frontend es una aplicacion Angular con MSAL, y el backend esta compuesto por microservicios Spring Boot expuestos a traves de AWS API Gateway, protegidos mediante validacion de JWT.

### 1.1 Actores y roles

| Rol | Responsabilidad |
|---|---|
| Admin | Administra el catalogo de servicios/repuestos y visualiza los KPIs de la red. |
| Supervisor (Operador) | Acepta ordenes, asigna tecnico y cierra el trabajo. |
| Cliente | Crea y hace seguimiento de sus ordenes de mantencion. |
| Auditor | Consulta el timeline de eventos. Acceso de solo lectura. |

### 1.2 Flujo de llamadas seguras

El flujo de toda peticion autenticada hacia el backend es siempre el mismo:

```
Cliente (Angular + MSAL) -> JWT -> AWS API Gateway -> ms-digitalfix-bff -> microservicio de dominio
```

El API Gateway valida el JWT emitido por Azure AD (issuer y audience) antes de reenviar la peticion. El BFF y cada microservicio de dominio revalidan el token y aplican autorizacion por rol sobre sus propios endpoints.

## 2. Organizacion del ecosistema polirepo

Este repositorio (`digitalfix-infrastructure`) es el repositorio central del proyecto. No contiene codigo de aplicacion: concentra la orquestacion de infraestructura compartida (mensajeria, streaming y despliegue local) y la documentacion de arquitectura que da contexto al resto de los repositorios del equipo.

El sistema se desarrolla bajo una estrategia multi-repo: un repositorio por cada componente desplegable. Los repositorios actuales del proyecto son:

| Repositorio | Organizacion | Tecnologia | Responsabilidad | Exposicion |
|---|---|---|---|---|
| [digitalfix-frontend](https://github.com/Blacknight3648/digitalfix-frontend.git) | Blacknight3648 | Angular + MSAL | Interfaz de usuario, login corporativo, consumo del API Gateway. | Publica (SPA) |
| [digitalfix-ms-login](https://github.com/Blacknight3648/digitalfix-ms-login.git) | Blacknight3648 | Spring Boot + Oracle | Autenticacion/sesion de aplicacion e integracion con el flujo de identidad; auditoria de intentos de login. | `/api/v1/login/*`, `/api/v1/audit/*` |
| [digitalfix-ms-user](https://github.com/Blacknight3648/digitalfix-ms-user.git) | Blacknight3648 | Spring Boot | Gestion de usuarios y roles de dominio. | `/api/users/*` |
| [digitalfix-ms-workorders](https://github.com/Blacknight3648/digitalfix-ms-workorders.git) | Blacknight3648 | Spring Boot + Oracle | CRUD de ordenes de trabajo y maquina de estados. | `/api/workorders/*` |
| [digitalfix-ms-notify](https://github.com/Blacknight3648/digitalfix-ms-notify.git) | Blacknight3648 | Spring Boot + RabbitMQ | Consumidor de colas; envio de notificaciones y tickets de despacho. | Sin exposicion publica (consumidor) |
| [digitalfix-ms-catalog](https://github.com/SolgreyDuocUC/digitalfix-ms-catalog.git) | SolgreyDuocUC | Spring Boot + Oracle | CRUD de servicios tecnicos, tarifas y stock de repuestos. | `/api/catalog/*` |
| [digitalfix-ms-report](https://github.com/SolgreyDuocUC/digitalfix-ms-report.git) | SolgreyDuocUC | Spring Boot + Kafka + Oracle | Consumidor de eventos; agregaciones y KPIs de lectura. | `/api/report/*` (solo lectura) |
| [digitalfix-ms-audit](https://github.com/SolgreyDuocUC/digitalfix-ms-audit.git) | SolgreyDuocUC | Spring Boot + Kafka + Oracle | Consumidor de eventos; persistencia y consulta del timeline. | `/api/audit/*` (solo lectura) |

Cada repositorio mantiene su propio ciclo de vida (build, test, deploy), su propio `README.md` con el detalle de endpoints, variables de entorno y forma de levantarlo localmente, y su propia rama `main` protegida.

### 2.1 Componentes pendientes

Segun la pauta del caso semestral, en etapas posteriores del curso se deben incorporar ademas:

- `ms-digitalfix-bff`: Backend for Frontend (Spring Boot + Spring Security), unico punto de entrada detras del API Gateway hacia los microservicios de dominio.
- Un microservicio o modulo administrador de RabbitMQ.
- Un microservicio o modulo administrador de Kafka.

Estos componentes se agregaran como repositorios adicionales (o como modulos dentro de uno existente, segun defina el equipo) conforme lo exija cada evaluacion. Cuando se incorporen, deben agregarse a la tabla anterior y al tablero Kanban unico del proyecto.

## 3. Estructura de este repositorio

```
digitalfix-infrastructure/
├── apps/   # Orquestacion de microservicios de dominio, BFF y persistencia (proxima etapa)
├── kafka/  # Cluster de Apache Kafka (Zookeeper, Brokers y Kafka UI) (proxima etapa)
└── mq/     # Cluster de RabbitMQ (nodos de mensajeria y Management UI)
```

Cada carpeta contiene su propio `docker-compose.yml` para permitir el despliegue independiente de cada componente de infraestructura, tanto en desarrollo local como en instancias EC2 dedicadas (`ec2-apps`, `ec2-mq`, `ec2-kafka`).

## 4. Seguridad e identidad

- App Registration "DigitalFix" en Azure AD: `clientId`, `redirectUri`, `authority = https://login.microsoftonline.com/<TENANT_ID>/`.
- Frontend (MSAL Angular): protege rutas mediante guards y adjunta `Authorization: Bearer <access_token>` a cada request saliente mediante un interceptor.
- AWS API Gateway (HTTP API) con JWT Authorizer: `issuer = https://login.microsoftonline.com/<TENANT_ID>/v2.0`, `audience = api://<API_CLIENT_ID>`.
- Backend (Spring Security / Resource Server): valida el JWT con `security.oauth2.resourceserver.jwt.issuer-uri` y aplica autorizacion por rol (`Admin`, `Operador`, `Cliente`, `Auditor`) sobre cada endpoint.

Ningun servicio debe confiar en un JWT sin validar su firma, `issuer` y `audience`. La validacion de presencia del header, sin verificar estos claims, no se considera una implementacion valida.

Las credenciales y secretos (client secrets, cadenas de conexion, usuarios de base de datos) nunca se suben a los repositorios. En desarrollo local se gestionan mediante variables de entorno o archivos `.env` ignorados por Git; en AWS se gestionan mediante variables de entorno de la instancia o AWS Secrets Manager.

## 5. Mensajeria asincrona (RabbitMQ)

Directorio: `mq/`

Canal orientado al procesamiento asincrono de comandos de trabajo y tareas operativas desacopladas mediante colas y Dead Letter Exchanges (DLX).

Topologia de colas principales y DLQ:

| Cola principal | Proposito | DLQ | Binding direct | Binding topic |
|---|---|---|---|---|
| `q.cmd.email` | Email/push al cliente (asignada, tecnico en camino, cerrada). | `q.cmd.email.dlq` | `email.send` | `email.*` |
| `q.cmd.dispatch` | Ticket de despacho / orden de terreno al tecnico. | `q.cmd.dispatch.dlq` | `dispatch.ticket` | `dispatch.#` |
| `q.cmd.report` | Generacion de PDF (informe tecnico o certificado de trabajo). | `q.cmd.report.dlq` | `report.gen` | `report.*` |

Exchanges definidos:

- `cmd.direct` (direct): enrutamiento puntual mediante routing keys exactas.
- `cmd.topic` (topic): enrutamiento por patrones.
- `cmd.dead.dlx` (direct): enrutamiento de mensajes rechazados o no entregables hacia sus DLQ correspondientes.

Buenas practicas exigidas a los consumidores: envelope comun (`type`, `eventId`, `timestamp`, `traceId`, `correlationId`), ACK/NACK explicitos, idempotencia en el procesamiento y metricas de tasa de DLQ.

## 6. Streaming y auditoria (Apache Kafka)

Directorio: `kafka/`

Plataforma de streaming de eventos de negocio orientada a la analitica en tiempo real y a la persistencia inmutable de auditoria (event sourcing).

| Topico | Particiones | Replicas | Politica | Retencion | Proposito |
|---|---|---|---|---|---|
| `workorders.events` | 3 | 3 | delete | 3-7 dias | Fuente de verdad de eventos de la orden de trabajo. Alimenta reporteria y auditoria. |
| `audit.timeline` | 3 | 3 | compact,delete | 14-30 dias | Historial de quien, que, cuando y desde donde. |
| `*.DLT` (por consumidor) | 3 | 3 | delete | 7-14 dias | Mensajes que fallaron tras N reintentos, con metadatos de error. |

## 7. Instrucciones de ejecucion de la infraestructura local

### Prerrequisitos

- Docker Engine 24.0 o superior.
- Docker Compose v2 o superior.
- Red local o puente Docker con soporte para nombres de contenedor.

### Red compartida

Los modulos utilizan la red puente `digitalfix-net`. Docker Compose crea la red automaticamente al inicializar el primer servicio si aun no existe. Todo nuevo contenedor agregado a este repositorio debe asociarse explicitamente a esta red.

### Despliegue de RabbitMQ

Desde el subdirectorio `mq/`:

```bash
cd mq
docker compose up -d
docker compose ps
docker compose logs -f
docker compose down
```

O desde la raiz del repositorio, indicando la ruta del archivo:

```bash
docker compose -f mq/docker-compose.yml up -d
docker compose -f mq/docker-compose.yml ps
docker compose -f mq/docker-compose.yml logs -f
docker compose -f mq/docker-compose.yml down
```

Acceso y puertos expuestos:

- Protocolo AMQP (microservicios): `localhost:5672`
- Consola de gestion web (Management UI): `http://localhost:15672`
  - Usuario: `digitalfix`
  - Contrasena: `digitalfix_pass`

### Despliegue de Kafka (proxima etapa)

```bash
cd kafka
docker compose up -d
```

### Despliegue de Apps (proxima etapa)

```bash
cd apps
docker compose up -d
```

## 8. Guia para desarrolladores

Esta seccion describe como preparar el entorno para desarrollar sobre los microservicios y el frontend del proyecto, dado que cada componente vive en su propio repositorio.

### 8.1 Requisitos previos generales

- Git.
- JDK 21 (requerido por Spring Boot 4.x en todos los microservicios).
- Apache Maven (o el wrapper `mvnw` incluido en cada microservicio).
- Node.js 20 LTS o superior y npm.
- Angular CLI (`npm install -g @angular/cli`).
- Docker Desktop (para levantar RabbitMQ, Kafka y bases de datos locales).
- Cliente de Oracle Database (driver JDBC) para los microservicios que persisten en Oracle: `ms-digitalfix-login`, `ms-digitalfix-workorders`, `ms-digitalfix-catalog`, `ms-digitalfix-report`, `ms-digitalfix-audit`.
- Cuenta de GitHub con acceso de colaborador a los ocho repositorios del proyecto.

### 8.2 Organizacion local de los repositorios

Se recomienda clonar todos los repositorios dentro de una misma carpeta de trabajo, manteniendo el nombre original de cada uno:

```bash
mkdir digitalfix && cd digitalfix

git clone https://github.com/Blacknight3648/digitalfix-frontend.git
git clone https://github.com/Blacknight3648/digitalfix-ms-login.git
git clone https://github.com/Blacknight3648/digitalfix-ms-user.git
git clone https://github.com/Blacknight3648/digitalfix-ms-workorders.git
git clone https://github.com/Blacknight3648/digitalfix-ms-notify.git
git clone https://github.com/SolgreyDuocUC/digitalfix-ms-catalog.git
git clone https://github.com/SolgreyDuocUC/digitalfix-ms-report.git
git clone https://github.com/SolgreyDuocUC/digitalfix-ms-audit.git
git clone https://github.com/SolgreyDuocUC/digitalfix-infrastructure.git
```

Esta estructura de carpetas planas (un directorio por repositorio) es la que mejor se adapta tanto a un workspace multi-root de Visual Studio Code como a la apertura de proyectos independientes en IntelliJ IDEA.

### 8.3 Desarrollo con Visual Studio Code

Visual Studio Code se utiliza principalmente para el desarrollo del frontend (`digitalfix-frontend`), aunque tambien puede usarse para editar cualquier microservicio.

1. Instalar las siguientes extensiones:
   - Extension Pack for Java (Microsoft).
   - Spring Boot Extension Pack (VMware/Microsoft).
   - Angular Language Service.
   - ESLint.
   - Docker.
   - GitHub Pull Requests and Issues.

2. Abrir un workspace multi-root que incluya los repositorios sobre los que se va a trabajar. En el menu `File > Add Folder to Workspace`, agregar cada carpeta de repositorio clonado y guardar el workspace como `digitalfix.code-workspace`. Esto permite ver y editar frontend y microservicios desde una sola ventana sin mezclar el control de versiones de cada repositorio (cada carpeta conserva su propio `.git`).

3. Para el frontend (`digitalfix-frontend`):

   ```bash
   cd digitalfix-frontend
   npm install
   ng serve
   ```

   La aplicacion queda disponible en `http://localhost:4200`. Verificar en el `environment.ts` del proyecto la configuracion de MSAL (`clientId`, `authority`, `redirectUri`) y la URL base del API Gateway o del BFF contra el que se debe apuntar en el entorno de desarrollo.

4. Para depurar un microservicio Spring Boot desde Visual Studio Code, usar la vista "Run and Debug" y crear una configuracion de tipo "Java" apuntando a la clase principal (`*Application.java`) del microservicio, o adjuntar el depurador a un proceso ya iniciado con `mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005"`.

5. Configurar las variables de entorno o el archivo `application-local.yml` de cada microservicio antes de ejecutarlo (ver seccion 8.5).

### 8.4 Desarrollo con IntelliJ IDEA

IntelliJ IDEA se utiliza para el desarrollo de los microservicios Spring Boot. Cada microservicio se abre como un proyecto independiente, ya que se trata de repositorios separados sin un `pom.xml` padre comun.

1. Verificar que el JDK configurado en `File > Project Structure > SDKs` corresponda a JDK 17.
2. Abrir cada microservicio con `File > Open` seleccionando la carpeta raiz del repositorio clonado (la que contiene el `pom.xml`). IntelliJ detecta el proyecto Maven e importa las dependencias automaticamente.
3. Instalar el plugin de Lombok (`Settings > Plugins > Lombok`) y habilitar "Annotation Processing" en `Settings > Build, Execution, Deployment > Compiler > Annotation Processors`, requerido por los microservicios que usan Lombok.
4. Para trabajar simultaneamente en varios microservicios, abrir cada uno en una ventana distinta de IntelliJ (`File > Open` elige "New Window"), en vez de intentar importarlos como modulos de un unico proyecto.
5. Crear una configuracion de ejecucion (`Run/Debug Configurations`) de tipo "Spring Boot" por cada microservicio, indicando en la pestana "Environment variables" las variables descritas en la seccion 8.5.
6. Para los microservicios que integran RabbitMQ o Kafka, levantar primero la infraestructura correspondiente con Docker Compose (seccion 7) antes de iniciar el microservicio desde IntelliJ.
7. Si se requiere inspeccionar Oracle Database, instalar y configurar el plugin de bases de datos integrado de IntelliJ (`Database` tool window) con el driver Oracle y las credenciales del entorno de desarrollo.

### 8.5 Variables de entorno y configuracion por servicio

Cada microservicio define su propio `application.yml` o `application.properties`, con perfiles separados (por ejemplo `local`, `dev`, `prod`). Como minimo, cada microservicio backend requiere:

- `SPRING_PROFILES_ACTIVE`: perfil activo (`local` en el equipo del desarrollador).
- `AZURE_TENANT_ID` y `API_CLIENT_ID` (o el `issuer-uri` equivalente): usados por Spring Security para validar el JWT.
- Variables de conexion a Oracle (`DB_URL`, `DB_USER`, `DB_PASSWORD`) en los microservicios que persisten datos.
- `RABBITMQ_HOST`, `RABBITMQ_PORT`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD` en los microservicios que publican o consumen colas (por defecto, los valores definidos en `mq/docker-compose.yml`: usuario `digitalfix`, contrasena `digitalfix_pass`, puerto `5672`).
- `KAFKA_BOOTSTRAP_SERVERS` en los microservicios consumidores de Kafka.

Ninguna de estas variables ni sus valores reales deben quedar hardcodeados en el codigo fuente ni subirse a los repositorios; el detalle exacto de cada una se documenta en el `README.md` propio de cada microservicio.

### 8.6 Ejecucion local coordinada

Orden recomendado para levantar un entorno de desarrollo completo:

1. Levantar la infraestructura compartida necesaria (`mq/`, y cuando corresponda `kafka/`) desde este repositorio.
2. Levantar los microservicios de dominio desde IntelliJ IDEA o linea de comandos (`mvnw spring-boot:run`), en el orden que sus dependencias requieran (por ejemplo, servicios consumidores de eventos despues de que la infraestructura de mensajeria este disponible).
3. Levantar el frontend con `ng serve` desde Visual Studio Code, apuntando su configuracion al API Gateway/BFF del entorno de desarrollo.

### 8.7 Control de versiones por repositorio

- Cada repositorio se sube con su propio `.gitignore` correspondiente a su tecnologia: Maven/Spring Boot en los microservicios, Node/Angular en el frontend. Solo debe versionarse codigo fuente y archivos de configuracion, nunca artefactos de build (`target/`, `dist/`, `node_modules/`) ni carpetas de IDE (`.idea/`, `.vscode/`).
- La rama `main` de cada repositorio esta protegida: no se permite push directo, unicamente integracion via Pull Request aprobado.

## 9. Metodologia de trabajo (Kanban + GitHub)

El equipo gestiona todo el desarrollo del proyecto semestral con Kanban sobre GitHub y GitHub Projects. El detalle completo del flujo esta en la guia entregada por la asignatura; a continuacion se resumen los puntos que todo integrante debe respetar sin excepcion.

### 9.1 Tablero unico

- Existe un unico GitHub Project (tablero Kanban) para todo el equipo, que enlaza los ocho repositorios del proyecto (frontend, microservicios de dominio y este repositorio de infraestructura).
- El tablero usa un campo personalizado "Servicio" para clasificar cada tarjeta segun el repositorio al que pertenece: `Frontend`, `MS-Login`, `MS-User`, `MS-Workorders`, `MS-Catalog`, `MS-Notify`, `MS-Report`, `MS-Audit`, `Infra`.
- Columnas: `Backlog`, `To Do`, `In Progress`, `In Review`, `Done`. Limite recomendado de trabajo en curso: 1-2 tarjetas en `In Progress` por integrante.
- El tablero es la fuente de verdad del avance del proyecto; no reemplaza a informes de avance separados.

### 9.2 Issues

- Cada tarjeta del tablero corresponde a un Issue de GitHub, nunca a texto suelto.
- Todo Issue debe tener: titulo claro y accionable, descripcion con criterio de aceptacion, etiqueta (`feature`, `bug`, `doc`, `chore`), responsable asignado y, si corresponde, milestone.

### 9.3 Ramas y commits

- Una rama por tarea/issue: `feature/nombre-corto`, `fix/nombre-corto`. Nunca trabajar directo sobre `main`.
- Commits descriptivos en presente, siguiendo la convencion Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`.

### 9.4 Pull Requests

- Todo Pull Request debe referenciar el Issue relacionado (`Closes #12`) para que la tarjeta se mueva automaticamente a `Done` al hacer merge.
- Debe ser revisado y aprobado por al menos un integrante distinto al autor antes de integrarse.
- Sin Pull Request aprobado no hay integracion a `main`.

### 9.5 Cambios que afectan a mas de un repositorio

- Cuando un cambio afecta a mas de un servicio (por ejemplo, un cambio de contrato de API entre un microservicio y el frontend, o un cambio en la topologia de `mq/`/`kafka/` que este repositorio expone), debe reflejarse con Pull Requests coordinados en cada repositorio afectado, referenciando el mismo Issue o milestone comun.
- Para referenciar un Issue de otro repositorio se usa la sintaxis `organizacion/repositorio#numero_issue` (por ejemplo, `Blacknight3648/digitalfix-ms-workorders#12`).
- La descripcion del Pull Request debe indicar explicitamente si el cambio requiere actualizar otro microservicio o el frontend, para evitar integrar cambios incompletos.

## 10. Estandares operativos

- Seguridad de credenciales: no almacenar secretos productivos en ningun repositorio. En entornos productivos (AWS EC2) las credenciales se suministran mediante variables de entorno del sistema o AWS Secrets Manager.
- Segregacion de despliegue: la separacion en carpetas (`apps`, `kafka`, `mq`) permite desplegar cada componente de manera independiente en instancias EC2 especificas (`ec2-apps`, `ec2-kafka`, `ec2-mq`) o en un entorno de desarrollo local consolidado.
- Red interna: todo nuevo contenedor o servicio agregado debe asociarse explicitamente a la red `digitalfix-net` para garantizar la resolucion DNS y conectividad entre microservicios y brokers.
- Trazabilidad: todo Pull Request mergeado debe estar vinculado a un Issue, verificable directamente en GitHub; no se aceptan cierres manuales de tarjetas sin codigo asociado.
