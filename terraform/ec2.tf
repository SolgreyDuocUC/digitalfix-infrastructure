# ==============================================================================
# DIGITALFIX - INSTANCIA EC2
# ==============================================================================
# Una sola EC2 t3.medium que orquesta toda la plataforma con Docker Compose.
#
# Flujo del user_data (bootstrap al primer arranque):
#   1. Instala Docker + Docker Compose plugin + Git
#   2. Crea el directorio ~/DigitalFix y clona digitalfix-infrastructure (rama deploy)
#   3. Clona los repositorios de los microservicios (rama deploy) como carpetas hermanas
#   4. Escribe el archivo .env centralizado con las variables de entorno
#   5. Levanta docker compose up -d desde digitalfix-infrastructure
# ==============================================================================

# --- Key Pair (sube tu clave pública para SSH) ---
# Si ya tienes un Key Pair creado en AWS con este nombre, comenta este recurso
# y usa directamente var.key_name en aws_instance.
resource "aws_key_pair" "digitalfix" {
  key_name   = var.key_name
  public_key = file(var.ssh_public_key_path)

  tags = {
    Name    = "${var.project_name}-keypair"
    Project = var.project_name
  }
}

# --- Security Group ---
resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Security group unico para la EC2 DigitalFix"
  vpc_id      = aws_vpc.main.id

  # SSH (restringir a tu IP en produccion real)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Cambia a tu IP: ["x.x.x.x/32"]
  }

  # Frontend Angular SSR
  ingress {
    description = "Frontend (Angular SSR)"
    from_port   = var.frontend_port
    to_port     = var.frontend_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # BFF / API Gateway
  ingress {
    description = "BFF Gateway"
    from_port   = var.bff_port
    to_port     = var.bff_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RabbitMQ Management UI (acceso local via tunel SSH recomendado, pero abrir aqui para lab)
  ingress {
    description = "RabbitMQ Management"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Todo el trafico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# --- EC2 Instance ---
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.digitalfix.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab_instance_profile.name

  root_block_device {
    volume_size           = 30  # GB — suficiente para Docker images de todos los servicios
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # ------------------------------------------------------------------
  # user_data: bootstrap ejecutado UNA SOLA VEZ al primer arranque.
  # Instala dependencias, clona repos, escribe .env y levanta compose.
  # ------------------------------------------------------------------
  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    project_name               = var.project_name
    git_repo_infrastructure    = var.git_repo_infrastructure
    git_repos                  = var.git_repos
    frontend_port              = var.frontend_port
    bff_port                   = var.bff_port

    spring_datasource_url      = var.spring_datasource_url
    spring_datasource_username = var.spring_datasource_username
    spring_datasource_password = var.spring_datasource_password

    azure_tenant_id            = var.azure_tenant_id
    azure_client_id            = var.azure_client_id

    rabbitmq_password          = var.rabbitmq_password
    rabbitmq_erlang_cookie     = var.rabbitmq_erlang_cookie

    spring_mail_host           = var.spring_mail_host
    spring_mail_port           = var.spring_mail_port
    spring_mail_username       = var.spring_mail_username
    spring_mail_password       = var.spring_mail_password
  }))

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
  }
}
