#!/bin/bash

ssh -A \
    -i ~/.ssh/shaurya-bastion-key.pem \
    ec2-user@"$(terraform output -raw bastion_public_ip)"
