┌─────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                         │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ Public Subnet (10.0.1.0/24)           │ │
│  │                                       │ │
│  │  ┌─────────────────────────────────┐ │ │
│  │  │ EC2 Instance (t3.micro)         │ │ │
│  │  │ - Amazon Linux 2023             │ │ │
│  │  │ - nginx web server              │ │ │
│  │  │ - Public IP                     │ │ │
│  │  │ - SSH access (port 22)          │ │ │
│  │  │ - HTTP access (port 80)         │ │ │
│  │  └─────────────────────────────────┘ │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘

Provisioner Flow:
1. file: Copy nginx config → /tmp/nginx.conf
2. file: Copy welcome page → /tmp/index.html  
3. remote-exec: Install nginx, move files, start service
4. local-exec: Record deployment info locally

Prerequisites
Before starting this lab, ensure you have:

 AWS CLI configured with valid credentials
 OpenTofu installed (v1.6.0+)
 SSH key pair available (or script will create one)
 Permissions to create VPC, EC2, and security group resources
 Network connectivity to AWS

 mkdir provisioners-lab
cd provisioners-lab

provisioners-lab/
├── versions.tf           # Provider and OpenTofu version constraints
├── variables.tf          # Input variables
├── data.tf              # Data sources (AMI lookup)
├── main.tf              # Main infrastructure (VPC, EC2, security groups)
├── outputs.tf           # Output values
├── terraform.tfvars     # Variable values (optional)
├── scripts/
│   └── bootstrap.sh     # Initialization script
└── files/
    ├── nginx.conf       # Nginx configuration
    └── index.html       # Custom welcome page

#################
Deploy Infrastructure

# Initialize Terraform

tofu init   
tofu plan
tofu apply  
tofu output

#Test the web server:

#Option 1: Using curl

WEB_URL=$(tofu output -raw web_url)
curl $WEB_URL

Option 2: Using browser

# Get the URL
tofu output web_url

# Open in browser (macOS)
open $(tofu output -raw web_url)

# Open in browser (Linux)
xdg-open $(tofu output -raw web_url)

#Check local logs:
cat deployment-log.txt
cat instance-info.txt


#SSH to the instance:
# Copy the SSH command from output
tofu output -raw ssh_command

# Or execute directly
eval $(tofu output -raw ssh_command)

#Verify nginx is running
# On the instance
sudo systemctl status nginx
curl http://localhost
ls -la /etc/nginx/nginx.conf
ls -la /usr/share/nginx/html/index.html