#!/bin/bash

ssh-add -q ~/.ssh/shaurya-bastion-key.pem 2>/dev/null

ssh \
  -A \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i ~/.ssh/shaurya-bastion-key.pem \
  -J ec2-user@"$(terraform output -raw bastion_public_ip)" \
  ec2-user@"$(terraform output -raw webserver_private_ip)"
