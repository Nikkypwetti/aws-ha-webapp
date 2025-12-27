# AWS Multi-Tier, Multi-AZ High Availability Web Application

## 🚀 Project Overview

This project demonstrates the deployment of a highly available, fault-tolerant, and scalable 3-Tier web application architecture on Amazon Web Services (AWS). It leverages core services like VPC, EC2 Auto Scaling, Application Load Balancing (ALB), and RDS Multi-AZ to ensure the application remains operational even if an entire Availability Zone (AZ) fails.

This setup is designed to serve as a foundational, production-ready environment for a modern web application.

### 🌐 Technologies Used

| Category | AWS Service | Purpose |
| :--- | :--- | :--- |
| **Networking** | VPC, Subnets, IGW, Route Tables | Isolated, custom network setup. |
| **High Availability** | **2+ Availability Zones** | Disaster recovery and fault tolerance. |
| **Compute** | EC2, Launch Templates, AMI | Virtual servers hosting the application. |
| **Load Balancing** | Application Load Balancer (ALB) | Distributes traffic and handles HTTPS termination. |
| **Scalability/Resilience**| **Auto Scaling Group (ASG)** | Automatically scales EC2 capacity and replaces unhealthy instances. |
| **Database** | RDS (Relational Database Service) | Managed, highly available, Multi-AZ database. |
| **Internet Access** | NAT Gateway, Elastic IP (EIP) | Allows private instances to initiate outbound internet connections. |
| **Security** | Security Groups (SGs) | Controls inbound/outbound traffic flow between tiers. |

## 🏗️ Architecture Diagram

The architecture is built across two Availability Zones (AZs) to prevent a single point of failure (SPOF).

<br>

![Architecture Diagram](./images/architecture-diagram.png)

### Architecture Flow:

1.  **User Request:** The user accesses the web application via the public DNS of the **Application Load Balancer (ALB)**.
2.  **Presentation Tier (Public Subnets):** The ALB is deployed in the public subnets across AZ-A and AZ-B. It directs traffic to healthy EC2 instances in the private layer.
3.  **Application Tier (Private App Subnets):** The **Auto Scaling Group (ASG)** maintains a minimum number of EC2 instances (Web Servers) balanced across AZ-A and AZ-B. These instances communicate with the database.
4.  **Internet Access:** Instances in the private subnets use the **NAT Gateway** in their respective AZs to access the internet (e.g., for OS updates) without being publicly accessible.
5.  **Data Tier (Private DB Subnets):** The **RDS Multi-AZ** deployment ensures a primary database instance is active in one AZ with a synchronous standby replica in the other AZ. This provides automatic failover at the database level.
6.  **Security:** Security Groups enforce strict rules, ensuring the **DB Tier** only accepts connections from the **App Tier**, and the **App Tier** only accepts traffic from the **ALB**.

## 📝 Setup Instructions (Manual Console Walkthrough)

*A full, step-by-step guide is available in the [SETUP-GUIDE.md](link-to-separate-setup-file) file.*

### Key Configuration Highlights:

| Component | Configuration | HA/Resilience Feature |
| :--- | :--- | :--- |
| **VPC** | CIDR: `10.0.0.0/16` | Custom network isolation. |
| **Subnets** | 2 Public, 2 Private App, 2 Private DB | Spread across **two AZs** for fault tolerance. |
| **Load Balancer** | Application Load Balancer (ALB) | Routes traffic, health checks, and is inherently Multi-AZ. |
| **Auto Scaling** | Min: 2, Desired: 2, Max: 4 | Automatically maintains minimum capacity and self-heals instances. |
| **RDS** | Multi-AZ Deployment | Synchronous replication and automatic failover for the database. |

### Demonstration of High Availability

To confirm the High Availability capability:

1.  Access the EC2 dashboard and confirm two instances are running, one in each AZ (e.g., `us-east-1a` and `us-east-1b`).
2.  **Manually terminate** one of the running EC2 instances.
3.  Observe the Auto Scaling Group log: within minutes, the ASG will detect the instance termination and automatically provision a brand new replacement instance in the same AZ, maintaining the desired capacity of 2.
4.  The application remains accessible via the ALB throughout the entire process.

---

## 🧹 Cleanup Instructions (Critical)

It is **CRITICAL** to clean up all resources created during this project to avoid unexpected AWS billing, as services like RDS Multi-AZ, NAT Gateways, and ALBs are *not* part of the Free Tier for continuous usage.

Follow these steps in the AWS Console, ensuring to delete resources in the correct order due to dependencies:

### 1. Database Tier Cleanup

| Service | Action | Notes |
| :--- | :--- | :--- |
| **RDS** | Modify the DB Instance | Turn off **Deletion Protection**. |
| **RDS** | Delete the DB Instance | Crucially, ensure you uncheck **"Create final snapshot"** and confirm the deletion by typing `delete me` (or similar). Wait for the status to change to *Deleted*. |
| **RDS** | Delete the **DB Subnet Group** | Delete the custom DB Subnet Group created for the RDS instance. |

### 2. Compute & Load Balancing Cleanup

| Service | Action | Notes |
| :--- | :--- | :--- |
| **Auto Scaling Group** | Delete the ASG | This will automatically terminate the EC2 instances. Set the **Desired Capacity** to `0` first if the deletion fails. |
| **Load Balancer** | Delete the ALB | Go to EC2 > Load Balancers and delete the Application Load Balancer. |
| **Target Groups** | Delete the Target Group | Go to EC2 > Target Groups and delete the target group associated with the ALB. |
| **Launch Template** | Delete the Launch Template | Go to EC2 > Launch Templates and delete the template. |
| **AMI** | Deregister the AMI | Go to EC2 > AMIs, select your custom AMI, and choose **Deregister**. |

### 3. Networking Cleanup (VPC)

| Service | Action | Notes |
| :--- | :--- | :--- |
| **NAT Gateways**| Delete the NAT Gateways | You must delete the NAT Gateways first before deleting the EIPs. |
| **Elastic IPs (EIPs)**| Release the EIPs | Go to EC2 > Elastic IPs and select the addresses created for the NAT Gateways, then select **Release Elastic IP addresses**. |
| **Route Tables** | Delete Custom Route Tables | Delete the two custom Private Route Tables. |
| **Security Groups** | Delete Custom SGs | Delete the custom SGs (ALB SG, App SG, DB SG). |
| **Internet Gateway**| Detach and Delete IGW | Detach the Internet Gateway from the VPC, then delete it. |
| **VPC** | Delete the VPC | Finally, navigate to **Your VPCs** and select **Delete VPC**. This step will also clean up the Subnets. |
