#!/bin/bash
set -euo pipefail

# Create a self-signed code signing certificate for Sayit
# This ensures stable signing across rebuilds so macOS permissions persist

CERT_NAME="Sayit Dev"

# Check if cert already exists
if security find-identity -v -p codesigning 2>&1 | grep -q "$CERT_NAME"; then
    echo "Certificate '$CERT_NAME' already exists."
    exit 0
fi

echo "Creating self-signed certificate: '$CERT_NAME'"

# Create the certificate using a signing request
cat > /tmp/sayit-cert.conf << 'EOF'
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
prompt             = no

[ req_distinguished_name ]
CN = Sayit Dev
EOF

# Generate key and cert
openssl req -x509 -newkey rsa:2048 -keyout /tmp/sayit-key.pem -out /tmp/sayit-cert.pem \
    -days 3650 -nodes -config /tmp/sayit-cert.conf 2>/dev/null

# Convert to p12
openssl pkcs12 -export -out /tmp/sayit.p12 \
    -inkey /tmp/sayit-key.pem -in /tmp/sayit-cert.pem \
    -passout pass:sayit -legacy 2>/dev/null

# Import to keychain with codesigning trust
security import /tmp/sayit.p12 -k ~/Library/Keychains/login.keychain-db \
    -P sayit -T /usr/bin/codesign -T /usr/bin/security

# Set trust to always trust for code signing
security add-trusted-cert -d -r trustRoot -p codeSign -k ~/Library/Keychains/login.keychain-db /tmp/sayit-cert.pem

# Cleanup
rm -f /tmp/sayit-cert.conf /tmp/sayit-key.pem /tmp/sayit-cert.pem /tmp/sayit.p12

echo "Certificate '$CERT_NAME' created and trusted."
echo "You can verify with: security find-identity -v -p codesigning"
