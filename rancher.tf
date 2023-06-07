terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region                  = var.region
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "default"
}

provider "tls" {}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.mykey
  public_key = tls_private_key.example.public_key_openssh
}

output "private" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

resource "aws_instance" "tf-rancher-server" {
  ami                    = var.myami
  instance_type          = var.instancetype
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.tf-rancher-sec-gr.id]
  iam_instance_profile   = aws_iam_instance_profile.profile_for_rancher.name
  subnet_id              = var.rancher-subnet
  root_block_device {
    volume_size = 16
  }
  user_data = file("rancherdata.sh")
  tags = {
    Name                                    = var.tags
    "kubernetes.io/cluster/project-Rancher" = "owned"
  }
}

resource "aws_alb_target_group" "rancher-tg" {
  name        = "project-rancher-http-80-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }
}

resource "aws_alb_target_group_attachment" "rancher-attach" {
  target_group_arn = aws_alb_target_group.rancher-tg.arn
  target_id        = aws_instance.tf-rancher-server.id
}

data "aws_vpc" "selected" {
  default = true
}

resource "aws_lb" "rancher-alb" {
  name               = "project-rancher-alb"
  ip_address_type    = "ipv4"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.rancher-alb.id]
}

data "aws_acm_certificate" "cert" {
  domain      = var.domain-name
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_alb_listener" "rancher-listener1" {
  load_balancer_arn = aws_lb.rancher-alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.rancher-tg.arn
  }
}
resource "aws_alb_listener" "rancher-listener2" {
  load_balancer_arn = aws_lb.rancher-alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_iam_policy" "policy_for_rke-controlplane_role" {
  name   = "project_policy_for_rke-controlplane_role"
  policy = file("rke-controlplane-policy.json")
}

resource "aws_iam_policy" "policy_for_rke_etcd_worker_role" {
  name   = "project_policy_for_rke_etcd_worker_role"
  policy = file("rke-etcd-worker-policy.json")
}

resource "aws_iam_role" "role_for_rancher" {
  name = "project_role_rancher"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "project_role_controlplane_rke"
  }
}

resource "aws_iam_policy_attachment" "attach_for_rancher1" {
  name       = "project_attachment_for_rancher_controlplane"
  roles      = [aws_iam_role.role_for_rancher.name]
  policy_arn = aws_iam_policy.policy_for_rke-controlplane_role.arn
}

resource "aws_iam_policy_attachment" "attach_for_rancher2" {
  name       = "project_attachment_for_rancher_worker"
  roles      = [aws_iam_role.role_for_rancher.name]
  policy_arn = aws_iam_policy.policy_for_rke_etcd_worker_role.arn
}

resource "aws_iam_instance_profile" "profile_for_rancher" {
  name = "profile_for_project_rancher"
  role = aws_iam_role.role_for_rancher.name
}


data "aws_route53_zone" "dns" {
  name = var.hostedzone
}

resource "aws_route53_record" "arecord" {
  name    = "rancher.${data.aws_route53_zone.dns.name}"
  type    = "A"
  zone_id = data.aws_route53_zone.dns.zone_id
  alias {
    name                   = aws_lb.rancher-alb.dns_name
    zone_id                = aws_lb.rancher-alb.zone_id
    evaluate_target_health = true
  }
}

resource "null_resource" "privatekey" {
  depends_on = [tls_private_key.example, aws_instance.tf-rancher-server]

  provisioner "local-exec" {
    command = "if [ ! -f ${var.pem_path}/${var.mykey}.pem ]; then terraform output -raw private > ${var.pem_path}/${var.mykey}.pem; fi"
  }
  provisioner "local-exec" {
    command = "cd ${var.pem_path}/ && chmod 400 ${var.mykey}.pem"
  }
}


