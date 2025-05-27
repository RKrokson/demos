# Networking Foundation for Demos
The Terraform deployment in the Networking folder will deploy an Azure Virtual WAN environment that can be used as the foundation for demos (not production environments). There are conditional variables to add any of the following:
* a secondary region w/ vWAN
* Azure Firewall in either or both regions
* Azure Private DNS in either or both regions (Private DNS Zones and Private Resolver)
* Azure VPN Gateway in either or both regions

## Example
![Diagram](./Diagrams/1reg-shub-dns-vpn.png)
![tfvars](./Diagrams/1reg-shub-dns-vpn-vars.png)

## Pre-reqs
Here are the pre-reqs for running this in your environment:
* Update/Set Azure Subscription ID variable
* Git
* Terraform

Set your Azure Subscription ID as an environment variable in Windows for Terraform deployments. The alternative is hardcoding the sub ID in your Terraform config file. I've provided a CLI example in the setSubscription.ps1 script to pull your sub ID and set as an environment variable. 

Install Git and Terraform locally. Git clone the repo to your machine. CD into the cloned folder and run terraform init to install the required providers. 