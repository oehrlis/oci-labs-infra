# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Provision VCN, gateways, route tables, security lists, subnets, and flow logs.
# Notes......: Uses lab_name_core for consistent naming; tags inherit from freeform_tags input.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  # Shortcuts for names
  vcn_name            = "vcn-${var.lab_name_core}-net-01"
  public_subnet_name  = "sn-${var.lab_name_core}-public-01"
  private_subnet_name = "sn-${var.lab_name_core}-private-01"
  db_subnet_name      = "sn-${var.lab_name_core}-db-01"
  app_subnet_name     = "sn-${var.lab_name_core}-app-01"

  public_sl_name  = "sl-${var.lab_name_core}-public-01"
  private_sl_name = "sl-${var.lab_name_core}-private-01"
  db_sl_name      = "sl-${var.lab_name_core}-db-01"
  app_sl_name     = "sl-${var.lab_name_core}-app-01"

  public_rt_name  = "rtb-${var.lab_name_core}-public-01"
  private_rt_name = "rtb-${var.lab_name_core}-private-01"
  db_rt_name      = "rtb-${var.lab_name_core}-db-01"
  app_rt_name     = "rtb-${var.lab_name_core}-app-01"

  log_group_name = "lg-${var.lab_name_core}-net-01"
  flow_log_name  = "log-${var.lab_name_core}-vcn-flow-01"
}

# -----------------------------------------------------------------------------
# VCN
# -----------------------------------------------------------------------------

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = local.vcn_name
  dns_label      = replace(substr(var.lab_name_core, 0, 15), "-", "")

  freeform_tags = var.freeform_tags
}


# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "oci_core_internet_gateway" "igw" {
  count          = var.internet_gateway_enabled ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "igw-${var.lab_name_core}-01"

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------

resource "oci_core_nat_gateway" "nat" {
  count          = var.nat_gateway_enabled ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "ngw-${var.lab_name_core}-01"

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.public_rt_name

  dynamic "route_rules" {
    for_each = var.internet_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_internet_gateway.igw[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.private_rt_name

  dynamic "route_rules" {
    for_each = var.nat_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.nat[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_route_table" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.db_rt_name

  dynamic "route_rules" {
    for_each = var.nat_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.nat[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_route_table" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.app_rt_name

  dynamic "route_rules" {
    for_each = var.nat_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.nat[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Security Lists
# -----------------------------------------------------------------------------

# Public subnet: SSH, WireGuard, optional HTTP/HTTPS, all egress
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.public_sl_name
  freeform_tags  = var.freeform_tags

  # Egress: weiterhin alles raus erlaubt
  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }

  # WireGuard UDP – für jede erlaubte CIDR
  dynamic "ingress_security_rules" {
    for_each = var.allowed_wireguard_cidrs
    content {
      protocol    = "17" # UDP
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false

      udp_options {
        min = var.wireguard_port
        max = var.wireguard_port
      }
    }
  }

  # SSH TCP – für jede erlaubte CIDR
  dynamic "ingress_security_rules" {
    for_each = var.allowed_ssh_cidrs
    content {
      protocol    = "6" # TCP
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false

      tcp_options {
        min = var.ssh_port
        max = var.ssh_port
      }
    }
  }
}

# Private, DB, App: allow all within VCN, egress all
resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.private_sl_name

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_security_list" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.db_sl_name

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_security_list" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.app_sl_name

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = local.public_subnet_name
  dns_label                  = "pub"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = var.freeform_tags
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = local.private_subnet_name
  dns_label                  = "priv"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = var.freeform_tags
}

resource "oci_core_subnet" "db" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.db_subnet_cidr
  display_name               = local.db_subnet_name
  dns_label                  = "db"
  route_table_id             = oci_core_route_table.db.id
  security_list_ids          = [oci_core_security_list.db.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = var.freeform_tags
}

resource "oci_core_subnet" "app" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.app_subnet_cidr
  display_name               = local.app_subnet_name
  dns_label                  = "app"
  route_table_id             = oci_core_route_table.app.id
  security_list_ids          = [oci_core_security_list.app.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Logging: Log Group + VCN Flow Logs
# -----------------------------------------------------------------------------
resource "oci_logging_log_group" "net" {
  compartment_id = var.compartment_ocid
  display_name   = local.log_group_name

  freeform_tags = var.freeform_tags
}

# Flow Logs pro Subnet (public / private / db / app)
locals {
  flow_log_targets = {
    public  = oci_core_subnet.public.id
    private = oci_core_subnet.private.id
    db      = oci_core_subnet.db.id
    app     = oci_core_subnet.app.id
  }
}

resource "oci_logging_log" "vcn_flow" {
  for_each = local.flow_log_targets

  log_group_id       = oci_logging_log_group.net.id
  display_name       = "log-${var.lab_name_core}-${each.key}-flow-01"
  log_type           = "SERVICE"
  is_enabled         = true
  retention_duration = var.flow_log_retention_duration

  configuration {
    source {
      category    = "all"
      resource    = each.value
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
  }

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Default Route Table "neutralisieren"
# -----------------------------------------------------------------------------

resource "oci_core_default_route_table" "default_rt" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id

  display_name = "rtb-${var.lab_name_core}-default-unused"

  # Ziel: keine Route-Regeln in der Default-RT.
  # Je nach Provider-Version kann es sein, dass du hier eine
  # leere Liste explizit setzen musst oder den Block komplett weglässt.
  # Falls `route_rules = []` meckert, einfach den Block löschen und
  # in der Doku kurz prüfen, wie der Provider leere Regeln erwartet.
  route_rules = []

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Default Security List leeren
# -----------------------------------------------------------------------------

resource "oci_core_default_security_list" "default_sl" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id

  display_name = "sl-${var.lab_name_core}-default-empty"

  # Keine eingehenden Regeln
  ingress_security_rules = []

  # Keine ausgehenden Regeln
  egress_security_rules = []

  freeform_tags = var.freeform_tags
}

# --- EOF ----------------------------------------------------------------------
