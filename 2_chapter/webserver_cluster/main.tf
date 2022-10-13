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

    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"

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


# Let's create the load balancer resource:
resource "aws_lb" "example" {
    name = "terraform-asg-example"
    load_balancer_type =  "application"
    subnets = data.aws_subnets.default.ids
    # We need to assign the security group
    security_groups = [aws_security_group.alb.id]
}

# Then, we create a target group for our ASG using the aws_lb_target_group resource
resource "aws_lb_target_group" "asg" {
    name = "terraform-asg-example"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

# Now we define a listener for the ALB (Application Load Balancer)
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = 80
    protocol = "HTTP"

    # By default, return a simple 404 page
    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: Page Not Found"
        status_code = 404
      }
    }
}

# By default, AWS resources, including ALBs do NOT allow incoming
# or outgoing traffic. You need to create a new security group
# specifically for the ALB.

resource "aws_security_group" "alb" {
    name = "terraform-example-alb"

    # Allow inbound HTTP requests
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow all outbound requests
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100
    condition {
        path_pattern {
          values = ["*"]
        }
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
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


output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "The domain name of the load balancer."
}
