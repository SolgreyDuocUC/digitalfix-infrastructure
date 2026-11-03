# ==============================================================================
# DIGITALFIX - VALORES DE VARIABLES
# ==============================================================================
# ¡ESTE ARCHIVO CONTIENE SECRETOS! Está en .gitignore.
# NO hacer commit ni push de este archivo.
# ==============================================================================

aws_region   = "us-east-1"
project_name = "digitalfix"

# --- Red ---
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
availability_zone  = "us-east-1a"

# --- EC2 ---
instance_type = "t3.medium"

# Nombre del Key Pair que se creará en AWS (debe coincidir con ssh_public_key_path)
key_name = "digitalfix-server"

# Ruta LOCAL a la clave PÚBLICA (.pub) para crear el Key Pair en AWS.
# Si ya tienes el par de claves, genera el .pub con:
#   ssh-keygen -y -f digitalfix-server.pem > digitalfix-server.pub
ssh_public_key_path = "~/.ssh/digitalfix-server.pub"

# AMI Amazon Linux 2023 x86_64 en us-east-1 (actualizar si cambia)
ami_id = "ami-0453ec754f44f9a4a"

# --- Puertos ---
frontend_port = 4200
bff_port      = 8090

# --- Base de Datos Oracle Autonomous ---
spring_datasource_url      = "jdbc:oracle:thin:@clx44joct2djmlz9_high?TNS_ADMIN=./wallet"
spring_datasource_username = "ADMIN"
spring_datasource_password = "Anastasia1110."   # <-- cambiar si es necesario

# --- Microsoft Entra ID ---
azure_tenant_id = "3fb8463e-0e33-4b7d-adc1-2a47c707831e"
azure_client_id = "9494b59c-9c6e-4a0f-91ae-ae90212882e7"

# --- RabbitMQ ---
rabbitmq_password      = "admin123"
rabbitmq_erlang_cookie = "23fac817ff9971a988f2a6320c458db2e7e4c5c0b0df2516"

# --- SMTP (ms-notify) ---
spring_mail_host     = "smtp.mailtrap.io"
spring_mail_port     = 2525
spring_mail_username = ""   # <-- rellenar con tu usuario SMTP
spring_mail_password = ""   # <-- rellenar con tu password SMTP
