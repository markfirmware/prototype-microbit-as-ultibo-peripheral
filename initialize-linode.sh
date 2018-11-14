#!/bin/bash
set -e

apt-get update
apt-get -y dist-upgrade
apt-get -y install git tmux apt-transport-https wget

echo "deb https://download.docker.com/linux/debian stretch stable" | tee /etc/apt/sources.list.d/docker.list
wget --quiet --output-document - https://download.docker.com/linux/debian/gpg | apt-key add -
apt-get update
apt-get -y install docker-ce
usermod -aG docker $(whoami)

git config --global user.name markfirmware
git config --global user.email markfirmware@users.noreply.github.com

cat > .exrc << __EOF__
set noai ic
__EOF__

set -x