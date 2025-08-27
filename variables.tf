variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

variable "public_subnet_cidr" {
  default = "172.16.1.0/24"
}

variable "instance_type" {
  default = "t2.micro"
}