# Install RKE, the Rancher Kubernetes Engine
resource "null_resource" "rke_setup" {
  depends_on = [null_resource.privatekey, aws_instance.tf-rancher-server]
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${var.pem_path}/${var.mykey}.pem")
    host        = aws_instance.tf-rancher-server.public_ip
  }
  provisioner "remote-exec" {

    inline = [
      "until grep -q 'userdata installed' /var/log/userdata-install.log; do sleep 35; done",
      "curl -SsL 'https://github.com/rancher/rke/releases/download/v1.4.2/rke_linux-amd64' -o 'rke_linux-amd64'",
      "until sudo mv rke_linux-amd64 /usr/local/bin/rke; do sleep 5; done",
      "until sudo chmod +x /usr/local/bin/rke; do sleep 3; done"
    ]
  }
}
# dosyanın içeriği değişken atanarak oluşturulur
locals {
  rancher_cluster_yml = templatefile("${path.module}/rancher-cluster.yml", { public_ip = aws_instance.tf-rancher-server.public_ip, private_ip = aws_instance.tf-rancher-server.private_ip, domain_name = var.domain-name, mykey = var.mykey })
  public_ip           = aws_instance.tf-rancher-server.public_ip
  private_ip          = aws_instance.tf-rancher-server.private_ip
}


# RKE kümesi oluşturmak için kaynak tanımlama
# rke up komutu çağrılırken değişken kullanılır
resource "null_resource" "rke_cluster_1" {
  depends_on = [aws_instance.tf-rancher-server, null_resource.rke_setup]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.pem_path}/${var.mykey}.pem")
      host        = aws_instance.tf-rancher-server.public_ip
    }

    inline = [
      "echo '${local.rancher_cluster_yml}' > ~/rancher-cluster.yml",
      "sed -i 's/public_ip/${local.public_ip}/g; s/private_ip/${local.private_ip}/g; s/domain_name/${var.domain-name}/g; s/mykey/${var.mykey}/g' ~/rancher-cluster.yml",
      "echo '${file("${var.pem_path}/${var.mykey}.pem")}' > ~/.ssh/${var.mykey}.pem",
      "chmod 400 ~/.ssh/${var.mykey}.pem",
      "until rke up --config ~/rancher-cluster.yml; do sleep 180; done",
      "apt-get update && sudo apt-get install -y apt-transport-https gnupg2 curl; sleep 5",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update; sleep 5",
      "sudo apt-get install -y kubectl; sleep 10"
    ]
  }
}

# .kube/config dosyasına chmod 400 eklenir
resource "null_resource" "kube-config-chmod" {
  depends_on = [null_resource.rke_cluster_1]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.pem_path}/${var.mykey}.pem")
      host        = aws_instance.tf-rancher-server.public_ip
    }
    inline = [
      "mkdir -p ~/.kube; sleep 3",
      "mv ./kube_config_rancher-cluster.yml ~/.kube/config; sleep 3",
      "mv ./rancher-cluster.rkestate ~/.kube/rancher-cluster.rkestate; sleep 3",
      "sudo chmod 400 ~/.kube/config; sleep 3",
      "kubectl get nodes"
    ]
  }
}


resource "null_resource" "rancher_chart_setup" {
  depends_on = [null_resource.kube-config-chmod]

  # Rancher helm chart repositorilerini ekler ve cattle-system adlı bir namespace oluşturur
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.pem_path}/${var.mykey}.pem")
      host        = aws_instance.tf-rancher-server.public_ip
    }
    inline = [
      "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3",
      "chmod 700 get_helm.sh",
      "./get_helm.sh",
      "helm repo add rancher-latest https://releases.rancher.com/server-charts/latest",
      "kubectl create namespace cattle-system"
    ]
  }
}

resource "null_resource" "rancher_helm_install" {
  depends_on = [null_resource.rancher_chart_setup]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.pem_path}/${var.mykey}.pem")
      host        = aws_instance.tf-rancher-server.public_ip
    }

    inline = [
      "helm install rancher rancher-latest/rancher \\",
      "  --namespace cattle-system \\",
      "  --set hostname=${aws_route53_record.arecord.name} \\",
      "  --set tls=external \\",
      "  --set podSecurityPolicy.enabled=false \\",
      "  --set replicas=1; sleep 30"
    ]
  }
}

resource "null_resource" "rancher_cli_install" {
  depends_on = [null_resource.rancher_helm_install]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.pem_path}/${var.mykey}.pem")
      host        = aws_instance.tf-rancher-server.public_ip
    }

    inline = [
      "curl -L https://github.com/rancher/cli/releases/download/v2.4.11/rancher-linux-amd64-v2.4.11.tar.gz -o rancher-cli.tar.gz; sleep 30",
      "tar -xzvf rancher-cli.tar.gz",
      "sudo mv rancher-v2.4.11/rancher /usr/local/bin/"
    ]
  }
}


output "rancher_server_url" {
  value = "http://${aws_route53_record.arecord.name}"
}