#!/bin/bash

for id in '0000:00:1f.0' '0000:00:1f.3' '0000:00:1f.4' '0000:00:1f.5'
do
    echo "$id" > /sys/bus/pci/drivers/vfio-pci/unbind

    echo "$id" > /sys/bus/pci/drivers/snd_hda_intel/bind
done

sleep 1;
alsa force-reload
