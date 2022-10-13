terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 4.0"
    }
  }
}

provider "aws" {
    region = "us-east-2"
}

# Resource block. We create "aws_launch_configuration."
# We call it "example." We can name it anything.
resource "aws_launch_configuration" "example" {
    # We set an image_id (AMI is amazon machine image).
    # We set an instance type: t2.micro.
    image_id = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"

    security_groups = [aws_security_group.instance.id]
    
    # We use "user_data" to run a shell script.
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello World" > index.html
                # The shell script contains a variable, our server port.
                # We use "var.server_port" to set it. 
                nohup busybox httpd -f -p ${var.server_port} &
                EOF

    # Required when using a launch configuration 
    # with an auto-scaling group.
    lifecycle {
      create_before_destroy = true
    }
  
}

# Next resource block. We have our "aws_autoscaling_group"
# We call it "example."
resource "aws_autoscaling_group" "example" {
    # Notice the "aws_launch_configuration" up at the start of the code?
    # That gets called here.
    launch_configuration = aws_launch_configuration.example.name
    
    # We set out vpc_zone_identifier to:
    # data.aws_subnets.default.ids
    # We pass it data, which we use the aws_subnets listed below
    vpc_zone_identifier = data.aws_subnets.default.ids

    # We set a min and max size. Defaults to 2.
    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch =  true
    } 
}

# We can set our server_port variable here with a default value of 8080
# Notice the number constraint. It hast to be a number.
variable "server_port" {
    description = "The port the server will use for HTTP requests."
    type = number
    default = 8080
}

# We create a resource using the "aws_security_group" and name it "instance"
resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# We can call a data source. The aws_vpc 
# default will show us our provider (aws_vpc)
# The name we want to refer to it as (default)
# then the configuration inside the curly braces.
# is different from the "name" we gave it
# It's just saying we want to see our default VPC

data "aws_vpc" "default" {
    default = true
}

# We can see this stuff called in the second resource block.
data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

