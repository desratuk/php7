# PHP 7.2 generic test record and limits

Scope: Ubuntu 20.04 amd64, PHP 7.2.34 revision 66 community rebuild. These are
historical results for the build/test code retained in this snapshot. Source
manifests/build scripts remain unchanged by the public documentation cleanup.
Detailed application/deployment records are outside this public repository.

## Build, regression and FPM

20 core CLI/FPM/module packages built and installed. Direct FPM startup/config,
local FastCGI requests, persistent sessions, multipart upload integrity, CLI/FPM
OOM termination without user destructors and subsequent worker recovery passed.

The selected native amd64 suite completed with 1,273 passes, zero unexpected
failures, three existing expected failures and 409 skips (1,685 total). This is
not the full PHP/extension suite. Existing skips/expected failures remain limits.
No tests were newly skipped or reclassified to obtain this result.

Three distribution/backport fixture mismatches were corrected: two session tests
explicitly set an empty save path rather than inheriting the packaged default;
one OOM test expects the safe-bailout diagnostic's intentional leading newline.
Test bodies/security checks and the backport were not weakened. A local emulated
file-descriptor failure did not reproduce in native CI; that test was unchanged.
An earlier pipeline masked a failing assertion; Bash/pipefail and corrected
version checks ensure later results propagate actual failures.

## Isolated historical-package upgrades

Disposable Focal containers upgraded original Surý revisions 34 and 36. All 133
synthetic config files/symlinks and CLI/FPM module lists were preserved for each.
APT added libzip5, retained libzip4 and removed no packages. Unrelated package
versions stayed unchanged. Customized master/pool/INI inputs were synthetic.
Original package sizes/hashes were checked against archived Launchpad records;
independent GPG verification is not claimed. This is not a historical OS image.

`test72-upgrade.sh` accepts verified original/candidate package directories with
SHA256SUMS, mounted read-only at `/old` and `/candidate`; mount this checkout at
`/repo:ro` and a fresh report directory at `/out`. Run only in a disposable Focal
amd64 container. It installs packages, blocks automatic service starts using
policy-rc.d and starts FPM directly for checks. Final preservation snapshots were
also checked after the historical test harness corrections; no fresh full
end-to-end rerun of that final upgrade harness is claimed.

## Limited application smoke testing

One private Symfony-based application received limited public-page and
authenticated read-only smoke checks on patched FPM in a Focal amd64 container.
No application compatibility code changes were needed. No application files,
credentials, database contents or deployment-specific comparisons are published.
This validates neither other applications nor complete business workflows.

## Untested / use at own risk

- Full PHP/extension regression suite and independent security/exploit audit.
- Application writes, submissions, uploads, email, external integrations,
  background jobs/queues and full business workflows.
- General PECL/custom extension and multi-PHP coexistence compatibility.
- Apache/mod_php, CGI, LiteSpeed, phpdbg and embedded PHP runtime behavior.
- Production performance/load, systemd integration, other historical revisions,
  OS versions, architectures or complete server/data rollback.
- Independent source-signature verification and ongoing security maintenance.

Containers started FPM directly. Compiling additional SAPIs does not imply they
were exercised. Generic test results are not a production-readiness guarantee.
