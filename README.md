# Experimental PHP 7.2 backport for Ubuntu 20.04 amd64

This source snapshot derives from [Niek/php7](https://github.com/Niek/php7).
It rebuilds **PHP 7.2.34** with Surý's revision 66 security backports for
**Ubuntu 20.04 (Focal), amd64 only**. The PHP 7.2 and PHP 5.6 experiments remain
separate. Upstream attribution and the [MIT license](LICENSE) are retained;
see [source attribution](NOTICE.md).

> [!WARNING]
> **Use entirely at your own risk.** This PHP branch is end-of-life and Ubuntu
> 20.04 is outside standard maintenance. This is an experimental migration aid,
> not a maintained security-support service. Testing is limited; there is no
> guarantee of compatibility, complete security coverage or future updates.
> Keep backups/recovery access and migrate to supported PHP/OS versions.

Candidate: **`7.2.34-66+tlb1~ubuntu20.04.1`**.

## Build scope

Pinned Surý Ubuntu 22.04 **source** is rebuilt against native Focal libraries;
Jammy/Debian binaries are not substituted onto Focal. The retained source patches
include CVE-2026-109618/CVE-2026-109619 bailout fixes. Source sizes/hashes are
checked through `sources72.sha256` and the downloaded `.dsc` manifest;
independent GPG source-signature verification is not claimed.

`build72.sh` retains Surý's package layout, adjusts build dependencies/optional
telemetry headers for Focal and resolves FPM version/PID placeholders.
Separate PECL extensions are not bundled.

## Generic validation results

Historical tests of the retained build/test code on Focal amd64:

- Built and installed 20 core CLI/FPM/module packages.
- Config checks, customized-config preservation, direct FPM startup, local
  FastCGI/session/multipart requests, OOM termination without a user destructor
  and subsequent-worker recovery passed.
- Selected native amd64 upstream regression suite: **1,273 passed, zero unexpected
  failures, three existing expected failures and 409 existing skips** (1,685 total).
- Disposable upgrades from historical Surý Focal revisions 34 and 36 preserved
  133 synthetic configuration entries and CLI/FPM module lists in each test.
- One private Symfony-based application received limited read-only smoke
  testing on Focal amd64. This does not establish general application compatibility.

See [test scope and limitations](docs/TESTING.md). The public history/docs
cleanup did not rerun compilation or the regression suite; it does not constitute
new validation of a differently built binary. No application source/data or
operational deployment records are included here.

## Installation status

Read the [candidate installation and verification procedure](docs/INSTALL.md).
There is no PHP 7.2 GitHub Release, signed APT repository or automatic updater.
CI artifacts are experimental outputs; verify provenance, hashes and individual
results. Do not use the inherited PHP 7.4 installation commands for this build.

## Reproduce in isolation

With Bash and Docker available:

```bash
set -euo pipefail
bash download72.sh
mkdir -p out72
docker run --name php72-focal-build --platform linux/amd64 \
  -v "$PWD:/repo:ro" -v "$PWD/sources72:/sources:ro" -v "$PWD/out72:/out" \
  -e JOBS=4 ubuntu:20.04 \
  bash -c 'bash /repo/build72.sh && bash /repo/test72-install.sh && bash /repo/test72-build.sh' \
  2>&1 | tee out72/build.log
```

Use fresh container/output names for another run. Never run installation/test
scripts directly on a host: they intentionally change disposable containers.
No production config, app data or credentials are required. Inspect individual
result files and exit codes, not just a workflow badge. CI mounts only checked-in
build/test code and source/package inputs; artifacts expire.

The PHP 7.2 workflow builds on main pushes or manual dispatch. Inherited PHP 7.4
files are retained for source history context; that workflow is manual-only.

Source: [Surý PHP 7.2 source pool](https://packages.sury.org/php/pool/main/p/php7.2/).
