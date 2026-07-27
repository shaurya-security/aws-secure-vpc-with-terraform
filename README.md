# terraform-aws-vpc-ssm

A single-region AWS network — VPC, public/private subnets, managed NAT Gateway, and a private web server — provisioned entirely with Terraform, with remote state and CI baked in.

This is v2 of a rebuild that started as a hand-run AWS CLI lab ([aws-infra-cli](https://github.com/shaurya-security/aws-infra-cli)), then became a first Terraform pass using a bastion-as-NAT instance ([terraform-aws-bastion-nat](https://github.com/shaurya-security/terraform-aws-bastion-nat/tree/v1.0.0)). This version drops the SSH bastion pattern entirely in favor of a managed NAT Gateway for egress and AWS SSM Session Manager for access — no open SSH ports, no key pairs to manage.

---

## What changed from v1

| | v1 (`terraform-aws-bastion-nat`) | v2 (`terraform-aws-vpc-ssm`) |
|---|---|---|
| Outbound NAT | Bastion EC2 doing `iptables MASQUERADE` | Managed `aws_nat_gateway` |
| Instance access | SSH jump through the bastion (`bastion_ssh.sh` / `web_ssh.sh`) | AWS SSM Session Manager (IAM role + `AmazonSSMManagedInstanceCore`) |
| State | Local `terraform.tfstate` | S3 backend (`shaurya-terraform-state-2026`) with native `use_lockfile` locking — no DynamoDB table needed |
| Security | Bastion SG open to SSH from anywhere | No inbound rules on either SG — SSM works entirely over outbound HTTPS |
| Hardening | — | IMDSv2 enforced (`http_tokens = required`), encrypted root volumes |
| CI | — | GitHub Actions: `terraform fmt`, `terraform validate`, Checkov scan |
| Policy-as-code | — | `.checkov.yaml` with explicit, commented skip list |
| Bootstrap | — | Separate `terraform-bootstrap/` config to stand up the S3 state bucket |

---

## Architecture

- VPC `10.0.0.0/16` in `ap-south-1`
- Public subnet `10.0.1.0/24` (`ap-south-1a`) → NAT Gateway + Elastic IP
- Private subnet `10.0.2.0/24` (`ap-south-1b`) → web server EC2, no public IP, NGINX
- Internet Gateway on the public route table; private route table's default route points at the NAT Gateway
- Both EC2 instances carry an IAM instance profile scoped to `AmazonSSMManagedInstanceCore` — reachable via `aws ssm start-session`, no bastion, no SSH key
- Security groups allow all egress and currently define no ingress rules at all — SSM doesn't need any

---

## Project structure

```
.
├── terraform-lab/              # the network + compute stack
│   ├── main.tf                 # provider + required_providers
│   ├── backend.tf              # S3 remote state, native locking
│   ├── variables.tf            # CIDR ranges, owner prefix
│   ├── locals.tf                # naming convention (owner → resource names)
│   ├── data.tf                  # latest Amazon Linux 2023 AMI lookup
│   ├── network.tf               # VPC, subnets, IGW, route tables, SGs, NAT Gateway
│   ├── compute.tf                # bastion + web server instances, IMDSv2, encrypted volumes
│   ├── iam.tf                    # SSM instance role/profile
│   ├── output.tf                 # IPs and instance IDs
│   ├── userdata/                 # common.sh (tooling + SSM agent), bastion.sh, webserver.sh
│   ├── ssm_bastion.sh             # zero-copy-paste SSM session into the bastion
│   ├── ssm_web.sh                 # zero-copy-paste SSM session into the web server
│   ├── .checkov.yaml              # commented Checkov skip list
│   └── .github/workflows/terraform.yml   # fmt + validate + Checkov on push/PR
└── terraform-bootstrap/         # one-time setup: S3 state bucket (versioned, encrypted, public access blocked)
```

---

## Deployment

**Prerequisites**
- Terraform >= 1.5, AWS provider `~> 6.0`
- AWS CLI v2 configured with credentials for `ap-south-1`
- Session Manager plugin for the AWS CLI (for `aws ssm start-session`)

**1. Bootstrap remote state (one-time, per AWS account)**

```bash
cd terraform-bootstrap
terraform init
terraform apply
```

**2. Deploy the network + compute stack**

```bash
cd terraform-lab
terraform init
terraform plan
terraform apply
```

**3. Connect — no SSH, no bastion**

```bash
chmod +x ssm_bastion.sh ssm_web.sh
./ssm_bastion.sh   # or ./ssm_web.sh
```

Both scripts read the instance ID straight from `terraform output`, same zero-copy-paste pattern v1's `bastion_ssh.sh` used, just over SSM instead of an SSH jump.

**4. Tear down**

```bash
terraform destroy
```

---

## Quality gates

The project is validated through GitHub Actions:
- `terraform fmt`
- `terraform validate`
- Checkov

Current Checkov status:
- ✅ 38 checks passed
- ⚠️ 2 checks intentionally left unresolved (`CKV_AWS_126`) because EC2 Detailed Monitoring is a cost optimization rather than a security requirement.

---

## Known gaps / next up

- [ ] Wire `bastion.sh` and `webserver.sh` into their respective instances' `user_data` (both currently only run `common.sh`)
- [ ] Add ingress rules scoped to what each tier actually needs (currently egress-only SGs)
- [ ] VPC Flow Logs feeding into the existing Wazuh detection pipeline (currently skipped in `.checkov.yaml` as `CKV2_AWS_11`)
- [ ] Toggle between NAT Gateway and the v1 bastion-as-NAT pattern via a variable, for cost comparison
- [ ] Split `network.tf` / `compute.tf` into reusable modules

---

## License

MIT
