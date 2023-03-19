provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

# Create VPC

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "production"
    }
}

# Create Internet Gateway

resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.main.id}"
}

# Create Custom Route Table

resource "aws_route_table" "prod-route-table" {
    vpc_id = "${aws_vpc.main.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }

    # route {
    #     ipv6_cidr_block = "::/0"
    #     egress_only_gateway_id = "${aws_internet_gateway.gw.id}"
    # }

    tags = {
        Name = "prod"
    }
}

# Create a Subnet

resource "aws_subnet" "subnet-1" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "prod-subnet"
    }
}

# Associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id = "${aws_subnet.subnet-1.id}"
  route_table_id = "${aws_route_table.prod-route-table.id}"
}

# Create security group to allow port 22,80,443

resource "aws_security_group" "allow_web_trafic" {
    name = "allow_web_trafic"
    description = "Allow Web Trafic"
    vpc_id = "${aws_vpc.main.id}"

    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS"
        from_port = 443
        protocol = "tcp"
        to_port = 443
    }

    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTP"
        from_port = 80
        protocol = "tcp"
        to_port = 80
    }

    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        description = "SSH"
        from_port = 22
        protocol = "tcp"
        to_port = 22
    }

    egress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port = 0
        protocol = "-1"
        to_port = 0
    }
}

# Create Network Interface

resource "aws_network_interface" "web-server-nic" {
    subnet_id = "${aws_subnet.subnet-1.id}"
    private_ips = ["10.0.1.50"]
    security_groups = ["${aws_security_group.allow_web_trafic.id}"]
}

# Assign an elastic ip address to the network interface

resource "aws_eip" "eip" {
    vpc = true
    network_interface = "${aws_network_interface.web-server-nic.id}"
    associate_with_private_ip = "10.0.1.50"
    depends_on = [
      aws_internet_gateway.gw
    ]
}

# Create Ubuntu Server

resource "aws_instance" "web-server-instance" {
    ami = "ami-0557a15b87f6559cf"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "ubuntu-custom-terraform"

    network_interface {
      device_index = 0
      network_interface_id = "${aws_network_interface.web-server-nic.id}"
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF

    tags = {
        Name = "ubuntu custom"
    }
}

# resource "aws_vpc" "first_vpc" {
#     cidr_block = "10.0.0.0/16"
#     tags = {
#         Name = "production"
#     }
# }

# resource "aws_vpc" "second_vpc" {
#     cidr_block = "10.0.0.0/16"
#     tags = {
#         Name = "dev"
#     }
# }

# resource "aws_subnet" "subnet-1" {
#     vpc_id = "${aws_vpc.first_vpc.id}"
#     cidr_block = "10.0.1.0/24"

#     tags = {
#         Name = "prod-subnet"
#     }
# }

# resource "aws_subnet" "subnet-2" {
#     vpc_id = "${aws_vpc.second_vpc.id}"
#     cidr_block = "10.0.1.0/24"

#     tags = {
#         Name = "dev-subnet"
#     }
# }

# resource "aws_instance" "my_first_server" {
#     ami = "ami-0557a15b87f6559cf"
#     instance_type = "t2.micro"

#     tags = {
#         Name = "ubuntu terraform"
#     }
# }