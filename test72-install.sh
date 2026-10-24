#!/bin/bash
# Runs only inside the disposable Focal build/test container.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends python3
core=(bcmath cli common curl dev fpm gd gmp imap intl json mbstring mysql opcache pgsql readline soap sqlite3 xml zip)
debs=()
for name in "${core[@]}"; do
  matches=(/out/php7.2-"$name"_*.deb)
  [ "${#matches[@]}" = 1 ] && [ -f "${matches[0]}" ]
  debs+=("${matches[0]}")
done
apt-get -s install "${debs[@]}" > /out/php72-install-simulation.txt
apt-get install -y --no-remove "${debs[@]}"
php7.2 -v
php7.2 -m | tee /out/php72-modules.txt
php7.2 -r '$required = array("bcmath", "curl", "gd", "gmp", "imap", "intl", "json", "mbstring", "mysqli", "pdo_mysql", "Zend OPcache", "pgsql", "readline", "soap", "sqlite3", "xml", "zip"); foreach ($required as $name) { if (!extension_loaded($name)) { fwrite(STDERR, "Missing module: ".$name."\n"); exit(1); } }'
[ "$(php-config7.2 --phpapi)" = 20170718 ]
php-fpm7.2 -t
! grep -E '@PHP_(MAJOR|MINOR)_VERSION@' /etc/php/7.2/fpm/php-fpm.conf
grep -Fx 'pid = /run/php/php7.2-fpm.pid' /etc/php/7.2/fpm/php-fpm.conf
# Prove a locally customized master config survives reinstallation.
printf '\n; TLB isolated preservation probe\n' >> /etc/php/7.2/fpm/php-fpm.conf
before=$(sha256sum /etc/php/7.2/fpm/php-fpm.conf)
UCF_FORCE_CONFFOLD=1 apt-get install -y --reinstall --no-remove \
  -o Dpkg::Options::=--force-confold "${debs[@]}"
[ "$before" = "$(sha256sum /etc/php/7.2/fpm/php-fpm.conf)" ]
php-fpm7.2 -t
python3 /repo/tests/fpm72.py | tee /out/php72-fpm-tests.json
printf 'Clean package install, config placeholder and reinstall-preservation checks passed.\n' > /out/php72-install-result.txt
