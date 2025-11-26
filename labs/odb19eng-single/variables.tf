# -----------------------------------------------------------------------------
# Core variables (tenancy / compartment / naming)
# -----------------------------------------------------------------------------

variable "compartment_ocid" {
  type        = string
  description = "OCI compartment OCID where the lab resources will be created."
}

# OCI region key used in names, e.g. chzh, eu-frn, uk-lon
variable "region_key" {
  type        = string
  description = "OCI region key used in resource names, e.g. chzh, eu-frn, uk-lon."
}

# Environment code: l (lab), ws (workshop), d (dev), t (test), p (prod)
variable "environment_code" {
  type        = string
  description = "Environment code used in resource names, e.g. l, ws, d, t, p."
  default     = "l"
}

# Stack / lab type, here: Oracle DB 19c Engineering
variable "stack_code" {
  type        = string
  description = "Stack or lab type code, e.g. odb19eng, odb21eng, odbaud."
  default     = "odb19eng"
}

# Lab instance index (for workshops with multiple identical labs)
variable "lab_instance" {
  type        = number
  description = "Numeric index for the lab instance (1 -> 01)."
  default     = 1
}

variable "common_freeform_tags" {
  type = map(string)
  description = "Base freeform tags applied to all resources of this stack."
  default = {
    project = "oradba-labs"
    owner   = "oehrli"
  }
}

# -----------------------------------------------------------------------------
# Network variables
# -----------------------------------------------------------------------------

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the lab VCN."
  default     = "10.19.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet."
  default     = "10.19.10.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet."
  default     = "10.19.20.0/24"
}

variable "enable_flow_logs" {
  type        = bool
  description = "Enable VCN/subnet flow logs where supported by the network module."
  default     = true
}

# -----------------------------------------------------------------------------
# Jumphost / Gateway variables
# -----------------------------------------------------------------------------

variable "jumphost_shape" {
  type        = string
  description = "Shape for the jumphost/gateway VM. For Always Free labs use VM.Standard.A1.Flex."
  default     = "VM.Standard.A1.Flex"
}

variable "jumphost_ocpus" {
  type        = number
  description = "Number of OCPUs for the jumphost/gateway VM."
  default     = 1
}

variable "jumphost_memory_gbs" {
  type        = number
  description = "Memory (GB) for the jumphost/gateway VM."
  default     = 16
}

variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key(s) for the jumphost (content of ~/.ssh/id_rsa.pub, etc.)."
}

variable "ssh_port" {
  type        = number
  description = "SSH port exposed on the jumphost. Some tenants allow 16022 instead of 22."
  default     = 16022
}

variable "enable_wireguard" {
  type        = bool
  description = "Enable WireGuard configuration on the jumphost (details implemented in module)."
  default     = true
}

