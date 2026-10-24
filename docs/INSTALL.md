# Installing the experimental PHP 7.2 candidate

**Use at your own risk.** Read the [testing limits](TESTING.md) first. This is
minimally tested on Ubuntu **20.04 amd64**, including one copy of our own Symfony
application. It is not a maintained security-support service or a guarantee
that your application/extensions will work. This public procedure is not validation of a particular live installation.

This procedure is for existing **CLI/FPM PHP 7.2 core packages** on Focal amd64.
It does not cover Apache/mod_php, other SAPIs, PECL/custom extensions, other OSes
or architectures. Do not install Ubuntu 22.04 or Debian binary packages on Focal.

## 1. Obtain and check a candidate

There is no PHP 7.2 GitHub Release or signed APT repository. Build from this
checkout as described in the [README](../README.md), or download the
`experimental-php72-focal-amd64` ZIP from a specific
[PHP 7.2 Actions run](https://github.com/desratuk/php7/actions/workflows/php72-focal.yml).
GitHub sign-in may be required; artifacts expire. Record its commit/run ID and
compare the archive SHA256 with that run's published artifact digest. Then
extract it into a dedicated directory and review the build/test result files.
Do not treat a green workflow alone as proof of passing tests.

Historical generic validation results are summarized in [TESTING.md](TESTING.md).
A fresh source snapshot does not attest that every newly generated binary has
passed those tests. Select a reviewed workflow run, verify its source manifests
and artifact digest, then confirm its individual test logs/results. Do not infer
success from a green badge alone or mix packages from different builds.

On the target clone, start **Bash** and change into the extracted artifact
folder containing `.deb` files and `SHA256SUMS`:

```bash
set -euo pipefail
. /etc/os-release
[ "$ID:$VERSION_ID:$(dpkg --print-architecture)" = ubuntu:20.04:amd64 ]
sha256sum -c SHA256SUMS
```

Hashes establish integrity relative to the supplied manifest, not independent
publisher authentication. Review the source/build provenance as well.

## 2. Snapshot and baseline first

Test on a disposable clone before considering a live system. Take a restorable
server snapshot and application/database backups. Have console/recovery access
and the previous package set available; a config backup alone cannot roll back
binaries. APT package scripts may restart FPM during installation, so plan a
maintenance window even though an explicit restart appears later in this guide.

```bash
backup="/var/backups/php72-$(date -u +%Y%m%dT%H%M%SZ)"
sudo mkdir -m 700 "$backup"
sudo cp -a /etc/php/7.2 "$backup/php72"
dpkg-query -W -f='${binary:Package}\t${Version}\t${db:Status-Abbrev}\n' \
  | sudo tee "$backup/packages.before" >/dev/null
php7.2 -m | sudo tee "$backup/cli-modules.before" >/dev/null
php-fpm7.2 -m | sudo tee "$backup/fpm-modules.before" >/dev/null
sudo php-fpm7.2 -t
systemctl show php7.2-fpm -p MainPID -p ExecMainStartTimestamp -p ActiveState \
  | sudo tee "$backup/fpm.before" >/dev/null
```

Check separately for PECL/custom modules, other installed PHP versions and
application/background-worker dependencies. Our tests do not establish their
compatibility. Keep the backup private; it contains application/service configs.

## 3. Select only installed core packages and simulate

Run in the same Bash session/artifact directory. This selects the tested package
family without installing unused SAPIs or blindly installing every `.deb`.

```bash
target='7.2.34-66+tlb1~ubuntu20.04.1'
core=(bcmath cli common curl dev fpm gd gmp imap intl json mbstring mysql \
      opcache pgsql readline soap sqlite3 xml zip)
debs=()
for name in "${core[@]}"; do
  package="php7.2-$name"
  status=$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)
  [ "$status" = installed ] || continue
  matches=(./"${package}"_*.deb)
  [ "${#matches[@]}" = 1 ] && [ -f "${matches[0]}" ]
  [ "$(dpkg-deb -f "${matches[0]}" Package)" = "$package" ]
  [ "$(dpkg-deb -f "${matches[0]}" Version)" = "$target" ]
  [ "$(dpkg-deb -f "${matches[0]}" Architecture)" = amd64 ]
  current=$(dpkg-query -W -f='${Version}' "$package")
  dpkg --compare-versions "$target" gt "$current"
  debs+=("${matches[0]}")
done
[ "${#debs[@]}" -gt 0 ]
printf '%s\n' "${debs[@]}"
sudo apt-get -s --no-remove install "${debs[@]}"
```

Stop on a failed check, a downgrade, removals, unrelated upgrades or unresolved
PHP package dependencies. Our revision 34/36 simulations upgraded 20 core packages
and added Focal `libzip5`, retaining `libzip4`, with zero removals. Your installed
set can differ. Review installed `php7.2*` packages omitted from this core list;
leaving a PECL package untouched does not prove its binary module still works.
Do not change APT repositories, run a distribution upgrade or autoremove packages
as part of this procedure.

## 4. Install, compare and restart

Only after the simulation is acceptable:

```bash
sudo env UCF_FORCE_CONFFOLD=1 apt-get --no-remove \
  -o Dpkg::Options::=--force-confold install "${debs[@]}"
sudo diff -qr --no-dereference "$backup/php72" /etc/php/7.2
php7.2 -m | sudo tee "$backup/cli-modules.after" >/dev/null
php-fpm7.2 -m | sudo tee "$backup/fpm-modules.after" >/dev/null
sudo diff -u "$backup/cli-modules.before" "$backup/cli-modules.after"
sudo diff -u "$backup/fpm-modules.before" "$backup/fpm-modules.after"
```

`diff` returns nonzero when it finds differences; investigate before continuing.
The preservation flags are not a guarantee that package scripts leave every
file unchanged. Compare any change against this server's backup, restore the
original file where appropriate and recheck. In particular verify the master
config still has `pid = /run/php/php7.2-fpm.pid` and contains no unresolved
`@PHP_MAJOR_VERSION@`/`@PHP_MINOR_VERSION@` placeholders. This build fixes the
known template problem, but the post-install check remains mandatory.

```bash
sudo php-fpm7.2 -t
php7.2 -v
php-fpm7.2 -v
dpkg-query -W -f='${binary:Package}\t${Version}\n' 'php7.2*'
sudo systemctl restart php7.2-fpm
systemctl status php7.2-fpm --no-pager
systemctl show php7.2-fpm -p MainPID -p ExecMainStartTimestamp -p ActiveState
```

Both version commands should report **`7.2.34-66+tlb1~ubuntu20.04.1`**. Plain
`php -v` follows the system default and may select a different PHP branch.
Confirm selected packages have that revision, omitted packages stayed at their
recorded versions, the PID/start time changed and FPM is active without errors.
Our containers verify direct FPM startup, not this systemd restart procedure.
Restart any separately identified long-running PHP 7.2 workers in your own
reviewed maintenance procedure.

Finally test the actual web/FPM runtime, login/session persistence, uploads,
critical application workflows and error logs. A CLI version or homepage 200
alone is insufficient. If verification fails, stop the installation and use the
prepared snapshot/previous-package recovery plan; do not improvise a broad
package purge or distribution change. Our application testing did not submit
forms, save content, send mail or call recruitment integrations.
