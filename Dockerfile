FROM library/alpine:3.7
LABEL maintainer="Gerardo Junior <me@gerardo-junior.com>"

# Get installation variables
ARG PHP_VERSION=7.2.5
ARG PHP_VERSION_SHA256=af70a33b3f7a51510467199b39af151333fbbe4cc21923bad9c7cf64268cddb2

ARG HTTPD_VERSION=2.4.33
ARG HTTPD_VERSION_SHA256=de02511859b00d17845b9abdd1f975d5ccb5d0b280c567da5bf2ad4b70846f05

ARG PHP_MONGO_VERSION=1.4.3
ARG PHP_MONGO_VERSION_SHA256=633485d2dd3f608143d0716f7ebf352a32d94b16eb7947a2bb851b29bad3e912

ARG PHALCON_VERSION=3.3.2
ARG PHALCON_VERSION_SHA256=823fd693a7e9e8999edfd405970a81b7bf731fa28109a64774216fc5f68d2975

ARG DEBUG=false
ARG XDEBUG_VERSION=2.6.0
ARG XDEBUG_VERSION_SHA256=b5264cc03bf68fcbb04b97229f96dca505d7b87ec2fb3bd4249896783d29cbdc


ENV COMPILE_DEPS .build-deps \
                 dpkg-dev dpkg \
                 autoconf \
                 file \
                 g++ \
                 gcc \
                 libc-dev \
                 make \
                 pkgconf \
                 re2c \
                 lua-dev \
                 libxml2-dev \
                 lua-dev \
                 nghttp2-dev \
                 pcre-dev \
                 zlib-dev \
                libxml2-dev \
                libressl-dev \
                curl-dev \
                libedit-dev \
                libsodium-dev \
                apr-dev \
                apr-util-dev \
                apr-util-ldap \
                perl

# Install compile deps
RUN apk add --no-cache --virtual ${COMPILE_DEPS}

# Install run deps
RUN apk --update add --virtual .persistent-deps \
                               curl \
                               tar \
                               xz \
                               libressl 

RUN cd /tmp

# Create project directory
RUN mkdir -p /usr/share/src

# Compile and install apache
ENV HTTPD_SOURCE_URL https://www.apache.org/dist/httpd
RUN set -xe && \
    curl -L -o httpd-${HTTPD_VERSION}.tar.bz2 ${HTTPD_SOURCE_URL}/httpd-${HTTPD_VERSION}.tar.bz2 && \
    if [ -n "$HTTPD_VERSION_SHA256" ]; then \
		echo "${HTTPD_VERSION_SHA256}  httpd-${HTTPD_VERSION}.tar.bz2" | sha256sum -c - \
	; fi && \
    tar -xf httpd-${HTTPD_VERSION}.tar.bz2 && \
    cd httpd-${HTTPD_VERSION} && \
    sh ./configure --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
                   --prefix="/usr/local/apache2" \
                   --enable-mods-shared=reallyall \
                   --enable-mpms-shared=all \
                   --enable-so \
                   --enable-ssl	\
                   --enable-rewrite \
                   --htmldir="/usr/share/src" && \
    make -j "$(nproc)" && \
    make install && \
    cd ../ && \
	runDeps="$runDeps $( scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
                       | tr ',' '\n' \
                       | sort -u \
                       | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' )" && \
    apk add --virtual .httpd-rundeps $runDeps && \
    unset HTTPD_SOURCE_URL


# Compile and install php
ENV PHP_SOURCE_URL https://secure.php.net/get
RUN set -xe && \
    curl -L -o php-${PHP_VERSION}.tar.xz ${PHP_SOURCE_URL}/php-${PHP_VERSION}.tar.xz/from/this/mirror && \
    if [ -n "$PHP_VERSION_SHA256" ]; then \
		echo "${PHP_VERSION_SHA256}  php-${PHP_VERSION}.tar.xz" | sha256sum -c - \
	; fi && \
    tar -Jxf php-${PHP_VERSION}.tar.xz && \
    cd php-${PHP_VERSION} && \
    mkdir -p /usr/local/etc/php/conf.d && \
    export CFLAGS="-fstack-protector-strong -fpic -fpie -O2" && \
	export CPPFLAGS=$CFLAGS && \
    export LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" && \ 
    sh ./configure --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
                   --with-apxs2="/usr/local/apache2/bin/apxs" \
                   --with-config-file-path="/usr/local/etc/php" \
                   --with-config-file-scan-dir="/usr/local/etc/php/conf.d" \
                   --enable-cgi \
                   --enable-ftp \
                   --enable-mbstring \
                   --with-sodium=shared \
                   --with-curl \
                   --with-libedit \
                   --with-openssl \
                   --with-zlib \
                   $(test "$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" = 's390x-linux-gnu' && echo '--without-pcre-jit') && \
	make -j "$(nproc)" && \
	make install && \
	find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true && \
    make clean && \
    mv php.ini-development /usr/local/etc/php/php.ini && \
    cd .. && \
    runDeps="$( scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
                | tr ',' '\n' \
                | sort -u \
                | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' )" && \
	apk add --no-cache --virtual .php-rundeps $runDeps && \
	pecl update-channels && \ 
    rm -rf /tmp/pear ~/.pearrc && \
    unset PHP_SOURCE_URL \
          CFLAGS \
          CPPFLAGS \
          LDFLAGS
