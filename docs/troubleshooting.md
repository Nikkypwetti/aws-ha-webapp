🛠️ Project Troubleshooting Case Study

This document details the critical technical challenges encountered during the deployment of the Highly Available Web App and the systematic approach used to resolve them.

1. Security Group Logic & Traffic Isolation

The Challenge: Establishing a secure communication path between the Load Balancer and the EC2 instances without exposing the instances to the public internet.

The Analysis: To follow the Principle of Least Privilege, the web servers were placed in private subnets. However, they still needed to receive traffic from the Application Load Balancer (ALB).

The Solution: I implemented Security Group Referencing (Chaining).

    ALB Security Group: Configured to allow inbound traffic on Port 80 from 0.0.0.0/0.

    EC2 Security Group: Instead of allowing an IP range, I set the Source of the inbound HTTP rule to the ID of the ALB Security Group (sg-xxxxxxxx).

    Result: This created a logical "handshake" where the EC2 instances only accept traffic if it is signed/forwarded by the ALB, effectively blocking direct external attacks.

2. OS Identification & Package Manager Conflict

The Challenge: The User Data script was failing to provision the web server, leaving instances in a perpetual "Unhealthy" state.

The Analysis: By examining the EC2 Serial Console and running the command:
Bash

cat /etc/os-release

I identified that the AMI was Amazon Linux 2023. My initial script used apt (Debian/Ubuntu), but Amazon Linux 2023 is based on Fedora and does not recognize the apt command, causing the installation to fail silently.

The Solution: I refactored the automation script to use the dnf package manager.

    Updated commands to sudo dnf install -y httpd php.

    Corrected the service name to httpd (Apache’s name in Red Hat-based systems).

    Result: The server successfully provisioned, and the Apache service was able to start and listen for requests.

3. Target Group Health Check Calibration

The Challenge: Even after Apache was running, the Load Balancer reported the targets as "Unhealthy," resulting in a 503 Service Temporarily Unavailable error at the DNS endpoint.

The Analysis: The Load Balancer's default health check looks for a file at the root path (/), usually expecting an index.html. Because my application was built on PHP, I had deployed an index.php. The ALB was receiving a 404 Not Found error during its health check probes, which it interpreted as a server failure.

The Solution: I manually reconfigured the Target Group Health Check settings:

    Health Check Path: Changed from / to /index.php.

    Success Codes: Verified it was looking for a 200 OK response.

    Result: The ALB successfully validated the PHP application, changed the target status to Healthy, and began routing live traffic.

💡 Key Takeaway

This project reinforced the importance of Environmental Awareness. Cloud automation is only as good as its compatibility with the underlying Operating System and the accuracy of the Load Balancer's health probes

🎓 Lessons Learned

    AMI Specificity Matters: I learned that "Linux" is not a monolith. Automation scripts must be precisely tailored to the specific distribution (Amazon Linux vs. Ubuntu) and its corresponding package manager (dnf vs. apt).

    Health Checks are the Heartbeat of HA: A "Running" instance is not the same as a "Healthy" instance. I learned how to use Target Group metrics to distinguish between a service that is powered on and a service that is actually ready to fulfill requests.

    Security Group Chaining: I gained a deep understanding of how to use Security Group IDs as sources for rules. This creates a much more secure "layered" defense than relying on IP addresses, which can change in dynamic environments.

    The Power of Logs: When things fail in the cloud, the EC2 System Log and Cloud-init logs are the first place to look. They provide the "why" behind the failure, saving hours of guesswork.