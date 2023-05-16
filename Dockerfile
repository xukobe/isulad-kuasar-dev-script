FROM openeuler/openeuler
MAINTAINER "OpenEuler Maintainers"
RUN dnf install -y dnf-plugins-core

#################### iSulad Dependency ####################
# basic depends of build
RUN dnf install -y cmake gcc-c++ make libtool chrpath autoconf automake m4 pkgconfig wget

# depends for version control
RUN dnf install -y diffutils patch git

# depends for ut of iSulad: -DENABLE_UT=ON
RUN dnf install -y gtest-devel gmock-devel

# depends for metrics of iSulad and restful connection: -DENABLE_METRICS=ON or -DENABLE_GRPC=OFF
RUN dnf install -y libevent-devel libevhtp-devel

# depends for grpc of iSulad: -DENABLE_GRPC=ON
RUN dnf install -y grpc grpc-plugins grpc-devel protobuf-devel libwebsockets libwebsockets-devel

# depends for image module and restful client of iSulad
RUN dnf install -y libcurl libcurl-devel libarchive-devel http-parser-devel

# depneds for security of iSulad
RUN dnf install -y libseccomp-devel libcap-devel libselinux-devel

# depends for json parse
RUN dnf install -y yajl-devel

# depends for device-mapper image storage of iSulad
RUN dnf install -y device-mapper-devel

# depends for embedded image of iSulad: -DENABLE_EMBEDDED=ON
RUN dnf install -y sqlite-devel

# depends for systemd notify of iSulad: -DENABLE_SYSTEMD_NOTIFY=ON
RUN dnf install -y systemd-devel systemd

# dependency for run isulad
RUN dnf install -y glibc-all-langpacks dbus udev

# dependency for development
RUN dnf install -y gdb

########################################################

#################### Kuasar Dependency ####################
# Install qemu
RUN dnf install -y qemu

# Install Rust
WORKDIR /home/openeuler
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
########################################################

#################### Env setup ####################
# Add PKG_CONFIG_PATH and LD_LIBRARY_PATH
RUN echo "export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH" >> /root/.bashrc
RUN echo "export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:$LD_LIBRARY_PATH" >> /root/.bashrc
RUN echo "/usr/local/lib" >> /etc/ld.so.conf
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/lib
########################################################

#################### Build from source ####################
# Build lxc
WORKDIR /home/openeuler
RUN git clone https://gitee.com/src-openeuler/lxc.git
WORKDIR /home/openeuler/lxc
RUN rm -rf lxc-4.0.3
RUN git config --global --add safe.directory /home/openeuler/lxc/lxc-4.0.3
RUN ./apply-patches
WORKDIR /home/openeuler/lxc/lxc-4.0.3
RUN ./autogen.sh && ./configure --disable-werror
RUN make -j $(nproc)
RUN make install
WORKDIR /home/openeuler
RUN rm -rf lxc

# Build lcr
WORKDIR /home/openeuler
RUN git clone -b dev-sandbox https://gitee.com/openeuler/lcr.git
WORKDIR /home/openeuler/lcr/build
RUN cmake ..
RUN make -j $(nproc)
RUN make install
WORKDIR /home/openeuler
RUN rm -rf lcr

# Build clibcni
WORKDIR /home/openeuler
RUN git clone https://gitee.com/openeuler/clibcni.git
WORKDIR /home/openeuler/clibcni/build
RUN cmake ..
RUN make -j $(nproc)
RUN make install
WORKDIR /home/openeuler
RUN rm -rf clibcni

# Build lib-shim-v2
WORKDIR /home/openeuler
RUN git clone https://gitee.com/openeuler/lib-shim-v2.git
WORKDIR /home/openeuler/lib-shim-v2
RUN make
RUN make install
WORKDIR /home/openeuler
RUN rm -rf lib-shim-v2

# Build iSulad
WORKDIR /home/openeuler
RUN git clone -b dev-sandbox https://gitee.com/openeuler/iSulad.git
WORKDIR /home/openeuler/iSulad/build
RUN cmake .. -D ENABLE_SANDBOX=ON -D ENABLE_SHIM_V2=ON && make -j 4
RUN make install
WORKDIR /home/openeuler
RUN rm -rf iSulad
# Update daemon.json
COPY data/daemon.json /etc/isulad/daemon.json

# Build kuasar with qemu support
WORKDIR /home/openeuler
RUN git clone https://github.com/kuasar-io/kuasar.git
WORKDIR /home/openeuler/kuasar/vmm/sandbox
RUN cargo build --release --features=qemu
RUN cp -f /home/openeuler/kuasar/vmm/sandbox/target/release/vmm-sandboxer /usr/local/bin/vmm-sandboxer
WORKDIR /home/openeuler
RUN rm -rf kuasar
########################################################

# Install kuasar
RUN mkdir -p /var/lib/kuasar
COPY images/kernel /var/lib/kuasar/kernel
COPY images/kuasar.initrd /var/lib/kuasar/kuasar.initrd
RUN mkdir -p /usr/share/defaults/kata-containers
COPY data/configuration.toml /usr/share/defaults/kata-containers/configuration.toml

# Install crictl tool
WORKDIR /home/openeuler
RUN wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.22.0/crictl-v1.22.0-linux-amd64.tar.gz
RUN tar -xvf crictl-v1.22.0-linux-amd64.tar.gz
RUN mv crictl /usr/local/bin
COPY data/crictl.yaml /etc/crictl.yaml
RUN rm -f crictl-v1.22.0-linux-amd64.tar.gz

# Install socat
WORKDIR /home/openeuler
RUN wget http://www.dest-unreach.org/socat/download/socat-1.7.4.4.tar.gz
RUN tar -xvf socat-1.7.4.4.tar.gz
WORKDIR /home/openeuler/socat-1.7.4.4
RUN ./configure && make && make install
WORKDIR /home/openeuler
RUN rm -rf socat-1.7.4.4 socat-1.7.4.4.tar.gz

# Install some scripts as shortcuts
COPY data/start-sandboxer /usr/local/bin
COPY data/kill-sandboxer /usr/local/bin
RUN chmod a+x /usr/local/bin/start-sandboxer
RUN chmod a+x /usr/local/bin/kill-sandboxer

WORKDIR /workspace

ENTRYPOINT [ "/usr/sbin/init" ]
