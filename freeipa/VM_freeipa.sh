#!/bin/bash

set -e


PASSWORD=lab12345



echo !!! old freeipa VM and disks will be removed !!!
read
virsh destroy freeipa.example.local || true
virsh undefine freeipa.example.local --remove-all-storage || true


if [[ -f CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2 ]]; then :; else
wget https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2
fi

if [[ -f CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2.SHA256SUM ]]; then :; else
wget https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2.SHA256SUM
fi

sha256sum -c CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2.SHA256SUM

backing_file="CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2"
qemu-img create -f qcow2 -b ${backing_file} -F qcow2 freeipa-01.qcow2 20G



###
cat << EOT > freeipa-user-data
#cloud-config

hostname: freeipa
fqdn: freeipa.example.local

chpasswd:
  expire: false
  users:
  - {name: root, password: ${PASSWORD}, type: text}

runcmd:
  - IP=\$(hostname -I)
  - echo \$IP freeipa.example.local >> /etc/hosts
  - #
  - rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf || true
  - echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  - systemctl restart sshd
  - #
  - useradd -m -s /bin/bash student
  - echo ${PASSWORD} | passwd -s student
  - echo "student ALL=(ALL) ALL" >> /etc/sudoers
  - #
  - dnf update -y
  - dnf -y install ipa-server bind-dyndb-ldap ipa-server-dns
  - ipa-server-install --setup-dns --no-forwarders -p ${PASSWORD} -a ${PASSWORD} -r EXAMPLE.LOCAL --hostname=freeipa.example.local -U
  - reboot
EOT
###


virt-install --virt-type kvm --name freeipa.example.local \
--osinfo centos-stream10 \
--import \
--memory 8192 --vcpu 4 \
--disk ./freeipa-01.qcow2 \
--graphics none \
--console pty,target_type=serial \
--cpu host \
--hvm \
--cloud-init user-data=./freeipa-user-data \
--boot bootmenu.enable=on,bios.useserial=on



# ssh-copy-id root@...
#
#
virsh start freeipa.example.local --console

