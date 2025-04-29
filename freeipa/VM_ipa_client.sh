#!/bin/bash

set -e
source .env


echo !!! old ipac VM and disks will be removed !!!
read
virsh destroy ipac.example.local || true
virsh undefine ipac.example.local --remove-all-storage || true


IMAGE="CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2"
if [[ -f $IMAGE ]]; then :; else
wget https://cloud.centos.org/centos/10-stream/x86_64/images/${IMAGE}
fi

HASH_FILE=CentOS-Stream-GenericCloud-x86_64-10-latest.x86_64.qcow2.SHA256SUM
if [[ -f $HASH_FILE ]]; then :; else
wget https://cloud.centos.org/centos/10-stream/x86_64/images/${HASH_FILE}
fi

sha256sum -c $HASH_FILE

backing_file=$IMAGE
qemu-img create -f qcow2 -b ${backing_file} -F qcow2 ipac-01.qcow2 20G



###
cat << EOT > ipac-user-data
#cloud-config

fqdn: ipac.example.local

chpasswd:
  expire: false
  users:
  - {name: root, password: ${PASSWORD}, type: text}

runcmd:
  - IP=\$(hostname -I)
  - echo \$IP ipac.example.local >> /etc/hosts
  - timedatectl set-timezone UTC
  - #
  - cname=\$(nmcli -t c show --active | awk -F':' '/ethernet/ {print \$1}')
  - #nmcli con modify "\$cname" ipv4.ignore-auto-dns yes
  - nmcli con modify "\$cname" +ipv4.dns "$IPA_SERVER_IP"
  - nmcli con down "\$cname" && nmcli con up "\$cname"
  - #
  - dnf update -y
  - #
  - rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf || true
  - echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  - systemctl restart sshd
  - #
  - dnf install ipa-client openldap-clients -y
  - ipa-client-install --mkhomedir --server=ipas.example.local --domain=example.local --realm=EXAMPLE.LOCAL --no-ntp -p admin -w $PASSWORD --all-ip-addresses --force-join -U
  - reboot
EOT
###


virt-install --virt-type kvm --name ipac.example.local \
--osinfo centos-stream10 \
--import \
--memory 2048 --vcpu 2 \
--disk ./ipac-01.qcow2 \
--graphics none \
--console pty,target_type=serial \
--cpu host \
--hvm \
--cloud-init user-data=./ipac-user-data \
--boot bootmenu.enable=on,bios.useserial=on


# ssh-copy-id root@...
#
#
virsh start ipac.example.local --console

