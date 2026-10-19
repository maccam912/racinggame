FROM ubuntu:22.04@sha256:0a9887931b0e38af2e3487ed39e29436b0535c4f3f52e57745baaf79d1898956
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates libstdc++6 libsecret-1-0 libfontconfig1 libfreetype6 \
    libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libasound2 libpulse0 tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 pacific \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin pacific \
    && install -d -o 10001 -g 10001 -m 0700 /var/lib/pacific-rush /var/log/pacific-rush
COPY bundle/ /opt/pacific-rush/
COPY host.sh /opt/pacific-rush/host.sh
RUN chmod 0755 /opt/pacific-rush/host.sh /opt/pacific-rush/pacific-directory /opt/pacific-rush/pacific-rush-server.x86_64 \
    && ldd /opt/pacific-rush/pacific-rush-server.x86_64 \
    && ldd /opt/pacific-rush/libpacific_platform.linux.template_release.x86_64.so \
    && dpkg-query -W > /opt/pacific-rush/runtime-packages.txt
WORKDIR /opt/pacific-rush
ENV XDG_DATA_HOME=/var/lib/pacific-rush/game-data \
    XDG_CONFIG_HOME=/var/lib/pacific-rush/game-config \
    PR_HEALTH_LISTEN=127.0.0.1:8080
USER 10001:10001
EXPOSE 8080/tcp 27020-27027/udp
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=10s --timeout=4s --start-period=20s --retries=3 \
    CMD /opt/pacific-rush/pacific-directory probe --listen "$PR_HEALTH_LISTEN"
ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/opt/pacific-rush/host.sh"]
CMD ["version"]
