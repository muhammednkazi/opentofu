# Multi-Provider Lab: Providers, Resources & Data Sources

## Overview
This lab demonstrates:
- Multiple provider configuration (AWS + Random)
- Data sources for dynamic infrastructure queries
- Implicit and explicit resource dependencies
- Provider version constraints
- Output values from multiple sources

## What This Lab Creates
1. Random ID for unique naming
2. Random password for demonstration
3. Security group with HTTP/SSH access
4. EC2 instance with Amazon Linux 2023
5. Elastic IP attached to instance
6. Web server accessible via HTTP

## Deployment Instructions
See main documentation below.

#Key Pair Name: jp_rsa_key generate locally and uploaded to aws create key pair options and then on command line with tofu command to associate with instance.

tofu apply -var="key_pair_name=jp_rsa_key"