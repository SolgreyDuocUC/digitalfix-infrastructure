# ==============================================================================
# DIGITALFIX - PROVEEDOR AWS
# ==============================================================================
# Usa las credenciales de sesión de AWS Academy (variables de entorno o
# ~/.aws/credentials). NO hardcodees claves aquí.
#
# Para autenticarte antes de ejecutar:
#   export AWS_ACCESS_KEY_ID=...
#   export AWS_SECRET_ACCESS_KEY=...
#   export AWS_SESSION_TOKEN=...
#   export AWS_DEFAULT_REGION=us-east-1
# ==============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Rol LabRole propio de AWS Academy — se usa como instance profile de la EC2
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Instance profile que envuelve el LabRole (debe existir en Academy)
data "aws_iam_instance_profile" "lab_instance_profile" {
  name = "LabInstanceProfile"
}
