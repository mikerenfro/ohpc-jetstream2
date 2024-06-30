provider "openstack" {
}

## Networking

### Create network segment for systems with external services
resource "openstack_networking_network_v2" "ohpc-external" {
  name = "ohpc-vpc-external"
  admin_state_up = "true"
}

### Create network segment for systems that are purely internal
resource "openstack_networking_network_v2" "ohpc-internal" {
  name = "ohpc-vpc-internal"
  admin_state_up = "true"
}

### Assign IPv4 range for external network segment
resource "openstack_networking_subnet_v2" "ohpc-external-ipv4" {
  name = "ohpc-external-ipv4"
  network_id = openstack_networking_network_v2.ohpc-external.id
  cidr = "10.4.0.0/16"
  ip_version = 4
}

### Assign IPv4 range for internal network segment
resource "openstack_networking_subnet_v2" "ohpc-internal-ipv4" {
  name = "ohpc-internal-ipv4"
  network_id = openstack_networking_network_v2.ohpc-internal.id
  enable_dhcp = false
  cidr = "10.5.0.0/16"
  # reserve 10.5.0.0/24 and 10.5.255.0/24 for static IPs
  allocation_pool {
    start = "10.5.1.0"
    end = "10.5.254.254"
  }
  ip_version = 4
}

### Assign IPv6 range for external network segment from the shared-default-ipv6 subnet pool
resource "openstack_networking_subnet_v2" "ohpc-external-ipv6" {
  name = "ohpc-external-ipv6"
  network_id = openstack_networking_network_v2.ohpc-external.id
  subnetpool_id = var.openstack_subnet_pool_shared_ipv6
  ip_version = 6
  ipv6_address_mode = "dhcpv6-stateful"
  ipv6_ra_mode = "dhcpv6-stateful"
}

### Create router interfaces connected to the external (IPv4 and v6) and internal (IPv4) network segments
resource "openstack_networking_router_interface_v2" "ohpc-external-ipv4" {
  router_id = var.openstack_router_id
  subnet_id = openstack_networking_subnet_v2.ohpc-external-ipv4.id
}

resource "openstack_networking_router_interface_v2" "ohpc-internal-ipv4" {
  router_id = var.openstack_router_id
  subnet_id = openstack_networking_subnet_v2.ohpc-internal-ipv4.id
}

resource "openstack_networking_router_interface_v2" "ohpc-external-ipv6" {
  router_id = var.openstack_router_id
  subnet_id = openstack_networking_subnet_v2.ohpc-external-ipv6.id
}

### Reserve a public IPv4 address for the management node
resource "openstack_networking_floatingip_v2" "ohpc" {
  pool = "public"
}

### Create security groups for external and internal network segments
resource "openstack_networking_secgroup_v2" "ohpc-external" {
  name        = "ohpc-sg-external"
}

resource "openstack_networking_secgroup_v2" "ohpc-internal" {
  name        = "ohpc-sg-internal"
}

### Allow ssh into the external network segment from anywhere (both IPv4 and v6)
resource "openstack_networking_secgroup_rule_v2" "ohpc-external-ipv4-ssh" {
  security_group_id = openstack_networking_secgroup_v2.ohpc-external.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "ohpc-external-ipv6-ssh" {
  security_group_id = openstack_networking_secgroup_v2.ohpc-external.id
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "::/0"
}

## Allow ping into the external network segment from anywhere (both IPv4 and v6)
resource "openstack_networking_secgroup_rule_v2" "ohpc-external-ipv4-icmp" {
  security_group_id = openstack_networking_secgroup_v2.ohpc-external.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "ohpc-external-ipv6-icmp" {
  security_group_id = openstack_networking_secgroup_v2.ohpc-external.id
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "ipv6-icmp"
  remote_ip_prefix  = "::/0"
}

### Define ingress rules mapping the external subnet to the external IPv4 and v6 ranges
resource "openstack_networking_secgroup_rule_v2" "ohpc-external-ipv4-subnet" {
  security_group_id = openstack_networking_secgroup_v2.ohpc-external.id
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = openstack_networking_subnet_v2.ohpc-external-ipv4.cidr
}

resource "openstack_networking_secgroup_rule_v2" "ohpc-external-ipv6-subnet" {
  security_group_id = openstack_networking_secgroup_v2.ohpc-external.id
  direction         = "ingress"
  ethertype         = "IPv6"
  remote_ip_prefix  = openstack_networking_subnet_v2.ohpc-external-ipv6.cidr
}

### Define ingress rule mapping the internal subnet to the internal IPv4 range
resource "openstack_networking_secgroup_rule_v2" "ohpc-internal-ipv4-subnet" {
  security_group_id = openstack_networking_secgroup_v2.ohpc-internal.id
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = openstack_networking_subnet_v2.ohpc-internal-ipv4.cidr
}

# resource "openstack_networking_secgroup_rule_v2" "ohpc-external-ipv4-ingress" {
#   security_group_id = openstack_networking_secgroup_v2.ohpc-external.id
#   direction         = "ingress"
#   ethertype         = "IPv4"
#   remote_ip_prefix  = "0.0.0.0/0"
# }

# resource "openstack_networking_secgroup_rule_v2" "ohpc-external-ipv6-ingress" {
#   security_group_id = openstack_networking_secgroup_v2.ohpc-external.id
#   direction         = "ingress"
#   ethertype         = "IPv6"
#   remote_ip_prefix  = "::/0"
# }

### Prepare connections between each of the external IPv4 and v6 subnets and the OpenHPC management node
resource "openstack_networking_port_v2" "ohpc-external" {
  name           = "ohpc-port-external-head"
  admin_state_up = "true"
  network_id = openstack_networking_network_v2.ohpc-external.id

  security_group_ids = [openstack_networking_secgroup_v2.ohpc-external.id]
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.ohpc-external-ipv4.id
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-external-ipv4.cidr, 8)
  }
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.ohpc-external-ipv6.id
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-external-ipv6.cidr, 8)
  }
}

