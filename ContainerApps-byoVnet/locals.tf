locals {
  platform_region0 = data.terraform_remote_state.networking.outputs.alz_regions.region0

  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }
}
