FROM alpine:latest

ARG BUILD_DATE
ENV USER=mysql
ENV PUID=1000
ENV PGID=1000
ENV TZ=America/Toronto
ENV MYSQL_ROOT_PASSWORD=""
ENV MYSQL_DATABASE=""
ENV MYSQL_USER=""
ENV MYSQL_PASSWORD=""
ENV MYSQL_CHARSET=""
ENV MYSQL_COLLATION=""
ENV MYSQL_REPLICA_FIRST=0
#ENV MYSQL_REPLICATION_USER=""
#ENV MYSQL_REPLICATION_PASSWORD=""
ENV VERBOSE=0 


LABEL maintainer="Eugene Taylashev" \
    mariadb-version="10.6.4" \
    alpine-version="3.15.0" \
    org.opencontainers.image.title="alpine-mariadb" \
    org.opencontainers.image.description="Minimal MariaDB image based on Alpine Linux" \
    org.opencontainers.image.authors="Eugene Taylashev" \
    org.opencontainers.image.version="v10.6.4" \
    org.opencontainers.image.url="https://hub.docker.com/r/etaylashev/mariadb" \
    org.opencontainers.image.source="https://github.com/eugene-taylashev/docker-mariadb" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE

#-- Create a user for MariaDB
RUN set -eux; \
    addgroup --gid $PGID "$USER"; \
    adduser \
      --disabled-password \
      --ingroup "$USER" \
      --no-create-home \
      --shell /sbin/nologin \
      --uid "$PUID" \
      "$USER";

#-- Install main packages
RUN set -eux; \
    apk add --no-cache mariadb mariadb-client \
        mariadb-server-utils pwgen shadow \
        socat rsync lsof bash; \
    rm -f /var/cache/apk/*

#-- Install replication packages from the edge repository
RUN set -eux; \
    apk add --no-cache galera \
        --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing; \
    rm -f /var/cache/apk/*

#-- Set timezone and locale
RUN set -eux; \
    apk add --no-cache tzdata musl-locales musl-locales-lang; \
    rm -f /var/cache/apk/*

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN set -eux; \
    cp /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo "$TZ" >  /etc/timezone;

COPY ./entrypoint.sh ./functions.sh /

EXPOSE 3306
STOPSIGNAL SIGINT
VOLUME ["/etc/my.cnf.d","/var/lib/mysql"]

ENTRYPOINT ["/entrypoint.sh"]
