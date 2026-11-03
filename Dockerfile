FROM debian:bookworm-slim

ARG EPRINTS_VERSION=v3.4.7
ENV DEBIAN_FRONTEND=noninteractive \
    EPRINTS_HOME=/opt/eprints3

RUN apt-get update && apt-get install -y --no-install-recommends \
      apache2 libapache2-mod-perl2 \
      perl libdbd-mysql-perl libdbi-perl libxml-libxml-perl libxml-libxslt-perl \
      libxml-parser-perl libxml-dom-perl libxml-namespacesupport-perl libxml-sax-base-perl \
      libtext-unidecode-perl libmime-lite-perl libterm-readkey-perl libjson-perl \
      libcgi-pm-perl libdigest-sha-perl libio-string-perl libtex-encode-perl \
      libfile-bom-perl libfile-slurp-perl libyaml-tiny-perl libconfig-general-perl \
      libuniversal-require-perl libwww-perl liblwp-protocol-https-perl libtime-hires-perl \
      libbibtex-parser-perl libarchive-zip-perl libtext-wrapper-perl \
      libsearch-xapian-perl \
      git autoconf automake make ca-certificates curl \
      wget unzip gzip tar ghostscript imagemagick poppler-utils antiword elinks \
      mariadb-client netcat-openbsd \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d $EPRINTS_HOME -s /bin/bash eprints \
 && usermod -a -G eprints www-data

RUN git clone --depth 1 --branch ${EPRINTS_VERSION} https://github.com/eprints/eprints3.4.git /usr/src/eprints \
 && cd /usr/src/eprints \
 && autoreconf -fi \
 && ./configure --prefix=$EPRINTS_HOME --with-user=eprints --with-group=eprints \
 && perl install.pl \
 && rm -rf /usr/src/eprints/.git

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80
VOLUME ["/opt/eprints3/archives"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
