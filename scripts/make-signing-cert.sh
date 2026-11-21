#!/usr/bin/env bash
# Creates a self-signed code-signing identity in the login keychain, so local
# builds have a stable signature (and keep the Accessibility permission)
# without an Apple Developer account. Then writes Config/Local.xcconfig.
set -euo pipefail
NAME="${1:-Clipboard Local Signing}"
cd "$(dirname "$0")/.."

if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  echo "Identity \"$NAME\" already exists."
else
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  cat > "$tmp/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
CNF
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" -config "$tmp/cert.cnf" 2>/dev/null
  pass="$(/usr/bin/openssl rand -hex 16)"
  /usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
    -out "$tmp/id.p12" -passout "pass:$pass" -name "$NAME"
  security import "$tmp/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "$pass" -T /usr/bin/codesign
  echo "Created identity \"$NAME\"."
fi

if [ ! -f Config/Local.xcconfig ]; then
  cat > Config/Local.xcconfig <<XC
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = $NAME
DEVELOPMENT_TEAM =
OTHER_CODE_SIGN_FLAGS = --timestamp=none
XC
  echo "Wrote Config/Local.xcconfig."
fi