COPY httpd.conf /usr/local/apache2/conf/httpd.conf

# Compile and install mongodb php driver
ENV PHP_MONGO_SOURCE_URL https://github.com/mongodb/mongo-php-driver/releases/download
RUN set -xe && \
    curl -L -o php-mongodb-${PHP_MONGO_VERSION}.tgz ${PHP_MONGO_SOURCE_URL}/${PHP_MONGO_VERSION}/mongodb-${PHP_MONGO_VERSION}.tgz && \
    if [ -n "PHP_MONGO_VERSION_SHA256" ]; then \
		echo "${PHP_MONGO_VERSION_SHA256}  php-mongodb-${PHP_MONGO_VERSION}.tgz" | sha256sum -c - \
	; fi && \
    tar -xzf php-mongodb-${PHP_MONGO_VERSION}.tgz && \
    cd mongodb-${PHP_MONGO_VERSION} && \
    phpize && \
    sh ./configure && \
    make all && \
    make install && \
    cd ../ && \
    echo -e "[mongodb] \n" \
            "extension = $(find /usr/local/lib/php/extensions/ -name mongodb.so)" > /usr/local/etc/php/conf.d/mongodb.ini && \
    unset PHP_MONGO_SOURCE_URL

# Compile and install phalcon php extension
ENV PHALCON_SOURCE_URL https://github.com/phalcon/cphalcon/archive
RUN set -xe && \
    curl -L -o phalcon-${PHALCON_VERSION}.tar.gz ${PHALCON_SOURCE_URL}/v${PHALCON_VERSION}.tar.gz && \
    if [ -n "PHALCON_VERSION_SHA256" ]; then \
		echo "${PHALCON_VERSION_SHA256}  phalcon-${PHALCON_VERSION}.tar.gz" | sha256sum -c - \
	; fi && \
    tar -xzf phalcon-${PHALCON_VERSION}.tar.gz && \
    cd ./cphalcon-${PHALCON_VERSION}/build/ && \
    sh ./install --phpize /usr/local/bin/phpize \
                 --php-config /usr/local/bin/php-config && \
    cd ../../ && \
    echo -e "[phalcon] \n" \
            "extension = $(find /usr/local/lib/php/extensions/ -name phalcon.so)" > /usr/local/etc/php/conf.d/phalcon.ini && \
    unset PHALCON_SOURCE_URL

# Compile, install and configure XDebug php extension
ENV XDEBUG_SOURCE_URL https://xdebug.org/files
ENV XDEBUG_CONFIG_HOST 0.0.0.0
ENV XDEBUG_CONFIG_PORT 9000
ENV XDEBUG_CONFIG_IDEKEY "IDEA_XDEBUG"
RUN if [ "$DEBUG" = "true" ] ; then \
        set -xe && \
        curl -L -o xdebug-${XDEBUG_VERSION}.tgz ${XDEBUG_SOURCE_URL}/xdebug-${XDEBUG_VERSION}.tgz && \
        if [ -n "XDEBUG_VERSION_SHA256" ]; then \
		    echo "${XDEBUG_VERSION_SHA256}  xdebug-${XDEBUG_VERSION}.tgz" | sha256sum -c - \
	    ; fi && \
        tar -xzf xdebug-${XDEBUG_VERSION}.tgz && \
        cd ./xdebug-${XDEBUG_VERSION} && \
        phpize && \
        sh ./configure --enable-xdebug && \
        make && \
        make install && \
        make clean && \
        cd ../ && \
        echo -e "[XDebug] \n" \
                "zend_extension = $(find /usr/local/lib/php/extensions/ -name xdebug.so) \n" \
                "xdebug.remote_enable = on \n" \
                "xdebug.remote_host = ${XDEBUG_CONFIG_HOST} \n" \
                "xdebug.remote_port = ${XDEBUG_CONFIG_PORT} \n" \
                "xdebug.remote_handler = \"dbgp\" \n" \
                "xdebug.remote_connect_back = off \n" \
                "xdebug.cli_color = on \n" \
                "xdebug.idekey = \"${XDEBUG_CONFIG_IDEKEY}\"" > /usr/local/etc/php/conf.d/xdebug.ini \
    ; fi && \
    unset XDEBUG_SOURCE_URL \ 
          XDEBUG_CONFIG_HOST \
          XDEBUG_CONFIG_PORT \
          XDEBUG_CONFIG_IDEKEY


# Cleanup system
RUN apk del ${COMPLIE_DEPS} .build-deps && \
    rm -Rf /var/cache/apk/* /tmp/* && \
    unset COMPLIE_DEPS \
          PHP_VERSION \
          PHP_VERSION_SHA256 \
          HTTPD_VERSION \
          HTTPD_VERSION_SHA256 \
          PHP_MONGO_VERSION \
          PHP_MONGO_VERSION_SHA256 \
          PHALCON_VERSION \
          PHALCON_VERSION_SHA256 \
          DEBUG \
          XDEBUG_VERSION \
          XDEBUG_VERSION_SHA256

# Copy scripts
COPY ./tools/start.sh /usr/local/bin/start.sh
COPY ./tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/start.sh

# Set project directory
VOLUME ["/usr/share/src"]
WORKDIR /usr/share/src
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EXPOSE 80