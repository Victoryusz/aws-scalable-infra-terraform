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

    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/14" //Significa que essa subnet terá 256 IPS
    map_public_ip_on_launch = true //Todo servidor que rodar aqui vai ganhar um Public ip automaticamente
    availability_zone = "us-east-1a" //ZONA especifica dentro da REGIAO
    
    tags = {
      Name = "PublicSubnet"
    }
  
}

//Criando SubNet Privada (Onde vai ficar o DB ou serviços internos)
resource "aws_subnet" "private_subnet" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24" //Outra subnet com XXX IPS disponiveis
    availability_zone = "us-east-1b" //Definindo outra zona para melhor resiliência

    tags = {
      Name = "PrivateSubnet"
    }
  
}

