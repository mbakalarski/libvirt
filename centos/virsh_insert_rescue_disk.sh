virsh domblklist centos1

virsh attach-disk centos1 "$(pwd)/CentOS-Stream-10-latest-x86_64-dvd1.iso" sda --type cdrom

virsh domblklist centos1


