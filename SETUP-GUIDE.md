# AWS Multi-Tier, Multi-AZ High Availability Web Application: Setup Guide

This guide provides the detailed, step-by-step instructions to manually provision the infrastructure for the highly available web application outlined in the `README.md`.

## Prerequisites

* An active AWS Account with administrative privileges.
* Basic familiarity with the AWS Management Console.
* Region: **us-east-1 (N. Virginia)** (Ensure all resources are created in the same region).

---

## Phase 1: Networking and Routing (VPC)

We will create a custom VPC with isolated Public, Private App, and Private DB subnets across two Availability Zones (AZs) for high availability.

### 1.1 Create the Custom VPC

1.  Navigate to the **VPC** service dashboard.
2.  Click **Create VPC**.
    * **Resources to create:** `VPC only`
    * **Name tag:** `Project1-HA-VPC`
    * **IPv4 CIDR block:** `10.0.0.0/16`
    * Click **Create VPC**.

### 1.2 Create Subnets

We need six subnets, three in each of two AZs (e.g., `us-east-1a` and `us-east-1b`).

1.  Navigate to **Subnets** and click **Create subnet**.
2.  Select `Project1-HA-VPC`.
3.  Create the following six subnets:

| Name Tag | AZ | IPv4 CIDR | Role |
| :--- | :--- | :--- | :--- |
| `Public-A` | `us-east-1a` | `10.0.1.0/24` | ALB and NAT Gateway |
| `Public-B` | `us-east-1b` | `10.0.2.0/24` | ALB and NAT Gateway |
| `App-Private-A` | `us-east-1a` | `10.0.11.0/24` | EC2 Web Servers (ASG) |
| `App-Private-B` | `us-east-1b` | `10.0.12.0/24` | EC2 Web Servers (ASG) |
| `DB-Private-A` | `us-east-1a` | `10.0.21.0/24` | RDS Primary |
| `DB-Private-B` | `us-east-1b` | `10.0.22.0/24` | RDS Standby |

### 1.3 Internet Gateway (IGW) and Public Routing

1.  Navigate to **Internet gateways** and click **Create internet gateway**. Name it `Project1-IGW`.
2.  Select the new IGW and click **Actions > Attach to VPC**. Select `Project1-HA-VPC`.
3.  Navigate to **Route tables** and create a new table named `Project1-Public-RT` for `Project1-HA-VPC`.
4.  Select `Project1-Public-RT`, go to the **Routes** tab, and click **Edit routes**.
    * Add a route: Destination `0.0.0.0/0`, Target **Internet Gateway** (`Project1-IGW`).
5.  Go to the **Subnet associations** tab and associate `Public-A` and `Public-B` subnets.

### 1.4 NAT Gateways and Private Routing

This step enables outbound internet access for the private EC2 instances. We need one NAT Gateway per AZ for HA.

1.  Navigate to **NAT gateways** and click **Create NAT gateway**.
    * **Name:** `Project1-NAT-A`
    * **Subnet:** Select `Public-A`
    * **Elastic IP allocation ID:** Click **Allocate Elastic IP** (a new EIP will be created).
    * Click **Create NAT gateway**.
2.  Repeat the process for the second AZ:
    * **Name:** `Project1-NAT-B`
    * **Subnet:** Select `Public-B`
    * **Elastic IP allocation ID:** Click **Allocate Elastic IP**.
    * Click **Create NAT gateway**.

3.  **Create Private Route Tables:**
    * Create **`Project1-Private-RT-A`** and set its default route (`0.0.0.0/0`) to the **`Project1-NAT-A`** NAT Gateway.
    * Associate this RT with `App-Private-A` and `DB-Private-A`.
    * Create **`Project1-Private-RT-B`** and set its default route (`0.0.0.0/0`) to the **`Project1-NAT-B`** NAT Gateway.
    * Associate this RT with `App-Private-B` and `DB-Private-B`.

---

## Phase 2: Compute Preparation and Security (AMI & SGs)

We prepare the server image and define security rules that strictly control traffic between the tiers.

### 2.1 Create Security Groups (SGs)

1.  Navigate to **EC2** > **Security Groups** and create the following SGs in `Project1-HA-VPC`:

| Name Tag | Description | Inbound Rules |
| :--- | :--- | :--- |
| `ALB-SG` | Allows web traffic to the Load Balancer. | **Type:** HTTP (80). **Source:** `0.0.0.0/0` |
| `App-Server-SG`| Allows traffic from the ALB. | **Type:** HTTP (80). **Source:** **`ALB-SG`** (Select by SG ID) |
| `DB-SG` | Allows traffic from the App Servers. | **Type:** MySQL/Aurora (3306). **Source:** **`App-Server-SG`** (Select by SG ID) |

### 2.2 Create a Custom AMI

