# OpenHPC 3.x, ww4, Rocky9, OpenStack/Jetstream2

## Software prerequisites

### For building the iPXE disk image

- Linux OS
- mtools
- git
- gcc

If you don't have a Linux system you regularly use and administer, you can build a Vagrant virtual machine with the included `Vagrantfile` that will include all of the above and build a disk image on startup.

### For managing the cloud infrastructure

- opentofu
- Python OpenStack client
- Ansible

The included Vagrant virtual machine also has these installed.

## Settings prerequisites

- active Jetstream2 allocation
- openrc.sh file from a Jetstream2 application credential (default name `app-cred-FOO-openrc.sh`)

See [Authenticating Against the OpenStack CLI (Logging In)](https://docs.jetstream-cloud.org/ui/cli/auth/) for information on generating an openrc.sh file.

## Setup

### OpenTofu settings

Create a new file `ssh_key.tf` with contents of

```
variable "ssh_public_key" {
    type = string
    default = "$SSH_KEY_TYPE $SSH_PUBLIC_KEY_CONTENT"
}
```

where `$SSH_KEY_TYPE` and `$SSH_PUBLIC_KEY_CONTENT` are from your preferred ssh public key.
The Vagrant virtual machine will automatically create this file with the vagrant user's ED25519 key.

Create a new file `local.tf` with contents of

```
variable "openstack_router_id" {
    type = string
    default = "$ROUTER_ID"
}

variable "openstack_subnet_pool_shared_ipv6" {
    type = string
    default = "$SHARED_IPV6"
}
```

Get `$ROUTER_ID` from the output of `openstack router show my-existing-router -c id`.
Get `$SHARED_IPV6` from the output of `openstack subnet show renfro-test-subnet -c subnetpool_id`.

Since there is only one main router - populate the `$ROUTER_ID` and `$SHARED_IVP6` pool variables. This could be automated with `openstack port list --router` and a tofu import (see router docs).


### Create the EFI image

Must have the following properties:
```ini
hw_firmware_type=uefi
hw_scsi_model=virtio-scsi
```

```bash
./ipxe.sh
openstack image create --disk-format raw --file disk.img --property hw_firmware_type='uefi' --property hw_scsi_model='virtio-scsi' --property hw_machine_type=q35 efi-ipxe
```

The Vagrant virtual machine will automatically create `disk.img` if it doesn't exist already.

## Debug
```bash
openstack console log show c0
ssh -i ~/.ssh/id_rsa -R 8180 c0
export all_proxy=socks5h://127.0.0.1:8180
scontrol update nodename=c0 state=RESUME
```
