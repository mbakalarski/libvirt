#!/bin/bash

set -e

echo !!! old fedora1 VM and disks will be removed !!!
read
virsh destroy fedora1 || true
virsh undefine fedora1 --remove-all-storage || true


if [[ -f Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2 ]]; then true; else
wget https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2
fi

if [[ -f Fedora-Cloud-41-1.4-x86_64-CHECKSUM ]]; then true; else
wget https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-41-1.4-x86_64-CHECKSUM
fi

if [[ -f fedora.gpg ]]; then true; else
curl -O https://fedoraproject.org/fedora.gpg
fi


gpgv --keyring ./fedora.gpg Fedora-Cloud-41-1.4-x86_64-CHECKSUM
sha256sum --ignore-missing -c Fedora-Cloud-41-1.4-x86_64-CHECKSUM 2>/dev/null


backing_file="Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"
qemu-img create -f qcow2 -b ${backing_file} -F qcow2 fedora1-01.qcow2 20G

qemu-img create -f qcow2 fedora1-02.qcow2 20G
qemu-img create -f qcow2 fedora1-03.qcow2 20G


###
PASSWORD=lab12345


cat << EOT > fedora1-user-data
#cloud-config

chpasswd:
  list: |
    root:${PASSWORD}
  expire: False

runcmd:
  - hostnamectl set-hostname fedora1
  - #
  - rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
  - echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  - systemctl restart sshd
  - #
  - useradd -m -s /bin/bash student
  - echo ${PASSWORD} | passwd -s student
  - echo "student ALL=(ALL) ALL" >> /etc/sudoers
EOT

###


virt-install --virt-type kvm --name fedora1 \
--osinfo fedora-unknown \
--import \
--memory 2048 --vcpu 2 \
--disk ./fedora1-01.qcow2 \
--disk ./fedora1-02.qcow2 \
--disk ./fedora1-03.qcow2 \
--graphics none \
--console pty,target_type=serial \
--cpu host \
--hvm \
--cloud-init user-data=./fedora1-user-data \
--boot bootmenu.enable=on,bios.useserial=on

# virsh reboot fedora1
# virsh start fedora1
# ssh-copy-id root@...

