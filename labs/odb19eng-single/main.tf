terraform {
  required_version = ">= 1.3.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

# Provider configuration:
# - For local runs: configured via environment variables or local provider block.
# - For OCI Resource Manager (ORM): provider is auto-configured by ORM.
provider "oci" {}

# -----------------------------------------------------------------------------
# Data sources
# -----------------------------------------------------------------------------

# Use the first availability domain in the compartment.
# This works both locally and in ORM.
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

locals {
  # Pick first AD
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

module "naming" {
  source            = "../../modules/naming"
  region_key        = var.region_key
  environment_code  = var.environment_code
  stack_code        = var.stack_code
  lab_instance      = var.lab_instance
  common_freeform_tags = var.common_freeform_tags
}

# -----------------------------------------------------------------------------
# Network module (VCN + subnets)
# -----------------------------------------------------------------------------

module "network" {
  source = "../../modules/network"

  compartment_ocid = var.compartment_ocid

  # Naming / tags from naming.tf
  lab_name_core  = local.lab_name_core
  freeform_tags  = local.base_freeform_tags

  # CIDRs
  vcn_cidr             = var.vcn_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidr  = var.private_subnet_cidr

  # Flow logs, etc – can be extended in the module later
  enable_flow_logs = var.enable_flow_logs
}

# -----------------------------------------------------------------------------
# Jumphost / Gateway module (SSH + WireGuard base)
# -----------------------------------------------------------------------------

module "jumphost_gateway" {
  source = "../../modules/jumphost_gateway"

  compartment_ocid   = var.compartment_ocid
  availability_domain = local.availability_domain
  subnet_id          = module.network.public_subnet_id

  lab_name_core = local.lab_name_core
  freeform_tags = local.base_freeform_tags

  shape          = var.jumphost_shape
  ocpus          = var.jumphost_ocpus
  memory_gbs     = var.jumphost_memory_gbs

  assign_public_ip = true

  ssh_authorized_keys = var.ssh_authorized_keys
  ssh_port            = var.ssh_port

  # WireGuard basic toggle, details in module implementation
  enable_wireguard = var.enable_wireguard
}

# -----------------------------------------------------------------------------
# (Optional) Future: DB19 engineering module
#
# module "db19_engineering" { ... }
#
# For the minimal first version, we keep the stack to:
# - VCN + Subnets
# - Jumphost / Gateway
# -----------------------------------------------------------------------------

