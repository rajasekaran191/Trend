provider "aws" {
  region = "ap-south-1"
}

# ---------------- VPC ----------------
resource "aws_vpc" "trend_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "trend-vpc"
  }
}

# ---------------- Subnet 1 ----------------
resource "aws_subnet" "trend_subnet" {
  vpc_id                  = aws_vpc.trend_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "trend-subnet-1"
  }
}

# ---------------- Subnet 2 ----------------
resource "aws_subnet" "trend_subnet2" {
  vpc_id                  = aws_vpc.trend_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "trend-subnet-2"
  }
}

# ---------------- Internet Gateway ----------------
resource "aws_internet_gateway" "trend_igw" {
  vpc_id = aws_vpc.trend_vpc.id

  tags = {
    Name = "trend-igw"
  }
}

# ---------------- Route Table ----------------
resource "aws_route_table" "trend_rt" {
  vpc_id = aws_vpc.trend_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.trend_igw.id
  }

  tags = {
    Name = "trend-route-table"
  }
}

# ---------------- Route Table Association ----------------
resource "aws_route_table_association" "subnet1_association" {
  subnet_id      = aws_subnet.trend_subnet.id
  route_table_id = aws_route_table.trend_rt.id
}

resource "aws_route_table_association" "subnet2_association" {
  subnet_id      = aws_subnet.trend_subnet2.id
  route_table_id = aws_route_table.trend_rt.id
}

# ---------------- Security Group ----------------
resource "aws_security_group" "trend_sg" {
  name        = "trend-sg"
  description = "Allow SSH and Web"
  vpc_id      = aws_vpc.trend_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins Port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "trend-sg"
  }
}

# ---------------- Jenkins EC2 ----------------
resource "aws_instance" "jenkins" {

  ami           = "ami-019715e0d74f695be"
  instance_type = "c7i-flex.large"
  subnet_id     = aws_subnet.trend_subnet.id
  key_name      = "devopsraja_newkey"

  vpc_security_group_ids = [aws_security_group.trend_sg.id]

  user_data = <<-EOF
              #!/bin/bash

              # Update system
              sudo apt update -y

              # Install Docker
              sudo apt install docker.io -y
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu

              # Install Java for Jenkins
              sudo apt install fontconfig openjdk-21-jre -y

              #jenkins install
              sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
               https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
              echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
                https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
                /etc/apt/sources.list.d/jenkins.list > /dev/null
              sudo apt update -y
              sudo apt install jenkins -y

              # Install unzip (required for AWS CLI)
              sudo apt install unzip -y

              # Download AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

              # Unzip AWS CLI
              unzip awscliv2.zip

              # Install AWS CLI
              sudo ./aws/install

              # Verify AWS CLI
              aws --version

              # Install kubectl
              curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
              sudo chmod +x kubectl
              sudo mv kubectl /usr/local/bin/

              EOF

  tags = {
    Name = "jenkins-server"
  }
}
