#!/bin/bash
# ------------------------------------------------------------------
# Project: High Availability Web App
# Purpose: Bootstrap EC2 instances with Apache & Metadata Info
# Author: Abdulganiy Basirah Olanike
# ------------------------------------------------------------------

# 1. Update the system packages
yum update -y

# 2. Install Apache HTTP Server
yum install -y httpd

# 3. Start the service and enable it to start on boot
systemctl start httpd
systemctl enable httpd

# 4. Get the Instance ID and Availability Zone from IMDSv2 (Instance Metadata Service)
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/placement/availability-zone)

# 5. Create a custom index.html file
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>High Availability Demo</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f4f4f4; }
        .card { background: white; padding: 20px; margin: auto; width: 50%; box-shadow: 0 4px 8px 0 rgba(0,0,0,0.2); border-radius: 10px; }
        h1 { color: #232F3E; }
        p { font-size: 18px; color: #555; }
        .highlight { color: #e67e22; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>☁️ AWS High Availability Project</h1>
        <p>If you are seeing this, the traffic was successfully routed!</p>
        <hr>
        <p>This request was handled by:</p>
        <p>Instance ID: <span class="highlight">$INSTANCE_ID</span></p>
        <p>Availability Zone: <span class="highlight">$AZ</span></p>
    </div>
</body>
</html>
EOF

# 6. Restart Apache to ensure changes take effect
systemctl restart httpd
