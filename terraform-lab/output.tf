output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
output "bastion_id" {
  value = aws_instance.bastion.id
}

output "webserver_private_ip" {
  value = aws_instance.webserver.private_ip
}

output "webserver_id" {
  value = aws_instance.webserver.id
}
