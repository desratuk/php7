#!/bin/bash
# Isolated Ubuntu 20.04 amd64 build of Surý's already-patched PHP 7.2 source.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
. /etc/os-release
[ "$ID:$VERSION_ID:$(dpkg --print-architecture)" = ubuntu:20.04:amd64 ]
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
apt-get update
apt-get install -y --no-install-recommends build-essential devscripts equivs dpkg-dev ca-certificates
mkdir -p /build /out
cd /sources
sha256sum -c /repo/sources72.sha256
dpkg-source --no-check -x ./*.dsc /build/php
cd /build/php
# Keep security changes from revision 66 intact. Guard optional telemetry exactly
# as upstream's 7.4 builder does for Focal's older libsodium.
sed -i 's/#include "secure_dns_telemetry.h"/#ifdef TELEMETRY_HOST\n#include "secure_dns_telemetry.h"\n#endif/' sapi/apache2handler/php_functions.c sapi/fpm/fpm/fpm_main.c
sed -i 's/php-common (>= 1:81~)/php-common (>= 1:35)/g' debian/control debian/control.in debian/php-module.control.in
# Surý's template carries PHP version placeholders that configure does not expand.
# Resolve them before generating the packaged FPM master config.
sed -i -e 's/@PHP_MAJOR_VERSION@/7/g' -e 's/@PHP_MINOR_VERSION@/2/g' \
  -e 's|^;pid = .*|pid = /run/php/php7.2-fpm.pid|' sapi/fpm/php-fpm.conf.in
export DEBFULLNAME='TLB PHP backport contributors' DEBEMAIL='noreply@github.com'
dch --newversion '7.2.34-66+tlb1~ubuntu20.04.1' --distribution focal \
  'Experimental Focal rebuild of Sury revision 66; retains CVE-2026-109618/109619 fixes; resolves FPM config placeholders.'
export DEB_BUILD_OPTIONS="nocheck parallel=${JOBS:-4}"
export DEB_BUILD_PROFILES=nocheck
mk-build-deps --install --remove --tool 'apt-get -y --no-install-recommends' debian/control
dpkg-buildpackage -us -uc -b -j"${JOBS:-4}"
cp /build/*.deb /out/
find /build -maxdepth 1 -type f \( -name '*.buildinfo' -o -name '*.changes' \) -exec cp {} /out/ \;
dpkg-query -W -f='${binary:Package}\t${Version}\n' > /out/build-dependencies.txt
cp debian/patches/0159-Avoid-state-corruption-via-bailout.patch /out/
cd /out
sha256sum ./*.deb > SHA256SUMS
