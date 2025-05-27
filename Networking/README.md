# Networking Foundation
The Terraform deployment in this folder will deploy an Azure Virtual WAN environment that can be used as the foundation for demos (not production environments). There are conditional variables to add any of the following:
* a secondary region w/ vWAN
* Azure Firewall in either or both regions
* Azure Private DNS in either or both regions (Private DNS Zones and Private Resolver)
* Azure VPN Gateway in either or both regions

## Notes
Azure Firewall is deployed with Routing Intent enabled for both Private and Internet traffic. However, the firewall policy allows any/any. Update firewall rules, as appropriate, for your tests.

Azure VPN Gateway is deployed without an environment on the other end. You can connect it to an existing on-prem or deploy another Azure environment to simulate on-prem. This is out of scope for now.

The default primary region (region 0) is Central US. The default secondary region (region 1) is East US 2. You can change these regions by updating them in the variables file. Update both the full region name and abbreviation.

![Regions](./diagrams/region-vars.png)

## Using the conditionals
The default for all conditionals is false (set in the variables file). This means they will not be deployed. In order to use the conditionals you need to update their value to true. The easiest way to do this is to use a tfvars file to update the variables. I've included two examples:
* terraform.tfvars.txt - Simple example that only includes the conditionals. 
* example.terraform.tfvars.txt - An example with conditionals and overriding the default IP scheme to avoid 10.0.0.0.

You can rename either file and save as "terraform.tfvars". Update the values to true and then run your terraform plan/apply.

## Examples
Below are examples of the various scenarios you can build using the conditionals with tfvars. 

### 1 Region, vHub, w/ DNS & VPN

![Diagram](./diagrams/1reg-hub-dns-vpn.png)
![tfvars](./diagrams/1reg-hub-dns-vpn-vars.png)

### 1 Region, vHub, w/o DNS or VPN (default deployment without tfvars in place)

![Diagram](./diagrams/1reg-hub-ndns-nvpn.png)
![tfvars](./diagrams/1reg-hub-ndns-nvpn-vars.png)

### 1 Region, Secure Hub, w/ DNS & VPN

![Diagram](./diagrams/1reg-shub-dns-vpn.png)
![tfvars](./diagrams/1reg-shub-dns-vpn-vars.png)

### 1 Region, Secure Hub, w/o DNS or VPN

![Diagram](./diagrams/1reg-shub-ndns-nvpn.png)
![tfvars](./diagrams/1reg-shub-ndns-nvpn-vars.png)

### 2 Regions, vHub, w/ DNS & VPN

![Diagram](./diagrams/2reg-hub-dns-vpn.png)
![tfvars](./diagrams/2reg-hub-dns-vpn-vars.png)

### 2 Regions, vHub, w/o DNS or VPN

![Diagram](./diagrams/2reg-shub-dns-vpn.png)
![tfvars](./diagrams/2reg-shub-dns-vpn-vars.png)
