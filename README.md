# Multi-Region Internet Observability Platform
A multi-region AWS platform that monitors the availability and network performance of real internet services from different AWS regions.
## Project Goal
The platform performs synthetic monitoring of real public internet services from multiple AWS regions.
It collects availability and performance measurements, stores the results centrally, visualizes monitoring metrics, and generates automated alerts when service degradation or regional connectivity problems are detected.
## Planned Architecture
- AWS Lambda — monitoring probes
- Amazon EventBridge — scheduled monitoring
- Amazon CloudWatch — metrics, logs and alarms
- Amazon DynamoDB — measurement storage
- Amazon SNS — alert notifications
- Terraform — Infrastructure as Code
- Python — monitoring logic
- GitHub Actions — CI/CD
## Monitoring Metrics
The platform will monitor:
- HTTP availability
- HTTP status codes
- Response latency
- DNS resolution latency
- TCP connection latency
- TLS handshake latency
- Request timeouts
- Regional differences in performance
## AWS Regions
Initial monitoring regions:
- eu-west-1
- eu-central-1
- us-east-1
## Project Status
🚧 Initial project setup