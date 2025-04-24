virsh domblklist ubuntu1
virsh attach-disk ubuntu1 "$(pwd)/ubuntu-24.04.2-live-server-amd64.iso" sda --type cdrom
virsh domblklist ubuntu1
