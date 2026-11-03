#!/bin/bash
set -euo pipefail

EP=/opt/eprints3
ID="${EPRINTS_ARCHIVE_ID:-kariadi}"
HOST="${EPRINTS_HOST:-localhost}"
PORT="${EPRINTS_PORT:-8080}"
ARCHIVE_NAME="${EPRINTS_ARCHIVE_NAME:-Repository EPrints}"
ORG_NAME="${EPRINTS_ORG_NAME:-Kariadi}"
ADMIN_EMAIL="${EPRINTS_ADMIN_EMAIL:-admin@localhost}"
DB_HOST="${DB_HOST:-db}"
DB_NAME="${DB_NAME:-eprints}"
DB_USER="${DB_USER:-eprints}"
DB_PASS="${DB_PASS:-eprints}"
ADMIN_USER="${EPRINTS_ADMIN_USER:-admin}"
ADMIN_PASS="${EPRINTS_ADMIN_PASS:-admin12345}"

as_ep() { su eprints -c "cd $EP && $*"; }

chown eprints:eprints $EP/archives
echo "Menunggu database $DB_HOST ..."
until mysqladmin ping -h "$DB_HOST" -u"$DB_USER" -p"$DB_PASS" --silent 2>/dev/null; do sleep 2; done

if [ ! -d "$EP/archives/$ID/cfg" ]; then
  echo ">> Inisialisasi archive '$ID' (pertama kali)"
  R=$EP/archives/$ID
  as_ep "mkdir -p $R/cfg $R/cgi $R/var $R/html $R/documents/disk0"
  as_ep "cp -a $EP/flavours/pub_lib/defaultcfg/. $R/cfg/"
  as_ep "mkdir -p $R/cfg/cfg.d $R/cfg/lang/en/phrases"
  cat > $R/cfg/cfg.d/00_flavour.pl <<EOP
\$c->{flavour} = 'pub';
EOP
  cat > $R/cfg/cfg.d/10_core.pl <<EOP
\$c->{host} = '$HOST';
\$c->{port} = '$PORT';
\$c->{aliases} = [];
\$c->{securehost} = '';
\$c->{secureport} = 443;
\$c->{http_root} = undef;
EOP
  cat > $R/cfg/cfg.d/adminemail.pl <<EOP
\$c->{adminemail} = '$ADMIN_EMAIL';
EOP
  cat > $R/cfg/cfg.d/database.pl <<EOP
\$c->{dbname} = '$DB_NAME';
\$c->{dbhost} = '$DB_HOST';
\$c->{dbport} = undef;
\$c->{dbsock} = undef;
\$c->{dbuser} = '$DB_USER';
\$c->{dbpass} = '$DB_PASS';
\$c->{dbengine} = 'InnoDB';
EOP
  cat > $R/cfg/lang/en/phrases/archive_name.xml <<EOP
<?xml version="1.0" encoding="iso-8859-1" standalone="no" ?>
<!DOCTYPE phrases SYSTEM "entities.dtd">
<epp:phrases xmlns="http://www.w3.org/1999/xhtml" xmlns:epp="http://eprints.org/ep3/phrase">
	<epp:phrase id="archive_name">$ARCHIVE_NAME</epp:phrase>
	<epp:phrase id="organisation_name">$ORG_NAME</epp:phrase>
</epp:phrases>
EOP
  chown -R eprints:eprints $R
  as_ep "bin/epadmin create_tables $ID"
  as_ep "bin/epadmin create_user $ID '$ADMIN_USER' admin '$ADMIN_PASS' '$ADMIN_EMAIL'"
  as_ep "bin/import_subjects --verbose --force $ID"
  as_ep "bin/generate_static $ID"
  as_ep "bin/generate_apacheconf --system --replace" || as_ep "bin/generate_apacheconf --replace"
  as_ep "bin/generate_views $ID" || true
fi

# Selalu regenerate config apache (host/port bisa berubah)
as_ep "bin/generate_apacheconf --replace" || true

echo "Include $EP/cfg/apache.conf" > /etc/apache2/conf-enabled/eprints.conf
a2enmod perl >/dev/null 2>&1 || true
sed -i "s/^Listen .*/Listen $PORT/" /etc/apache2/ports.conf
sed -i "/Listen 443/d" /etc/apache2/ports.conf
sed -i 's/^User .*//; s/^Group .*//' /etc/apache2/apache2.conf
echo "User eprints
Group eprints" >> /etc/apache2/apache2.conf

(cd $EP && bin/epindexer start) || true
trap '(cd $EP && bin/epindexer stop) || true' EXIT

set +u
source /etc/apache2/envvars
exec apache2 -DFOREGROUND
