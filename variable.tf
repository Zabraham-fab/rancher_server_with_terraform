
variable "region" {
  default = "us-east-1"
}

variable "mykey" {
  default = "project-rancher"
}
variable "tags" {
  default = "project-rancher-server"
}
variable "myami" {
  description = "ubuntu 20.04 ami"
  default     = "ami-0778521d914d23bc1"
}
variable "instancetype" {
  default = "t3a.medium"
}

variable "vpc" {
  default = "vpc-0e60287xxxxxxxxxx"
}

variable "subnet_ids" {
  type = list(string)
  default = [
    "subnet-057b416f4xxxxxxxx",
    "subnet-003551fb8xxxxxxxx",
    "subnet-05e5703b6xxxxxxxx"
  ]
}

variable "secgrname" {
  default = "rancher-server-sec-gr"
}

variable "domain-name" {
  default = "fbingolcloud.store"
}

variable "rancher-subnet" {
  default = "subnet-057b416f4xxxxxxxx"
}

variable "hostedzone" {
  default = "xxxxxxxxxx.store"
}

variable "pem_path" {
  default = "~/.ssh"
}
