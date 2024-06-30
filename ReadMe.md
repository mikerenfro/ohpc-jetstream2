# OpenHPC 3.x, ww4, Rocky9, OpenStack/Jetstream2

## Software prerequisites

### For building the iPXE disk image

- Linux OS
- mtools
- git
- gcc

If you don't have a Linux system you regularly use and administer, you can build a [Vagrant](https://www.vagrantup.com) virtual machine with the included `Vagrantfile` that will include all required software.

### For managing the cloud infrastructure

- [opentofu](https://opentofu.org/docs/intro/install/)
- [Python OpenStack client](https://pypi.org/project/python-openstackclient/)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/)

The included Vagrant virtual machine also has these installed.

## Settings prerequisites

- an active Jetstream2 allocation
- a copy of this `ohpc-jetstream2` repository, via `git clone` or `.zip` download
- an openrc.sh file from a Jetstream2 application credential (named `app-cred-$SOMETHING-openrc.sh`), copied to the repository folder.

See [Authenticating Against the OpenStack CLI (Logging In)](https://docs.jetstream-cloud.org/ui/cli/auth/) for information on generating an openrc.sh file.

Source your openrc.sh file and verify you can access Jetstream via the `openstack` client:

```bash
$ source app-cred-myallocation-openrc.sh
$ openstack image list
+--------------------------------------+------------------------------+--------+
| ID                                   | Name                         | Status |
+--------------------------------------+------------------------------+--------+
| 7009d616-620c-4172-8901-0d2eeb55c434 | Featured-AlmaLinux8          | active |
...
```

The Vagrant virtual machine will automatically copy any `app-cred-*-openrc.sh` in this folder into the `vagrant` user's startup files, so you should be able to skip the explicit `source` line if you use the Vagrant VM.

## Setup

### OpenTofu settings

Create a new file `ssh_key.tf` in this folder with contents of

```
variable "ssh_public_key" {
    type = string
    default = "$SSH_KEY_TYPE $SSH_PUBLIC_KEY_CONTENT"
}
```

where `$SSH_KEY_TYPE` and `$SSH_PUBLIC_KEY_CONTENT` are from the ssh public key for the user that will run Ansible.
The Vagrant virtual machine will automatically create this file with the `vagrant` user's ED25519 key.

Create a new file `local.tf` in this folder with contents of

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
Get `$SHARED_IPV6` from the output of `openstack subnet show my-existing-subnet -c subnetpool_id`.

Since there is only one main router - populate the `$ROUTER_ID` and `$SHARED_IVP6` pool variables. This could be automated with `openstack port list --router` and a tofu import (see router docs).

### Create the EFI-iPXE image

The EFI-iPXE image will be used to build diskless compute nodes that will boot from the OpenHPC management node.

The image must have the following properties:
```ini
hw_firmware_type=uefi
hw_scsi_model=virtio-scsi
```

Create the disk image with:
```bash
./ipxe.sh
```

The Vagrant virtual machine will automatically create `disk.img` if it doesn't exist already.

Upload the disk image to your allocation with:
```bash
openstack image create --disk-format raw --file disk.img --property hw_firmware_type='uefi' --property hw_scsi_model='virtio-scsi' --property hw_machine_type=q35 efi-ipxe
```

## Debugging

```bash
openstack console log show c0
ssh -i ~/.ssh/id_rsa -R 8180 c0
export all_proxy=socks5h://127.0.0.1:8180
scontrol update nodename=c0 state=RESUME
```