### Prepare connection between the internal IPv4 subnet and the OpenHPC management node
resource "openstack_networking_port_v2" "ohpc-internal" {
  name           = "ohpc-port-internal-head"
  admin_state_up = "true"
  network_id = openstack_networking_network_v2.ohpc-internal.id

  port_security_enabled = false
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.ohpc-internal-ipv4.id
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-internal-ipv4.cidr, 8)
  }
}

### Assign the public IPv4 address to the OpenHPC management node
resource "openstack_networking_floatingip_associate_v2" "ohpc" {
  floating_ip = openstack_networking_floatingip_v2.ohpc.address
  port_id = openstack_networking_port_v2.ohpc-external.id
}

## Compute

### Define an SSH public key that will be added to the OpenHPC management node's user's authorized_keys file
resource "openstack_compute_keypair_v2" "ohpc-keypair" {
  name       = "ohpc-keypair"
  public_key = var.ssh_public_key
}

### Define the OpenHPC management node as Rocky 9 with 2 cores, 6 GB RAM, 20 GB disk.
### Connect it to both the external and internal network segments.
### Add the previously-defined SSH public key to the authorized_keys file for user 'rocky'
### Delete root's password to make debugging from the local console easier (use username 'root', then hit Enter at the password prompt)
### Prevent root from logging in over SSH (by default, only works with authorized_keys entries, so removing root's authorized_keys file disables that route)
resource "openstack_compute_instance_v2" "ohpc" {
  name = "head"
  image_name = "Featured-RockyLinux9"
  flavor_name = "m3.small"
  key_pair = "ohpc-keypair"
  network {
    port = openstack_networking_port_v2.ohpc-external.id
  }
  network {
    port = openstack_networking_port_v2.ohpc-internal.id
  }
  user_data = <<-EOF
    #!/bin/bash
    passwd -d root
    rm -v /root/.ssh/authorized_keys
    EOF
}

### Define a group of OpenHPC compute nodes using the EFI iPXE image with 2 cores, 6 GB RAM, 20 GB disk.
### Connect them to the internal network segment and security group.
resource "openstack_compute_instance_v2" "node" {
  count = 1
  name = "c${count.index}"
  image_name = "efi-ipxe"
  flavor_name = "m3.small"
  network {
    uuid = openstack_networking_network_v2.ohpc-internal.id
    fixed_ip_v4 = cidrhost(openstack_networking_subnet_v2.ohpc-internal-ipv4.cidr, 256 + count.index)
  }
  security_groups = [openstack_networking_secgroup_v2.ohpc-internal.name]
}

## Output

### Create an Ansible inventory on the local system, including the OpenHPC managment node's external IP
resource "local_file" "ansible" {
  filename = "local.ini"
  content = <<-EOF
    ## auto-generated
    [ohpc]
    head ansible_host=${openstack_networking_port_v2.ohpc-external.all_fixed_ips[1]} ansible_user=rocky arch=x86_64

    [ohpc:vars]
    sshkey=${var.ssh_public_key}
    EOF
}

### Show the OpenHPC management node's external IPv4 and v6 addresses, so that they can be accessed with "ssh rocky@OHPC_IP"
output "ohpc_ipv4" {
  value = openstack_networking_floatingip_v2.ohpc.address
}

output "ohpc_ipv6" {
  value = openstack_networking_port_v2.ohpc-external.all_fixed_ips[1]
}
