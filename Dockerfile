FROM alpine:latest

ARG BUILD_DATE
ENV USER=mysql
ENV UID=1002
ENV VERBOSE=0 

LABEL maintainer="Eugene Taylashev" \
    architecture="amd64/x86_64" \
    mariadb-version="10.5.8" \
    alpine-version="3.13.2" \
    build="2021-03-14" \
    org.opencontainers.image.title="alpine-mariadb" \
    org.opencontainers.image.description="Minimal MariaDB image based on Alpine Linux" \
    org.opencontainers.image.authors="Eugene Taylashev" \
    org.opencontainers.image.version="v10.5.8" \
    org.opencontainers.image.url="https://hub.docker.com/r/etaylashev/mariadb" \
    org.opencontainers.image.source="https://github.com/eugene-taylashev/docker-mariadb" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE

#-- Create a user for MariaDB
RUN set -eux; \
    addgroup --gid $UID "$USER"; \
    adduser \
      --disabled-password \
      --ingroup "$USER" \
      --no-create-home \
      --shell /sbin/nologin \
      --uid "$UID" \
      "$USER";

#-- Install main packages
RUN set -eux; \
    apk add --no-cache mariadb mariadb-client mariadb-server-utils pwgen; \
    rm -f /var/cache/apk/*

#-- Set timezone and locale
RUN set -eux; \
    apk add --no-cache tzdata musl-locales musl-locales-lang; \
    rm -f /var/cache/apk/*

ENV TZ America/Toronto
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN set -eux; \
    cp /usr/share/zoneinfo/America/Toronto /etc/localtime; \
    echo "America/Toronto" >  /etc/timezone; \
    apk del tzdata;

COPY ./entrypoint.sh /

EXPOSE 3306
STOPSIGNAL SIGINT
VOLUME ["/etc/my.cnf.d","/var/lib/mysql"]

ENTRYPOINT ["/entrypoint.sh"]
