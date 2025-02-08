//Definir tipo de serviço (AWS) e região
provider "aws" {
  region = "us-east1"
}

//Definindo e criando a VPC = Rede privada (MUITO IMPORTANTE)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16" //Isso define o tamanho da rede

  tags = {
    Name = "Minha-primeira-VPC"
  }
}

//Criando SubNet pública dentro da VPC
resource "aws_subnet" "public_subnet" {

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/14" //Significa que essa subnet terá 256 IPS
  map_public_ip_on_launch = true          //Todo servidor que rodar aqui vai ganhar um Public ip automaticamente
  availability_zone       = "us-east-1a"  //ZONA especifica dentro da REGIAO

  tags = {
    Name = "PublicSubnet"
  }
}

//Criando SubNet Privada (Onde vai ficar o DB ou serviços internos)
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24" //Outra subnet com XXX IPS disponiveis
  availability_zone = "us-east-1b"  //Definindo outra zona para melhor resiliência

  tags = {
    Name = "PrivateSubnet"
  }
}

#Criando o internet Gateway 
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id #associa à sua VPC

  tags = {
    Name = "MeuInternetGateway"
  }
}

# Criar uma Tabela de Rotas para a Subnet Pública
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  #Cria rota que envia todo o trafego para a internet via IGW route
  route = {
    cidr_block = "0.0.0.0/0"             # Permite saída para qualquer destino
    gateway_id = aws_internet_gateway.id # Passa pelo Internet Gateway
  }

  tags = {
    Name = "PublicRouteTable"
  }
}
# Associar a Tabela de Rotas à Subnet Publica
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#Criando a Chave SSH para acessar a EC2
resource "aws_key_pair" "my_key" {
  key_name   = "minha-chave-ssh"
  public_key = file("~/.ssh/id_rsa.pub") #Chave pública para permitir acesso seguro à instância

}

#Criando Security Group para a EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Permite acesso SSH e HTTP"
  vpc_id      = aws_vpc.main.id
  #Permite conectar na EC2 via terminal  (SSH = porta 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #Permite rodar um servidor web (HTTP = porta 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #Permite saída de qualquer porta (egress = para que a instância possa baixar pacotes)   
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
#Criar uma Instância EC2!
resource "aws_instance" "n" {
  ami             = "ami-085ad6ae776d8f09c"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.ec2_sg.name]
  key_name        = aws_key_pair.my_key.key_name

  tags = {
    Name = "MeuServidorEC2"
  }
}
#Criando um Elastic IP (IP-Estatico para a EC2)
resource "aws_eip" "elastic_ip" {
  domain = "vpc"

  tags = {
    Name = "MeuElasticIP"
  }
}
#Associando o Elastic IP ao EC2!
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.elastic_ip.id
}

#Criando o security group do load balancer
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Permite acesso HTTP e HTTPS"
  vpc_id      = aws_vpc.main.id

  # Permitir acesso HTTP (porta 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir saída para qualquer destino
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB_SecurityGroup"
  }
}
#Criando o APPLICATION-LOADBALANCER
resource "aws_lb" "app_load_balancer" {
  name               = "meu-loadlancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet.id]

  tags = {
    name = "MeuALB"
  }

}
# Criando o Target Group (Define para onde o LB vai enviar o tráfego)
resource "aws_lb_target_group" "alb_tg" {
  name     = "meu-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    name = "MeuTargetGroup"
  }
}
#Registrar a EC2 no Load Balancer (Adiciona o EC2 como destino do loadBalancer)
resource "aws_lb_target_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = "aws_instance.web.id"
  port             = 80
}
#Criar a Regra de Encaminhamento ou "Listener"
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.app_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}
# Criando Launch Template OU modelos de instâncias EC2 para o auto scalling
resource "aws_launch_template" "lt_web" {
  name_prefix   = "web-template"
  image_id      = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_key.key_name

#Configura segurança e rede (Security Group, IP público..)
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
    subnet_id                   = aws_subnet.public_subnet.id
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "InstanciaAutoScaling"
    }
  }
}
#Criando o Auto-Scaling-Group (ASG)
resource "aws_autoscaling_group" "asg_web" {
  desired_capacity = 2
  min_size = 1
  max_size = 3
  vpc_zone_identifier = [aws_subnet.public_subnet.id]
  launch_template {
    id = aws_launch_template.lt_web.id
    version = "$Lastest"
  }

  tag {
    key                 = "Name"
    value               = "ASG-Instance"
    propagate_at_launch = true
  }
}