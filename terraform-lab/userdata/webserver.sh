#!/bin/bash


dnf install nginx -y
systemctl enable nginx
systemctl start nginx
echo "<h1>Hello Terraform</h1>" > /usr/share/nginx/html/index.html

