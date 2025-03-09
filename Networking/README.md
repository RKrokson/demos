# Networking Foundation
The Terraform deployment in this folder will deploy an Azure Virtual WAN environment that can be used as the foundation for demos (not production environments). There are conditional variables to add any of the following:
* a secondary region w/ vWAN
* Azure Firewall in either or both regions
* Azure Private DNS in either or both regions (Private DNS Zones and Private Resolver)
* Azure VPN Gateway in either or both regions

## Using the conditionals
The default for all conditionals is false. This means they will not be deployed. In order to use the conditionals you need to update their value to true. The easiest way to do this is to use a tfvars file to update the variables. I've included two examples:
* terraform.tfvars.txt - Simple example that only includes the conditionals. 
* example.terraform.tfvars.txt - An example with conditionals and overriding the default IP scheme to avoid 10.0.0.0.

You can rename either file and save as terraform.tfvars. Update the values to true and then run your terraform plan/apply.

## Example walkthrough
WIP