#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p sources72
while read -r _ file; do
  curl --fail --location --retry 3 "https://packages.sury.org/php/pool/main/p/php7.2/$file" -o "sources72/$file"
done < sources72.sha256
(cd sources72 && shasum -a 256 -c ../sources72.sha256)
