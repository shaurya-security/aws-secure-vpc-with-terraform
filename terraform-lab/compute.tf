resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  user_data     = templatefile("${path.module}/userdata/common.sh", {})

metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}

root_block_device {
  encrypted = true
}

  tags = { Name = local.bastion_ec2_name }

}

resource "aws_instance" "webserver" {

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  user_data     = templatefile("${path.module}/userdata/common.sh", {})

metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}
root_block_device {
  encrypted = true
}

  tags = { Name = local.webserver_ec2_name }

}
