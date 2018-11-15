FROM debian:stretch

WORKDIR /root

RUN apt-get update && apt-get -y dist-upgrade && apt-get -y install curl qemu-system-arm unzip wget build-essential

RUN curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y && \
    echo 'export PATH=/root/.nimble/bin:$PATH' >> ~/.bashrc

RUN mkdir -p bin                                                                            && \
    echo 'export PATH=/root/bin:$PATH' >> ~/.bashrc                                         && \
    cd bin                                                                                  && \
    wget https://github.com/elm/compiler/releases/download/0.19.0/binaries-for-linux.tar.gz && \
    tar zxf binaries-for-linux.tar.gz                                                       && \
    rm binaries-for-linux.tar.gz

RUN apt-get -y install gdb-minimal libgtk2.0-dev libghc-x11-dev binutils-arm-none-eabi
COPY ultiboinstaller-docker.sh .
RUN ./ultiboinstaller-docker.sh
