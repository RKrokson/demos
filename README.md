# Networking Foundation for Demos
The Terraform deployment in the Networking folder will deploy an Azure Virtual WAN environment that can be used as the foundation for demos (not production environments). There are conditional variables to add any of the following:
* a secondary region w/ vWAN
* Azure Firewall in either or both regions
* Azure Private DNS in either or both regions (Private DNS Zones and Private Resolver)
* Azure VPN Gateway in either or both regions

## Example
![Diagram](./diagrams/1reg-shub-dns-vpn.png)
![tfvars](./diagrams/1reg-shub-dns-vpn-vars.png)

## Pre-reqs
Use Azure Powershell or CLI to pull your subscription ID and set it as an environment variable in Windows for Terraform deployments. Alternative is hardcoding the sub ID in your config file. I've provided a CLI example in the setSubscription.ps1 script.

Install terraform locally and clone the repo to your machine. Run terraform init to install the required providers. 