#!/bin/bash
set -ex

# on raspbian, build the program and reboot to it

./build.sh

sudo cp microbitdemo-kernel-RPI3.img /boot
sudo cp microbitdemo-config.txt microbitdemo-cmdline.txt /boot
sudo cp /boot/microbitdemo-config.txt /boot/config.txt
sleep 2
sudo reboot
