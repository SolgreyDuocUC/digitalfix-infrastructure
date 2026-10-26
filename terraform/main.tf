# ==============================================================================
# DIGITALFIX - MAIN.TF
# ==============================================================================
# Punto de entrada de Terraform. Los recursos están organizados en archivos
# separados por responsabilidad:
#
#   provider.tf    -> Proveedor AWS y LabRole de Academy
#   variables.tf   -> Declaración de todas las variables
#   network.tf     -> VPC, subnet pública, IGW, rutas y Elastic IP
#   ec2.tf         -> Key Pair, Security Group e instancia EC2
#   outputs.tf     -> Valores de salida (IP, URLs, comandos SSH)
#
# Archivos de valores:
#   terraform.tfvars -> Valores reales (secretos, IDs, etc.) — en .gitignore
#
# Script de bootstrap de la EC2:
#   userdata.sh.tpl  -> Se ejecuta al primer arranque de la instancia
#
# Uso básico:
#   cd digitalfix-infrastructure/terraform
#   terraform init
#   terraform plan
#   terraform apply
#   terraform destroy  # para limpiar todo al terminar el lab
# ==============================================================================
