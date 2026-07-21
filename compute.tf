resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = "shaurya-bastion-key"
  source_dest_check      = false


  user_data = <<-EOF
    #!/bin/bash
    set -e

    # IP forwarding, persisted across reboots via sysctl.d
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-nat.conf

    # AL2023 ships iptables-nft; "iptables-services" (AL2) doesn't exist here
    dnf install -y iptables

    IFACE=$(ip route get 1 | awk '{print $5; exit}')

    iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4

    # No iptables.service on AL2023 — restore rules ourselves at boot
    cat > /etc/systemd/system/iptables-restore.service <<'UNIT'
    [Unit]
    Description=Restore iptables rules
    Before=network-pre.target
    Wants=network-pre.target

    [Service]
    Type=oneshot
    ExecStart=/usr/sbin/iptables-restore /etc/iptables/rules.v4
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable iptables-restore.service
  EOF

  tags = { Name = local.bastion_ec2_name }

}

resource "aws_instance" "webserver" {

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  key_name               = "shaurya-bastion-key"

  user_data = <<-EOF
#!/bin/bash

dnf update -y
dnf install nginx -y
systemctl enable nginx
systemctl start nginx
echo "<h1>Hello Terraform</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = { Name = local.webserver_ec2_name }

}
