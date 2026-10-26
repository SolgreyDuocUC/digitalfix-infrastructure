# ==============================================================================
# DIGITALFIX - RED (VPC, Subred Pública, Internet Gateway, Rutas)
# ==============================================================================
# Layout minimalista para una única EC2 pública:
#   VPC (10.0.0.0/16)
#    └─ Subred pública (10.0.1.0/24) us-east-1a
#        └─ EC2 DigitalFix (IP pública asignada automáticamente + Elastic IP)
# ==============================================================================

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# --- Subred pública ---
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public"
    Project = var.project_name
  }
}

# --- Tabla de rutas pública ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Elastic IP para la EC2 (IP fija aunque la instancia se reinicie) ---
resource "aws_eip" "ec2" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}

resource "aws_eip_association" "ec2" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.ec2.id
}
