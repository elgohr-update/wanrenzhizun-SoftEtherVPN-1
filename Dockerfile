FROM alpine:3.14 as prep

ARG BUILD_VERSION=4.38-9760-rtm
ARG SHA256_SUM=00000000d
ENV BUILD_VERSION=${BUILD_VERSION} \
    SHA256_SUM=${SHA256_SUM}


RUN wget https://github.com/wanrenzhizun/SoftEtherVPN_Stable/archive/v${BUILD_VERSION}.tar.gz \
    && echo "${SHA256_SUM}  v${BUILD_VERSION}.tar.gz" | sha256sum -c \
    && mkdir -p /usr/local/src \
    && tar -x -C /usr/local/src/ -f v${BUILD_VERSION}.tar.gz \
    && rm v${BUILD_VERSION}.tar.gz

FROM centos:8 as build

COPY --from=prep /usr/local/src /usr/local/src

RUN yum -y update \
    && yum -y groupinstall "Development Tools" \
    && yum -y install ncurses-devel openssl-devel readline-devel \
    && cd /usr/local/src/SoftEtherVPN_Stable-* \
    && ./configure \
    && make \
    && make install \
    && touch /usr/vpnserver/vpn_server.config \
    && zip -r9 /artifacts.zip /usr/vpn* /usr/bin/vpn*

FROM centos:8

COPY --from=build /artifacts.zip /

COPY copyables /

RUN yum -y update \
    && yum -y install unzip iptables \
    && rm -rf /var/log/* /var/cache/yum/* /var/lib/yum/* \
    && chmod +x /entrypoint.sh /gencert.sh \
    && unzip -o /artifacts.zip -d / \
    && rm /artifacts.zip \
    && rm -rf /opt \
    && ln -s /usr/vpnserver /opt \
    && find /usr/bin/vpn* -type f ! -name vpnserver \
       -exec sh -c 'ln -s {} /opt/$(basename {})' \;

WORKDIR /usr/vpnserver/

VOLUME ["/usr/vpnserver/server_log/", "/usr/vpnserver/packet_log/", "/usr/vpnserver/security_log/"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 500/udp 4500/udp 1701/tcp 1194/udp 5555/tcp 443/tcp

CMD ["/usr/bin/vpnserver", "execsvc"]
