
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
              nohup busybox httpd -f -p 8080 &
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "terrafart"
  }
}

# AWS does not allow traffic in or out of EC2 instances by defualt.
# You have to conifgure a security group.

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

