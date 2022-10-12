
# Specify a provider.
provider "aws" {
  region = "us-east-2"
}


# We specify a resource and give it a name. In this case, "example."
resource "aws_instance" "example" {

  # "ami" and "instance_type" are two required arguments.
  ami                    = "ami-0fb653ca2d3203ac1"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  # Run a shell script that uses Bosybox to run web server on 8080.
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, world." > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "terror_form_halloween_edition"
  }
}

# AWS does not allow traffic in or out of EC2 instances by defualt.
# You have to conifgure a security group.

# First, let's set a variable.

variable "server_port" {
  description = "The port the server will use for HTTP requests."
  type = number
  default = 8080
} 

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


output "public_ip" {
  value = aws_instance.example.public_ip
  description = "This is the public IP of my AWS EC2 Instance."

}

