mkdir -p tmpfs-disk
sudo mount -t tmpfs tmpfs tmpfs-disk/ -o size=2G,noswap
dd if=/dev/zero of=tmpfs-disk/data bs=1M count=2048

virsh attach-disk ubuntu1 "$(pwd)/tmpfs-disk/data" vdd

