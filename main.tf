provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "basic-vpc"
  }
}

# public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "basic-igw"
  }
}

# public route table static route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public-rt"
  }
}

# link public subnet to igw route
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# sg to allow ssh
resource "aws_security_group" "ssh" {
  name   = "allow-ssh"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # more secure to put specific ip when possible
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh in allow all out"
  }
}

# create key for access to public ec2
resource "tls_private_key" "rsa_example" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

# create key pair for access to public ec2
resource "aws_key_pair" "ec2_pair" {
    key_name   = "my-generated-ssh-key"
    public_key = tls_private_key.rsa_example.public_key_openssh
}

# save key locally to be able to ssh to public ec2
resource "local_file" "private_key_file" {
  content  = tls_private_key.rsa_example.private_key_pem
  filename = "ec2_private_key.pem"
  file_permission = "0400" # local permissions for file
}

# create public ec2
resource "aws_instance" "public_ec2" {
  ami                    = "ami-00ca32bbc84273381" # free tier aws linux 2 in us-east-1
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh.id]
  associate_public_ip_address = true
  key_name      = aws_key_pair.ec2_pair.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  user_data     = <<-EOF
    #!/bin/bash
    echo "test" > /tmp/test.txt
    sudo apt-get update -y
    sudo apt install -y awscli
    chmod 666 /tmp/test.txt
    EOF
  tags = {
    Name = "public-ec2"
  }
}

# output to get public ip of public ec2
output "ec2_public_ip" {
          description = "public IP address of public EC2 instance."
          value       = aws_instance.public_ec2.public_ip
        }

### create iam policy

# ec2 role to allow access to s3
resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ec2 role policy to specify allowed actions on one bucket
resource "aws_iam_role_policy" "s3_policy" {
  name = "s3-access-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ],
        Resource = "arn:aws:s3:::my-versioned-bucket-2025133"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "arn:aws:s3:::my-versioned-bucket-2025133/*"
      }
    ]
  })
}

# iam instance profile for role
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-instance-profile"
  role = aws_iam_role.ec2_role.name
}

###

# create s3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "my-versioned-bucket-2025133"
  force_destroy = true # had to add this so i could delete it programmatically

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

# enable versioning for the bucket
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = [
    aws_route_table.public.id
  ]
}