# Jenkins EC2 Instance and Elastic IP

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.jenkins_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false
  }

  user_data = file("${path.module}/userdata-jenkins.sh")

  tags = {
    Name        = "jenkins-server"
    Environment = "production"
    Role        = "jenkins"
  }
}

# Elastic IP for Jenkins
resource "aws_eip" "jenkins_eip" {
  domain   = "vpc"
  instance = aws_instance.jenkins.id

  tags = {
    Name = "jenkins-eip"
  }
}
