# Networking Foundation for Demos
The Terraform deployment in the Networking folder will deploy an Azure Virtual WAN environment that can be used as the foundation for demos (not production environments). There are conditional variables to add any of the following:
* a secondary region w/ vWAN
* Azure Firewall in either or both regions
* Azure Private DNS in either or both regions (Private DNS Zones and Private Resolver)
* Azure VPN Gateway in either or both regions

## Pre-reqs
Use Azure Powershell or CLI to pull your subscription ID and set it as an environment variable for Terraform deployments. Alternative is hardcoding the sub ID in your config file. I've provided a CLI example in the setSubscription.ps1 script.

Install terraform locally and clone the repo to your machine. Terraform init will 

## Setup walkthrough
WIP