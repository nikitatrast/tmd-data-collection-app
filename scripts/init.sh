#!/bin/bash
set -euo pipefail  # see: bash strict mode


echo "This script will setup the necessary files."

if [ -d "server" ] && [ -d "smartphone-app" ]; then
    PREFIX="."
elif [ -d "../server" ] && [ -d "../smartphone-app" ]; then
    PREFIX=".."
else 
    read -p "Enter path to project root (where .git is) " PREFIX
    PREFIX=${PREFIX%/}  # remove trailing slash
fi

if [ ! -d "$PREFIX/server" ]; then
    echo "Unable to find $PREFIX/server directory"
    exit 1
fi
if [ ! -d "$PREFIX/smartphone-app" ]; then
    echo "Unable to find $PREFIX/smartphone-app directory"
    exit 1
fi

CERT_DIR="$PREFIX/certificates"
mkdir -p $CERT_DIR

#-----------------------
# Certificate Authority

CA_KEY="$CERT_DIR/CA.key"
CA_PEM="$CERT_DIR/CA.pem"
CA_DER="$CERT_DIR/CA.der"
CA_CSR="$CERT_DIR/CA.csr"
CA_SRL="$CERT_DIR/CA.srl"
EXT_FILE="$PREFIX/scripts/x509.ext"

if [ -f "$CA_KEY" ] && [ -f "$CA_PEM" ]; then
    echo "$CA_KEY found"
    echo "$CA_PEM found"
else
    echo "Generating a self-signed certificate authority (CA)"
    openssl req -new -sha256 -nodes -newkey rsa:4096 -keyout "$CA_KEY" -out "$CA_CSR"
    openssl x509 -req -sha256 -extfile "$EXT_FILE" -extensions ca -in "$CA_CSR" -signkey "$CA_KEY" -days 1095 -out "$CA_PEM"
fi

if [ -f "$CA_DER" ]; then
    echo "$CA_DER found"
else
    openssl x509 -in "$CA_PEM" -outform der -out "$CA_DER"
fi

#-------------------
# Server Certificate

echo
echo "Checking server certificate status..."
DOMAIN=""
while [ -z "$DOMAIN" ]; do
    read -p 'Domain? (example.com) ' DOMAIN
done

read -p 'Organization name? ' COMPANY

SERVER_KEY="$CERT_DIR/$DOMAIN.key"
SERVER_PEM="$CERT_DIR/$DOMAIN.pem"
SERVER_DER="$CERT_DIR/$DOMAIN.der"
SERVER_CSR="$CERT_DIR/$DOMAIN.csr"

if [ -f "$SERVER_KEY" ] && [ -f "$SERVER_PEM" ]; then
    echo "$SERVER_KEY found"
    echo "$SERVER_PEM found"
else
    SUBJ="/CN=${DOMAIN}/O=${COMPANY}"
    echo "Info: the following subject will be used to generate server certificate: $SUBJ"
    openssl req -new -sha256 -nodes -subj "$SUBJ" -newkey rsa:4096 -keyout "$SERVER_KEY" -out "$SERVER_CSR"
    openssl x509 -req -sha256 -CA "$CA_PEM" -CAkey "$CA_KEY" -days 730 -CAcreateserial -CAserial "$CA_SRL" -extfile "$EXT_FILE" -extensions server -in "$SERVER_CSR" -out "$SERVER_PEM"
fi

if [ -f "$SERVER_DER" ]; then
    echo "$SERVER_DER found"
else
    openssl x509 -in "$SERVER_PEM" -outform der -out "$SERVER_DER"
fi

#-------------------
# Client Certificate

CLIENT_KEY="$CERT_DIR/client.key"
CLIENT_PEM="$CERT_DIR/client.pem"
CLIENT_CSR="$CERT_DIR/client.csr"

if [ -f "$CLIENT_KEY" ] && [ -f "$CLIENT_PEM" ]; then
    echo "$CLIENT_KEY found"
    echo "$CLIENT_PEM found"
