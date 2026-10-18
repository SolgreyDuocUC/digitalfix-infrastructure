# Guía de Contenedores y Orquestación de Microservicios

Este documento contiene la información técnica, especializada y concisa para desplegar, operar y monitorear todos los contenedores y microservicios de la plataforma **DigitalFix**.

---

## Tabla de Microservicios, Contenedores y Puertos

| Servicio | Nombre Contenedor | Puerto Host | Puerto Contenedor | Swagger / Endpoint Principal | Tecnología |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Frontend Web** | `digitalfix-frontend` | `4200` | `4000` | [http://localhost:4200](http://localhost:4200) | Angular 19 (SSR / Node 20) |
| **MS Login** | `ms-login-service` | `8081` | `8081` | [http://localhost:8081/swagger-ui.html](http://localhost:8081/swagger-ui.html) | Java 21 / Spring Boot 4 / Azure AD |
| **MS User** | `ms-user-service` | `8082` | `8082` | [http://localhost:8082/swagger-ui.html](http://localhost:8082/swagger-ui.html) | Java 21 / Spring Boot 4 / Oracle JPA |
| **MS Notify** | `ms-digitalfix-notify` | `8083` | `8083` | [http://localhost:8083/swagger-ui.html](http://localhost:8083/swagger-ui.html) | Java 21 / Spring AMQP / Mail |
| **MS Catalog** | `ms-catalog-service` | `8084` | `8080` | [http://localhost:8084/swagger-ui.html](http://localhost:8084/swagger-ui.html) | Java 21 / Spring Boot 4 / Oracle JPA |
| **MS Workorders** | `ms-workorders-service` | `8085` | `8080` | [http://localhost:8085/swagger-ui.html](http://localhost:8085/swagger-ui.html) | Java 21 / Spring Boot 4 / Oracle JPA |
| **RabbitMQ Broker** | `digitalfix-rabbitmq` | `5672` | `5672` | `amqp://localhost:5672` | RabbitMQ 3.12 Alpine |
| **RabbitMQ Web** | `digitalfix-rabbitmq` | `15672` | `15672` | [http://localhost:15672](http://localhost:15672) (`admin` / `admin123`) | Consola de Gestión AMQP |

---

## 1. Despliegue Centralizado (Toda la Plataforma)

Desde la carpeta `digitalfix-infrastructure` puedes construir y levantar todos los microservicios, el broker de mensajería y el frontend con **un solo comando**:

### Levantar todos los servicios:
```powershell
cd digitalfix-infrastructure
docker compose up -d --build
```

### Detener todos los servicios:
```powershell
docker compose down
```

### Ver estado de los contenedores:
```powershell
docker compose ps
```

### Ver logs en tiempo real:
```powershell
# Logs de todos los servicios
docker compose logs -f

# Logs de un microservicio específico
docker compose logs -f ms-workorders
docker compose logs -f ms-login
docker compose logs -f frontend
```

---

## 2. Despliegue Individual (Microservicio Específico)

Si prefieres trabajar únicamente en un microservicio de manera aislada:

### Paso previo: Asegurar la red compartida
La mayoría de los microservicios se comunican a través de la red interna de Docker `digitalfix-net`:
```powershell
docker network create digitalfix-net
```

### Comandos por Microservicio:

* **Frontend Web (`digitalfix-frontend/frontend`)**:
  ```powershell
  cd digitalfix-frontend/frontend
  docker compose up -d --build
  ```

* **Microservicio Login (`digitalfix-ms-login`)**:
  ```powershell
  cd digitalfix-ms-login
  docker compose up -d --build
  ```

* **Microservicio User (`digitalfix-ms-user`)**:
  ```powershell
  cd digitalfix-ms-user
  docker compose up -d --build
  ```

* **Microservicio Workorders (`digitalfix-ms-workorders`)**:
  ```powershell
  cd digitalfix-ms-workorders
  docker compose up -d --build
  ```

* **Microservicio Catalog (`digitalfix-ms-catalog`)**:
  ```powershell
  cd digitalfix-ms-catalog
  docker compose up -d --build
  ```

* **Microservicio Notify + RabbitMQ (`digitalfix-ms-notify`)**:
  ```powershell
  cd digitalfix-ms-notify
  docker compose up -d --build
  ```

---

## 3. Requisitos y Configuración de Entorno

1. **Archivos `.env`**:
   Cada microservicio debe contar con su archivo `.env` configurado en su respectiva raíz (basado en su `.env.example`).
2. **Oracle Wallet mTLS**:
   Los microservicios que conectan a Oracle Autonomous Database (`login`, `user`, `workorders`, `catalog`, `notify`) requieren tener la carpeta `wallet/` en la raíz de su proyecto con los certificados (`cwallet.sso`, `tnsnames.ora`, etc.). El Docker Compose monta este directorio en modo solo lectura (`/app/wallet:ro`).
3. **Azure AD / Microsoft Entra ID**:
   El frontend expone el puerto `4200` hacia el host para ser compatible con la URL de redirección configurada en Azure AD (`http://localhost:4200`).

---

## 4. Comunicación Interna de Red (`digitalfix-net`)

Dentro de la red Docker compartida, los microservicios pueden comunicarse entre sí mediante sus nombres de servicio DNS internos:

| Destino | Host Interno en Docker | Puerto Interno |
| :--- | :--- | :--- |
| **RabbitMQ** | `rabbitmq` | `5672` |
| **MS Login** | `ms-login` | `8081` |
| **MS User** | `ms-user` | `8082` |
| **MS Notify** | `ms-notify` | `8083` |
| **MS Catalog** | `ms-catalog` | `8080` |
| **MS Workorders** | `ms-workorders` | `8080` |

---

## 5. Diagnóstico y Troubleshooting

* **Reiniciar un contenedor específico sin apagar el resto:**
  ```powershell
  docker compose restart ms-workorders
  ```
* **Recompilar un microservicio tras modificar código Java o Angular:**
  ```powershell
  docker compose up -d --build ms-workorders
  ```
* **Acceder al bash/shell de un contenedor:**
  ```powershell
  docker exec -it ms-workorders-service sh
  ```
* **Limpiar volúmenes e imágenes huérfanas:**
  ```powershell
  docker compose down --volumes --remove-orphans
  ```
