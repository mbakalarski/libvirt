#!/bin/bash

set -e


source .env



echo !!! old centos1 VM and disks will be removed !!!
read
virsh destroy centos1 || true
virsh undefine centos1 --remove-all-storage || true


if [[ -f CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2 ]]; then :; else
wget https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2
fi

if [[ -f CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2.SHA256SUM ]]; then :; else
wget https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2.SHA256SUM
fi

sha256sum -c CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2.SHA256SUM

backing_file="CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2"
qemu-img create -f qcow2 -b ${backing_file} -F qcow2 centos1-01.qcow2 20G

qemu-img create -f qcow2 centos1-02.qcow2 20G
qemu-img create -f qcow2 centos1-03.qcow2 20G


###
cat << EOT > centos1-user-data
#cloud-config

chpasswd:
  expire: false
  users:
  - {name: root, password: ${PASSWORD}, type: text}

runcmd:
  - hostnamectl set-hostname centos1
  - #
  - rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf || true
  - echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  - systemctl restart sshd
  - #
  - useradd -m -s /bin/bash student
  - echo ${PASSWORD} | passwd -s student
  - echo "student ALL=(ALL) ALL" >> /etc/sudoers
EOT
###


virt-install --virt-type kvm --name centos1 \
--osinfo centos-stream10 \
--import \
--memory 8192 --vcpu 4 \
--disk ./centos1-01.qcow2 \
--disk ./centos1-02.qcow2 \
--disk ./centos1-03.qcow2 \
--graphics none \
--console pty,target_type=serial \
--cpu host \
--hvm \
--cloud-init user-data=./centos1-user-data \
--boot bootmenu.enable=on,bios.useserial=on



# ssh-copy-id root@...
#
