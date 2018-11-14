FROM debian:stretch

WORKDIR /root

RUN apt-get update && apt-get -y dist-upgrade && apt-get -y install build-essential
RUN apt-get -y install gdb-minimal
RUN apt-get -y install unzip
RUN apt-get -y install libgtk2.0-dev
RUN apt-get -y install libghc-x11-dev
RUN apt-get -y install binutils-arm-none-eabi
RUN apt-get -y install wget

COPY ultiboinstaller-docker.sh .
RUN ./ultiboinstaller-docker.sh
