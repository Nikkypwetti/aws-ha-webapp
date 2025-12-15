# ☁️ High-Availability Web Application on AWS

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Status](https://img.shields.io/badge/Status-Completed-success)

## 📖 Project Overview
This project deploys a highly available, fault-tolerant web application on AWS. It is designed to withstand the failure of an entire Availability Zone (AZ) without service interruption. 

The infrastructure implements a classic **Multi-Tier Architecture**, separating the web serving layer from the logic/database layer to enhance security and scalability.

## 🏗️ Architecture
![Architecture Diagram](./images/architecture-diagram.png)

**Key Components:**
* **VPC:** Custom Virtual Private Cloud spanning two Availability Zones (e.g., `us-east-1a`, `us-east-1b`).
* **Public Subnets:** Host the NAT Gateways and Application Load Balancer (ALB).
* **Private Subnets:** Host the EC2 Web Servers (Application Tier) for enhanced security.
* **Auto Scaling Group (ASG):** Automatically scales EC2 instances based on CPU utilization traffic.
* **Application Load Balancer (ALB):** Distributes incoming HTTP traffic across healthy instances in multiple AZs.

## 🛠️ Tech Stack
* **Cloud Provider:** Amazon Web Services (AWS)
* **Compute:** Amazon EC2 (Amazon Linux 2023 AMI)
* **Networking:** VPC, Security Groups, ELB, Route53
* **Automation/User Data:** Bash Scripting (Apache Web Server installation)
* **Storage:** EBS (Elastic Block Store)

## 🚀 Deployment Steps

### Prerequisites
* AWS Free Tier Account
* AWS CLI installed and configured (optional, if deploying via CLI)

### Step 1: Network Configuration
1. Created a VPC with CIDR `10.0.0.0/16`.
2. Configured 2 Public Subnets and 2 Private Subnets across separate Availability Zones for redundancy.
3. Attached an Internet Gateway (IGW) for public access.
4. Configured NAT Gateways in Public Subnets to allow Private Subnet instances to update packages securely.

### Step 2: Security Groups
* **ALB SG:** Allows Inbound HTTP (80) from `0.0.0.0/0`.
* **Web Server SG:** Allows Inbound HTTP (80) **only** from the ALB Security Group ID (ensuring no direct access from the internet).

### Step 3: Launch Templates & Auto Scaling
1. Created an EC2 Launch Template with User Data to install Apache (`httpd`) and create a custom `index.html`.
2. Configured an Auto Scaling Group with a target capacity of 2 and maximum of 4.
3. Defined Scaling Policies: Scale out if Average CPU > 70%.

### Step 4: Testing High Availability
1. Accessed the application via the ALB DNS name.
2. **Chaos Engineering:** Manually terminated an instance in `us-east-1a`.
3. **Result:** The Load Balancer immediately directed traffic to the instance in `us-east-1b`. The Auto Scaling Group detected the unhealthy instance and provisioned a replacement within 2 minutes.

## 🧪 User Data Script
This Bash script was used to bootstrap the instances:

```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
