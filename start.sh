#!/bin/ash

# disconnect all virtual terminals (for GPU passthrough to work)
test -e /sys/class/vtconsole/vtcon0/bind && echo 0 > /sys/class/vtconsole/vtcon0/bind
test -e /sys/class/vtconsole/vtcon1/bind && echo 0 > /sys/class/vtconsole/vtcon1/bind
test -e /sys/devices/platform/efi-framebuffer.0/driver && echo "efi-framebuffer.0" > /sys/devices/platform/efi-framebuffer.0/driver/unbind

# load vfio drivers onto devices if it's not loaded (for GPU passthrough to work)
modprobe vfio_pci
modprobe vfio_iommu_type1
# for pci_id in "0000:01:00.0" "0000:01:00.1" "0000:01:00.2" "0000:01:00.3"; do
#  test -e /sys/bus/pci/devices/$pci_id/driver && echo -n "$pci_id" > /sys/bus/pci/devices/$pci_id/driver/unbind
#  echo "$(cat /sys/bus/pci/devices/$pci_id/vendor) $(cat /sys/bus/pci/devices/$pci_id/device)" > /sys/bus/pci/drivers/vfio-pci/new_id
# done
# while [ ! -e /dev/vfio ]; do sleep 1; done

# gracefully shut down QEMU when docker tries stopping it
trap 'echo system_powerdown | socat - UNIX-CONNECT:/var/run/qemu_monitor' SIGTERM

run qemu
qemu-system-x86_64 \
  -nodefaults \
  -monitor stdio \
  -monitor unix:/var/run/qemu_monitor,server,nowait `# so we can send system_powerdown instead of hard stop when docker shuts down` \
  \
  -machine type=q35 `# allows for PCIe` \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd `# read-only UEFI bios` \
  -drive if=pflash,format=raw,file=/qemu-win10.nvram `# UEFI writeable NVRAM` \
  -rtc clock=host,base=localtime `# faster boot aparently` \
  -device qemu-xhci `# USB3 bus` \
  \
  -enable-kvm \
  -cpu host,check,enforce,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,l3-cache=on,-hypervisor,kvm=off,migratable=no,+invtsc,hv_vendor_id=1234567890ab \
  -smp 4,sockets=1,cores=2,threads=2 \
  -m 8192 \
  \
  -drive index=0,media=cdrom,file=/win10.iso \
  -drive index=1,media=cdrom,file=/virtio.iso \
  -object iothread,id=io1 \
  -device virtio-blk-pci,drive=disk0,iothread=io1 \
  -drive if=none,id=disk0,cache=none,format=raw,aio=threads,file=/win10.raw \
  \
  -nic user,model=virtio-net-pci `# simple passthrough networking that cant ping` \
  \
  -device vfio-pci,host=0000:00:1f.3,id=hostdev0 \
  -device vfio-pci,host=0000:01:00.1,id=hostdev1 \
  -device vfio-pci,host=0000:01:00.0,id=hostdev2 \
  \
  -object input-linux,id=kbd1,evdev=/dev/input/by-id/usb-Logitech_USB_Keyboard-event-kbd,grab_all=on,repeat=on \
  -object input-linux,id=mouse1,evdev=/dev/input/by-id/usb-Logitech_USB_Optical_Mouse-event-mouse \
  \
  -vga none \
  -nographic &
QEMU_PID=$!

while [ -e /proc/$QEMU_PID ]; do sleep 1; done