1.  Launch a temporary EC2 Instance:
    * **AMI:** Amazon Linux 2 or Ubuntu.
    * **VPC/Subnet:** `Project1-HA-VPC` / `Public-A`.
    * **Security Group:** Use the **`App-Server-SG`** temporarily.
2.  **Connect** to the instance via SSH.
3.  Install and configure a basic web server (e.g., Apache/HTTPD):

    ```bash
    sudo yum update -y
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd
    # Create a simple index.html file
    echo "<h1>Project 1 HA Web App - Deployed from AMI</h1>" | sudo tee /var/www/html/index.html
    ```
4.  **Stop** the temporary instance.
5.  With the instance stopped, select it, click **Actions > Image and templates > Create image**.
    * **Image name:** `Project1-Web-Server-AMI`
6.  Once the AMI is complete, **Terminate** the temporary EC2 instance.

---

## Phase 3: Load Balancing and Scaling (ALB & ASG)

This phase establishes the automatic healing and load distribution features.

### 3.1 Create Target Group and ALB

1.  Navigate to **EC2** > **Target Groups**.
    * **Target type:** `Instances`.
    * **Name:** `Project1-App-TG`.
    * **VPC:** `Project1-HA-VPC`.
    * **Health check path:** `/index.html` (or `/` if you didn't create `index.html`).
    * Click **Create target group**.

2.  Navigate to **EC2** > **Load Balancers**.
    * Click **Create Load Balancer** > **Application Load Balancer (ALB)**.
    * **Name:** `Project1-ALB`.
    * **Scheme:** `Internet-facing`.
    * **VPC:** `Project1-HA-VPC`.
    * **Mapping:** Select both `Public-A` and `Public-B`.
    * **Security Groups:** Select **`ALB-SG`**.
    * **Listeners:** Set up an HTTP Listener (80) and forward traffic to **`Project1-App-TG`**.
    * Click **Create load balancer**.

### 3.2 Create Launch Template and Auto Scaling Group (ASG)

1.  Navigate to **EC2** > **Launch Templates**.
    * **Name:** `Project1-App-LT`.
    * **Source AMI:** Select **`Project1-Web-Server-AMI`** (from Phase 2.2).
    * **Instance type:** Choose a Free Tier eligible type (e.g., `t2.micro`).
    * **Key pair:** Select your key pair for troubleshooting access (optional).
    * **Network settings:** Select the **`App-Server-SG`**.
    * Click **Create launch template**.

2.  Navigate to **EC2** > **Auto Scaling Groups**.
    * **Name:** `Project1-App-ASG`.
    * **Launch template:** Select **`Project1-App-LT`**.
    * **VPC and Subnets:** Select the `Project1-HA-VPC`. **Crucially**, select both **`App-Private-A`** and **`App-Private-B`** subnets.
    * **Load Balancing:** Attach to an existing load balancer.
        * **Select target groups:** Choose **`Project1-App-TG`**.
    * **Group size:** Set **Desired Capacity** to `2`, **Minimum Capacity** to `2`, and **Maximum Capacity** to `4`.
    * Click **Skip to review** and **Create Auto Scaling group**.

*(Wait a few minutes for the ASG to launch two EC2 instances.)*

---

## Phase 4: Database Tier (RDS Multi-AZ)

This sets up a resilient, managed database layer.

### 4.1 Create RDS Subnet Group

1.  Navigate to **RDS** > **Subnet groups**.
2.  Click **Create DB subnet group**.
    * **Name:** `Project1-DB-Subnet-Group`.
    * **VPC:** `Project1-HA-VPC`.
    * **Add subnets:** Select the two AZs (`us-east-1a`, `us-east-1b`) and then select your two private DB subnets (`DB-Private-A` and `DB-Private-B`).
    * Click **Create**.

### 4.2 Launch Multi-AZ Database

1.  Navigate to **RDS** > **Databases**.
2.  Click **Create database**.
    * **Engine:** Choose MySQL or PostgreSQL.
    * **Templates:** Select **Dev/Test** (or Production for stronger HA).
    * **DB instance identifier:** `project1-db`.
    * **DB Subnet Group:** Select **`Project1-DB-Subnet-Group`**.
    * **Connectivity:**
        * **VPC:** `Project1-HA-VPC`.
        * **VPC security group (existing):** Select **`DB-SG`** (remove the default group).
        * **Availability & durability:** Select **Create a standby instance** (**Multi-AZ deployment**).
    * Click **Create database**.

---

## Phase 5: Verification

1.  Go to the **EC2 > Load Balancers** dashboard.
2.  Copy the **DNS name** of your `Project1-ALB`.
3.  Paste the DNS name into your web browser. You should see the test page: "Project 1 HA Web App - Deployed from AMI".

**Congratulations!** You have successfully deployed a fully redundant, Multi-AZ web application.

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
