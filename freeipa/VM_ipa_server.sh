#!/bin/bash

set -e
source .env


echo !!! old ipas VM and disks will be removed !!!
read
virsh destroy ipas.example.local || true
virsh undefine ipas.example.local --remove-all-storage || true


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
qemu-img create -f qcow2 -b ${backing_file} -F qcow2 ipas-01.qcow2 20G



###
cat << EOT > ipas-user-data
#cloud-config

hostname: ipas
fqdn: ipas.example.local

chpasswd:
  expire: false
  users:
  - {name: root, password: ${PASSWORD}, type: text}

runcmd:
  - IP=\$(hostname -I)
  - echo \$IP ipas.example.local >> /etc/hosts
  - timedatectl set-timezone UTC
  - dnf update -y
  - #
  - rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf || true
  - echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  - systemctl restart sshd
  - #
  - useradd -m -s /bin/bash student
  - echo ${PASSWORD} | passwd -s student
  - echo "student ALL=(ALL) ALL" >> /etc/sudoers
  - #
  - dnf -y install ipa-server bind-dyndb-ldap ipa-server-dns
  - ipa-server-install --setup-dns --no-forwarders -p ${PASSWORD} -a ${PASSWORD} -r EXAMPLE.LOCAL --hostname=ipas.example.local -U
  - #
  - dnf install firewalld -y
  - for i in dns ntp http https ldap ldaps kerberos kpasswd ; do firewall-cmd --add-service \$i --permanent ; done
  - firewall-cmd --reload
  - reboot
EOT
###


virt-install --virt-type kvm --name ipas.example.local \
--osinfo centos-stream10 \
--import \
--memory 8192 --vcpu 4 \
--disk ./ipas-01.qcow2 \
--graphics none \
--console pty,target_type=serial \
--cpu host \
--hvm \
--cloud-init user-data=./ipas-user-data \
--boot bootmenu.enable=on,bios.useserial=on


IPA_SERVER_IP=$(virsh net-dhcp-leases default | awk '/ipas/ {printf $5}' | cut -d/ -f1)
sed -i 's/^IPA_SERVER_IP=\(.*\)/#IPA_SERVER_IP=\1/' .env
echo IPA_SERVER_IP=${IPA_SERVER_IP} >> .env


virsh start ipas.example.local --console


# ssh-copy-id root@...
#
#