else
    SUBJ="/O=${COMPANY}"
    echo "Info: the following subject will be used to generate client certificate: $SUBJ"
    openssl req -new -sha256 -nodes -subj "$SUBJ" -newkey rsa:4096 -keyout "$CLIENT_KEY" -out "$CLIENT_CSR"
    openssl x509 -req -sha256 -CA "$CA_PEM" -CAkey "$CA_KEY" -days 730 -CAcreateserial -CAserial "$CA_SRL" -extfile "$EXT_FILE" -extensions server -in "$CLIENT_CSR" -out "$CLIENT_PEM"
fi

#-------------------
# EXPORT to APP


# Copy to Traefik config

CONFIG="$PREFIX/server/traefik/config/$DOMAIN.toml"
if [ ! -f "$CONFIG" ]; then
    echo "Generating Traefik config file: $CONFIG"
    cat > "$CONFIG" << EOM
[[tls.certificates]]
  certFile = "/certificates/$DOMAIN.pem"
  keyFile = "/certificates/$DOMAIN.key"
EOM
fi

SERVER_CERT_DIR="$PREFIX/server/certificates"
[ -d "$SERVER_CERT_DIR" ] || mkdir "$SERVER_CERT_DIR"

TRAEFIK_KEY="$SERVER_CERT_DIR/$DOMAIN.key"
TRAEFIK_PEM="$SERVER_CERT_DIR/$DOMAIN.pem"
TRAEFIK_CLIENT_CA="$SERVER_CERT_DIR/client-ca.pem"

echo "Copying certificates to Traefik's certificate directory"
cp "$SERVER_KEY" "$TRAEFIK_KEY"
cp "$SERVER_PEM" "$TRAEFIK_PEM"
cp "$CA_PEM" "$TRAEFIK_CLIENT_CA"

# Copy to Flutter assets

FLUTTER_ASSET_DIR="$PREFIX/smartphone-app/assets"
FLUTTER_CERT_DIR="$FLUTTER_ASSET_DIR/certificates"
[ -d "$FLUTTER_ASSET_DIR" ] || mkdir "$FLUTTER_ASSET_DIR"
[ -d "$FLUTTER_CERT_DIR" ]  || mkdir "$FLUTTER_CERT_DIR"

FLUTTER_CLIENT_KEY="$FLUTTER_CERT_DIR/client.key"
FLUTTER_CLIENT_PEM="$PREFIX/smartphone-app/assets/certificates/client.pem"
FLUTTER_SERVER_CA_PEM="$PREFIX/smartphone-app/assets/certificates/server-ca.pem"
FLUTTER_SERVER_CA_DER="$PREFIX/smartphone-app/assets/certificates/server-ca.der"

echo "Copying client certificate to flutter application's assets"
cp "$CA_PEM" "$FLUTTER_SERVER_CA_PEM"
cp "$CA_DER" "$FLUTTER_SERVER_CA_DER"
cp "$CLIENT_KEY" "$FLUTTER_CLIENT_KEY"
cp "$CLIENT_PEM" "$FLUTTER_CLIENT_PEM"

# Configure default ports

echo "Requests will be sent to https://$DOMAIN:443. You can change the port number, or leave blank to keep 443"
re='^[0-9]*$'

read -p "Https port number for secured connections? (default: 443) " PORT
while ! [[ "$PORT" =~ $re ]] ; do
   read -p "Https port number for secured connections? (default: 443) " PORT
done
if [ -z "$PORT" ]; then
    PORT=443
fi
echo "Using https port $PORT"

read -p "Http port number for unsecured connections? (default: 80) " HTTP_PORT
while ! [[ "$HTTP_PORT" =~ $re ]] ; do
   read -p "Http port number for unsecured connections? (default: 80) " HTTP_PORT
done
if [ -z "$HTTP_PORT" ]; then
    HTTP_PORT=80
fi

# Write flutter config

FLUTTER_SERVER_CONFIG="$PREFIX/smartphone-app/assets/server-info.json"
echo "Writing $FLUTTER_SERVER_CONFIG"
cat > "$FLUTTER_SERVER_CONFIG" << EOM
{"domain": "$DOMAIN", "port": "$PORT"}
EOM

# Write docker config

DOCKER_ENV_CONFIG="$PREFIX/server/.env"
echo "Writing $DOCKER_ENV_CONFIG"
cat > "$DOCKER_ENV_CONFIG" << EOM
TMD_HOST=$DOMAIN
HTTPS_PORT=$PORT
HTTP_PORT=$HTTP_PORT
EOM

echo "Done!"
