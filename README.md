# AWS Secure VPC with Terraform

#### A single-region AWS network—VPC, public/private subnets, a managed NAT Gateway, and a private web server—fully provisioned with Terraform, with remote state and integrated GitHub Actions CI.

- This project is the second iteration of a lab that began as a hand-built AWS CLI environment ([aws-infra-cli](https://github.com/shaurya-security/aws-infra-cli)).
  
- It then evolved into a Terraform deployment using a bastion-as-NAT instance ([terraform-aws-bastion-nat](https://github.com/shaurya-security/terraform-aws-bastion-nat/tree/v1.0.0)).
  
- This version replaces the bastion-as-NAT pattern with a managed NAT Gateway and replaces SSH administration with AWS Systems Manager Session Manager—no SSH keys or inbound SSH access required.
  
> **Note:** Although the environment still includes a bastion EC2 instance, it is no longer used for NAT or SSH access. It serves only as an SSM-managed administration host and demonstration instance.

---

## What changed from v1

| | v1 (`terraform-aws-bastion-nat`) | v2 (`aws-secure-vpc-with-terraform`) |
|---|---|---|
| Outbound NAT | Bastion EC2 using `iptables MASQUERADE` | Managed `aws_nat_gateway` |
| Instance access | SSH jump host (`bastion_ssh.sh` / `web_ssh.sh`) | AWS Systems Manager Session Manager (`ssm_bastion.sh` / `ssm_web.sh`) |
| State | Local `terraform.tfstate` | S3 backend with native `use_lockfile` locking |
| Security | SSH exposed on the bastion | No inbound security group rules; SSM works over outbound HTTPS |
| Hardening | — | IMDSv2 enforced (`http_tokens = required`), encrypted root volumes |
| CI | — | GitHub Actions (`terraform fmt`, `terraform validate`, Checkov) |
| Policy-as-Code | — | `.checkov.yaml` with documented skip list |
| Bootstrap | — | Separate `terraform-bootstrap/` project for the remote state bucket |

---

## Architecture

- VPC `10.0.0.0/16` in `ap-south-1`
- Public subnet `10.0.1.0/24` (`ap-south-1a`) hosting:
  - NAT Gateway + Elastic IP
  - Bastion EC2 (SSM-managed only)
- Private subnet `10.0.2.0/24` (`ap-south-1b`) hosting:
  - Web server EC2 (NGINX, no public IP)
- Internet Gateway attached to the VPC
- Public and private route tables with the private subnet routing Internet-bound traffic through the NAT Gateway
- Both EC2 instances use IAM instance profiles with `AmazonSSMManagedInstanceCore`, enabling administration through AWS Systems Manager instead of SSH
- Security groups currently allow all outbound traffic and intentionally define no inbound rules

---

## Project structure

```text
.
├── terraform-lab/
│   ├── main.tf                  # Provider configuration
│   ├── backend.tf               # S3 remote state + native locking
│   ├── variables.tf             # CIDR ranges and configurable values
│   ├── locals.tf                # Resource naming
│   ├── data.tf                  # Latest Amazon Linux 2023 AMI lookup
│   ├── network.tf               # VPC, subnets, IGW, route tables, NAT Gateway, SGs
│   ├── compute.tf               # EC2 instances, IMDSv2, encrypted root volumes
│   ├── iam.tf                   # SSM IAM role and instance profile
│   ├── output.tf                # Terraform outputs
│   ├── userdata/
│   │   ├── common.sh
│   │   ├── bastion.sh
│   │   └── webserver.sh
│   ├── ssm_bastion.sh           # Start an SSM session with the bastion
│   ├── ssm_web.sh               # Start an SSM session with the web server
│   ├── .checkov.yaml            # Checkov configuration
│   └── .github/workflows/
│       └── terraform.yml        # fmt + validate + Checkov
│
└── terraform-bootstrap/
    ├── provider.tf
    ├── backend.tf
    └── s3.tf                    # One-time bootstrap for the remote state bucket
```

---

## Deployment

### Prerequisites

- Terraform >= 1.5
- AWS Provider `~> 6.0`
- AWS CLI v2 configured for `ap-south-1`
- AWS Session Manager Plugin

### 1. Bootstrap the remote state (one-time)

```bash
cd terraform-bootstrap
terraform init
terraform apply
```

### 2. Deploy the infrastructure

```bash
cd terraform-lab
terraform init
terraform plan
terraform apply
```

### 3. Connect using AWS Systems Manager

```bash
chmod +x ssm_bastion.sh ssm_web.sh

./ssm_bastion.sh
# or
./ssm_web.sh
```

Both helper scripts automatically read the instance ID from `terraform output` and start an interactive SSM session without requiring SSH keys.

### 4. Destroy the infrastructure

```bash
terraform destroy
```

---

## Quality gates

Every push and pull request runs:

- `terraform fmt`
- `terraform validate`
- Checkov

### Latest Checkov scan

- ✅ 38 checks passed
- ⚠️ 2 checks intentionally left unresolved (`CKV_AWS_126`) because EC2 Detailed Monitoring is a cost optimization rather than a security requirement

---

## Known gaps / future improvements

- [ ] Wire `bastion.sh` and `webserver.sh` into their respective `user_data` blocks (currently only `common.sh` is used)
- [ ] Add a variable to switch between the managed NAT Gateway and the v1 bastion-as-NAT architecture for cost comparison
- [ ] Refactor `network.tf` and `compute.tf` into reusable Terraform modules
- [ ] Add least-privilege inbound security group rules once application workloads are deployed (security groups are intentionally egress-only today)
- [ ] Enable VPC Flow Logs and integrate them with the existing Wazuh detection pipeline (currently skipped in `.checkov.yaml` as `CKV2_AWS_11`)

---

## License

MIT
