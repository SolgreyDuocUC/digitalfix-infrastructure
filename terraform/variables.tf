# ==============================================================================
# DIGITALFIX - VARIABLES
# ==============================================================================

variable "aws_region" {
  description = "Región AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para nombrar todos los recursos AWS"
  type        = string
  default     = "digitalfix"
}

# ------------------------------------------------------------------------------
# Red
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Bloque CIDR de la subred pública donde vivirá la EC2"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Zona de disponibilidad para la subred pública"
  type        = string
  default     = "us-east-1a"
}

# ------------------------------------------------------------------------------
# EC2
# ------------------------------------------------------------------------------
variable "instance_type" {
  description = "Tipo de instancia EC2 (mínimo t3.medium para correr todos los contenedores)"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Nombre del Key Pair en AWS que se usará para SSH"
  type        = string
  # Valor real se define en terraform.tfvars
}

variable "ssh_public_key_path" {
  description = "Ruta LOCAL al archivo .pub de tu clave SSH para crear el Key Pair en AWS"
  type        = string
  default     = "~/.ssh/digitalfix-server.pub"
}

variable "ami_id" {
  description = "AMI de Amazon Linux 2023 en us-east-1 (actualizar si cambias de región)"
  type        = string
  # Amazon Linux 2023 x86_64 en us-east-1 (octubre 2026)
  default     = "ami-0453ec754f44f9a4a"
}

# ------------------------------------------------------------------------------
# Puertos públicos expuestos por la EC2
# ------------------------------------------------------------------------------
variable "frontend_port" {
  description = "Puerto del host donde escucha el frontend Angular SSR"
  type        = number
  default     = 4200
}

variable "bff_port" {
  description = "Puerto del host donde escucha el BFF/API Gateway"
  type        = number
  default     = 8090
}

# ------------------------------------------------------------------------------
# Repositorio
# ------------------------------------------------------------------------------
variable "git_repo_infrastructure" {
  description = "URL HTTPS del repo digitalfix-infrastructure"
  type        = string
  default     = "https://github.com/SolgreyDuocUC/digitalfix-infrastructure.git"
}

variable "git_repos" {
  description = "Mapa de repos a clonar en la EC2 (nombre => URL)"
  type        = map(string)
  default = {
    "digitalfix-bff-gateway"    = "https://github.com/SolgreyDuocUC/digitalfix-bff-gateway.git"
    "digitalfix-frontend"       = "https://github.com/Blacknight3648/digitalfix-frontend.git"
    "digitalfix-ms-admin-queues"= "https://github.com/Blacknight3648/digitalfix-ms-admin-queues.git"
    "digitalfix-ms-catalog"     = "https://github.com/SolgreyDuocUC/digitalfix-ms-catalog.git"
    "digitalfix-ms-login"       = "https://github.com/Blacknight3648/digitalfix-ms-login.git"
    "digitalfix-ms-notify"      = "https://github.com/Blacknight3648/digitalfix-ms-notify.git"
    "digitalfix-ms-user"        = "https://github.com/Blacknight3648/digitalfix-ms-user.git"
    "digitalfix-ms-workorders"  = "https://github.com/Blacknight3648/digitalfix-ms-workorders.git"
  }
}

# ------------------------------------------------------------------------------
# Variables de entorno de la aplicación (se inyectan en el .env de la EC2)
# Los valores sensibles deben ir en terraform.tfvars (que está en .gitignore)
# ------------------------------------------------------------------------------
variable "spring_datasource_url" {
  description = "JDBC URL del Oracle Autonomous (TNS Alias)"
  type        = string
  default     = "jdbc:oracle:thin:@clx44joct2djmlz9_high?TNS_ADMIN=./wallet"
}

variable "spring_datasource_username" {
  description = "Usuario de base de datos Oracle"
  type        = string
  default     = "ADMIN"
}

variable "spring_datasource_password" {
  description = "Password de base de datos Oracle"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Tenant ID de Microsoft Entra ID (Azure AD)"
  type        = string
  default     = "3fb8463e-0e33-4b7d-adc1-2a47c707831e"
}

variable "azure_client_id" {
  description = "Client ID de la App Registration en Entra ID"
  type        = string
  default     = "9494b59c-9c6e-4a0f-91ae-ae90212882e7"
}

variable "rabbitmq_password" {
  description = "Password del usuario administrador de RabbitMQ"
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "rabbitmq_erlang_cookie" {
  description = "Cookie de Erlang para el cluster RabbitMQ"
  type        = string
  sensitive   = true
  default     = "23fac817ff9971a988f2a6320c458db2e7e4c5c0b0df2516"
}

variable "spring_mail_host" {
  description = "Host del servidor SMTP para ms-notify"
  type        = string
  default     = "smtp.mailtrap.io"
}

variable "spring_mail_port" {
  description = "Puerto del servidor SMTP"
  type        = number
  default     = 2525
}

variable "spring_mail_username" {
  description = "Usuario del servidor SMTP"
  type        = string
  default     = ""
}

variable "spring_mail_password" {
  description = "Password del servidor SMTP"
  type        = string
  sensitive   = true
  default     = ""
}
