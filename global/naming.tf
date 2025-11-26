# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: naming.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Centralized naming and tagging helpers for OraDBA lab stacks.
# Notes......: Keep naming patterns consistent across lab resources.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------

# OCI region key, e.g. chzh, eu-frn, uk-lon
variable "region_key" {
  type        = string
  description = "OCI region key used in resource names, e.g. chzh, eu-frn, uk-lon."
}

# Environment code: l (lab), ws (workshop), d (dev), t (test), p (prod)
variable "environment_code" {
  type        = string
  description = "Environment code used in resource names, e.g. l (lab), ws (workshop), d, t, p."
  default     = "l"
}

# Stack / lab type, e.g. odb19eng, odb21eng, odb26ai, odbaud, odbwls, od badb
variable "stack_code" {
  type        = string
  description = "Stack or lab type code, e.g. odb19eng, odb21eng, odbaud."
}

# Lab instance index (for multiple labs of the same type), e.g. 1 -> 01
variable "lab_instance" {
  type        = number
  description = "Numeric index for the lab instance, used to build names (1 -> 01)."
  default     = 1
}

# Common freeform tags applied to all resources, can be extended per resource.
variable "common_freeform_tags" {
  type        = map(string)
  description = <<EOT
Base freeform tags applied to all resources of this stack.
Can be merged with resource-specific tags.
EOT
  default = {
    project = "oradba-labs"
    owner   = "oehrli"
  }
}

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  # Lab instance as two-digit string, e.g. 01, 02, 03
  lab_instance_padded = format("%02d", var.lab_instance)

  # Core name segment used inside all resource names:
  # {region}-{env}-{stack}-{instance}
  #
  # Example: chzh-l-odb19eng-01
  lab_name_core = "${var.region_key}-${var.environment_code}-${var.stack_code}-${local.lab_instance_padded}"

  # Base freeform tags for this lab / stack. Extend per resource if needed.
  base_freeform_tags = merge(
    var.common_freeform_tags,
    {
      stack   = var.stack_code
      env     = var.environment_code
      region  = var.region_key
      lab_idx = local.lab_instance_padded
    }
  )
}

# ------------------------------------------------------------------------------
# Usage examples (copy/paste into resources)
# ------------------------------------------------------------------------------
#
# Example: VCN name
#   vcn-chzh-l-odb19eng-net-01
#
# resource "oci_core_vcn" "this" {
#   display_name   = "vcn-${local.lab_name_core}-net-01"
#   freeform_tags  = local.base_freeform_tags
#   # ...
# }
#
# Example: Public subnet
#   sn-chzh-l-odb19eng-public-01
#
# resource "oci_core_subnet" "public" {
#   display_name   = "sn-${local.lab_name_core}-public-01"
#   freeform_tags  = local.base_freeform_tags
#   # ...
# }
#
# Example: Jumphost / Gateway instance
#   ci-chzh-l-odb19eng-gw-01
#
# resource "oci_core_instance" "jumphost" {
#   display_name   = "ci-${local.lab_name_core}-gw-01"
#   freeform_tags  = local.base_freeform_tags
#   # ...
# }
#
# Example: Primary and Standby DB hosts
#   ci-chzh-l-odb19eng-pri-01
#   ci-chzh-l-odb19eng-stb-01
#
# resource "oci_core_instance" "db_primary" {
#   display_name   = "ci-${local.lab_name_core}-pri-01"
#   freeform_tags  = local.base_freeform_tags
#   # ...
# }
#
# resource "oci_core_instance" "db_standby" {
#   display_name   = "ci-${local.lab_name_core}-stb-01"
#   freeform_tags  = local.base_freeform_tags
#   # ...
# }
#
# If you need an additional qualifier (e.g. sec, demo, ha), simply insert it
# before the instance number, for example:
#   ci-${local.lab_name_core}-gw-sec-01
#
# --- EOF ----------------------------------------------------------------------
