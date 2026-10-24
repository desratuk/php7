#!/bin/bash
# Disposable Focal container only: /old and /candidate are read-only package sets.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
. /etc/os-release
[ "$ID:$VERSION_ID:$(dpkg --print-architecture)" = ubuntu:20.04:amd64 ]
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
apt-get update
apt-get install -y --no-install-recommends python3 ca-certificates
(cd /old && sha256sum -c SHA256SUMS)
(cd /candidate && sha256sum -c SHA256SUMS)
old=(/old/*.deb)
apt-get install -y --no-remove "${old[@]}"
mkdir -p /run/php /out
# Synthetic, non-secret customizations exercise both conffiles and added files.
printf '\n; isolated upgrade preservation probe\n' >> /etc/php/7.2/fpm/php-fpm.conf
printf 'memory_limit=192M\ndate.timezone=Europe/London\n' > /etc/php/7.2/mods-available/upgrade-probe.ini
for sapi in cli fpm; do
  ln -sf /etc/php/7.2/mods-available/upgrade-probe.ini /etc/php/7.2/$sapi/conf.d/99-upgrade-probe.ini
done
printf '\n; preserve existing pool customization\n' >> /etc/php/7.2/fpm/pool.d/www.conf
snapshot() {
  python3 - "$1" <<'PY'
import hashlib,json,os,sys
from pathlib import Path
root=Path('/etc/php/7.2')
files={str(p):({'symlink':os.readlink(p)} if p.is_symlink() else {'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}) for p in sorted(root.rglob('*')) if p.is_symlink() or p.is_file()}
Path('/out/'+sys.argv[1]+'-configs.json').write_text(json.dumps(files,indent=2))
PY
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 'php*' > "/out/$1-packages.txt"
  php7.2 -m > "/out/$1-cli-modules.txt"
  php-fpm7.2 -m > "/out/$1-fpm-modules.txt"
}
php-fpm7.2 -t
snapshot before
new=()
for file in "${old[@]}"; do
  package=$(dpkg-deb -f "$file" Package)
  [[ "$package" == php7.2-* ]] || continue
  matches=(/candidate/"${package}"_*.deb)
  [ "${#matches[@]}" = 1 ] && [ -f "${matches[0]}" ]
  new+=("${matches[0]}")
done
apt-get -s install "${new[@]}" > /out/upgrade-simulation.txt
UCF_FORCE_CONFFOLD=1 apt-get install -y --no-remove -o Dpkg::Options::=--force-confold "${new[@]}"
snapshot after
python3 - <<'PY'
import json
from pathlib import Path
before=json.loads(Path('/out/before-configs.json').read_text())
after=json.loads(Path('/out/after-configs.json').read_text())
changed=[p for p,v in before.items() if after.get(p)!=v]
assert not changed, 'Original config changed: '+repr(changed)
for sapi in ('cli','fpm'):
 assert Path('/out/before-'+sapi+'-modules.txt').read_bytes()==Path('/out/after-'+sapi+'-modules.txt').read_bytes(),sapi+' modules changed'
old=dict(line.split('\t') for line in Path('/out/before-packages.txt').read_text().splitlines())
new=dict(line.split('\t') for line in Path('/out/after-packages.txt').read_text().splitlines())
for name,version in old.items():
 if not version: continue  # dpkg-query also lists uninstalled virtual packages.
 if name.startswith('php7.2-'):
  assert new[name]=='7.2.34-66+tlb1~ubuntu20.04.1',(name,new[name])
 else:
  assert new.get(name)==version,(name,'unrelated PHP package changed')
Path('/out/preservation.json').write_text(json.dumps({'original_config_files_and_symlinks':len(before),'config_preservation':'passed','cli_fpm_modules':'unchanged','core_package_upgrade':'passed','unrelated_php_packages':'unchanged'},indent=2))
PY
php-fpm7.2 -t
php-fpm7.2 -D
test -s /run/php/php7.2-fpm.pid
kill -0 "$(cat /run/php/php7.2-fpm.pid)"
kill -QUIT "$(cat /run/php/php7.2-fpm.pid)"
python3 /repo/tests/fpm72.py | tee /out/fpm-tests.json
printf 'Upgrade, configs, CLI/FPM modules, packaged FPM startup and request tests passed.\n' > /out/result.txt
