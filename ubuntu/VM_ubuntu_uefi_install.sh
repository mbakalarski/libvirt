#!/bin/bash

set -e


echo !!! old ubuntu1 VM and disks will be removed !!!
read
virsh destroy ubuntu1 || true
virsh undefine ubuntu1 --remove-all-storage || true



if [[ -f oracular-server-cloudimg-amd64.img ]]; then :; else
wget https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img
fi

if [[ -f SHA256SUMS ]]; then :; else
wget https://cloud-images.ubuntu.com/oracular/current/SHA256SUMS
fi

sha256sum -c --ignore-missing oracular-server-cloudimg-amd64.img SHA256SUMS 2>/dev/null | grep -q 'oracular-server-cloudimg-amd64.img: OK'


backing_file="oracular-server-cloudimg-amd64.img"
qemu-img create -f qcow2 -b ${backing_file} -F qcow2 ubuntu1-01.qcow2 20G

qemu-img create -f qcow2 ubuntu1-02.qcow2 20G
qemu-img create -f qcow2 ubuntu1-03.qcow2 20G


###
PASSWORD=lab12345


cat << EOT > ubuntu1-user-data
#cloud-config

chpasswd:
  expire: false
  users:
  - {name: root, password: ${PASSWORD}, type: text}

runcmd:
  - hostnamectl set-hostname ubuntu1
  - #
  - find /etc/ssh/sshd_config.d/ /etc/ssh/sshd_config -type f -exec grep -l PermitRootLogin {} \; -exec sed -i 's/PermitRootLogin/#PermitRootLogin/' {} \;
  - find /etc/ssh/sshd_config.d/ /etc/ssh/sshd_config -type f -exec grep -l PermitRootLogin {} \; -exec bash -c -- "echo 'PermitRootLogin yes' | tee -a {}" \;
  - find /etc/ssh/sshd_config.d/ /etc/ssh/sshd_config -type f -exec grep -l PasswordAuthentication {} \; -exec sed -i 's/PasswordAuthentication/#PasswordAuthentication/' {} \;
  - find /etc/ssh/sshd_config.d/ /etc/ssh/sshd_config -type f -exec grep -l PasswordAuthentication {} \; -exec bash -c -- "echo 'PasswordAuthentication yes' | tee -a {}" \;
  - systemctl restart sshd
  - #
  - #
  - useradd -m -s /bin/bash student
  - echo ${PASSWORD} | passwd -s student
  - echo "student ALL=(ALL) ALL" >> /etc/sudoers
EOT

###


virt-install --virt-type kvm --name ubuntu1 \
--osinfo ubuntu24.10 \
--import \
--memory 2048 --vcpu 2 \
--disk ./ubuntu1-01.qcow2 \
--disk ./ubuntu1-02.qcow2 \
--disk ./ubuntu1-03.qcow2 \
--graphics none \
--console pty,target_type=serial \
--cpu host \
--hvm \
--boot loader=$(pwd)/OVMF.fd \
--cloud-init user-data=./ubuntu1-user-data


# ssh-copy-id root@...
# ssh-copy-id student@...
#

