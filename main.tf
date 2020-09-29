
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "compartment_ocid" {}
variable "region" {}

provider "oci" {
  region           = "${var.region}"
  tenancy_ocid     = "${var.tenancy_ocid}"
  user_ocid        = "${var.user_ocid}"
  fingerprint      = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
}

locals {
  ssh_key = "${file("/home/ec2-user/ocitest/id_rsa.pub")}"
}

variable "ad_region_mapping" {
  type = "map"

  default = {
    us-seattle-1 = 2
    us-sanjose-1 = 1
  }
}

variable "images" {
  type = "map"

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.5-2018.10.16-0"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaadtmpmfm77czi5ghi5zh7uvkguu6dsecsg7kuo3eigc5663und4za"

    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaayuihpsm2nfkxztdkottbjtfjqhgod7hfuirt2rqlewxrmdlgg75q"
    us-sanjose-1 = "ocid1.image.oc1.us-sanjose-1.aaaaaaaabzxj3lv6j623p2dqmjolk4zslnssbr3qhlmoef6numj6erduvhgq"

  }
}

data "oci_identity_availability_domain" "ad" {
  compartment_id = "${var.tenancy_ocid}"
  ad_number      = "${var.ad_region_mapping[var.region]}"
}

resource "oci_core_virtual_network" "test_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "testVCN"
  dns_label      = "testvcn"
}

resource "oci_core_subnet" "test_subnet" {
  cidr_block        = "10.1.20.0/24"
  display_name      = "testSubnet"
  dns_label         = "testsubnet"
  security_list_ids = ["${oci_core_security_list.test_security_list.id}"]
  compartment_id    = "${var.compartment_ocid}"
  vcn_id            = "${oci_core_virtual_network.test_vcn.id}"
  route_table_id    = "${oci_core_route_table.test_route_table.id}"
  dhcp_options_id   = "${oci_core_virtual_network.test_vcn.default_dhcp_options_id}"
}

resource "oci_core_internet_gateway" "test_internet_gateway" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "testIG"
  vcn_id         = "${oci_core_virtual_network.test_vcn.id}"
}

resource "oci_core_route_table" "test_route_table" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.test_vcn.id}"
  display_name   = "testRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = "${oci_core_internet_gateway.test_internet_gateway.id}"
  }
}

resource "oci_core_security_list" "test_security_list" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.test_vcn.id}"
  display_name   = "testSecurityList"

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "3000"
      min = "3000"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "3005"
      min = "3005"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "80"
      min = "80"
    }
  }
}

resource "oci_core_instance" "free_instance0" {
  availability_domain = "${data.oci_identity_availability_domain.ad.name}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "freeInstance0"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.test_subnet.id}"
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "freeinstance0"
  }

  source_details {
    source_type = "image"
    source_id   = "${var.images[var.region]}"
  }

  metadata = {
    ssh_authorized_keys = "${local.ssh_key}"
  }
}

resource "oci_core_instance" "free_instance1" {
  availability_domain = "${data.oci_identity_availability_domain.ad.name}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "freeInstance1"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = "${oci_core_subnet.test_subnet.id}"
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "freeinstance1"
  }

  source_details {
    source_type = "image"
    source_id   = "${var.images[var.region]}"
  }

  metadata = {
    ssh_authorized_keys = "${local.ssh_key}"
  }
}
