#!/usr/bin/env bash
# Script Version: v2.0.0

# ------------------------------  Configurations  ------------------------------
# Constants
COUNTRY="IN"
STATE="MH"
LOCALITY="Pune"
ORGNAME="TIBCO"
ORGUNIT="Connectors"
COMMONNAMEFQDN=$DOMAINNAME
P12_EXPORT_PASSWORD="password"

# File names
ROOT_CA_KEY="rootCA.key.pem"
ROOT_CA_CRT="rootCA.crt.pem"
ROOT_CA_P12="rootCA.p12"
ROOT_CA_JKS="rootCA.jks"

SERVER_KEY="server.key.pem"
SERVER_CRT="server.crt.pem"
SERVER_P12="server.p12"
SERVER_JKS="server.jks"

CLIENT_KEY="client.key.pem"
CLIENT_CRT="client.crt.pem"
CLIENT_P12="client.p12"
CLIENT_JKS="client.jks"

# -----------------------------  Helper functions  -----------------------------
# arg1: error message
# [arg2]: exit code
function exit_with_error {
    printf '\n%s\n' "$1" >&2 ## Send message to stderr.
    exit "${2-1}" ## Return a code specified by $2, or 1 by default.
}

# arg1: command to run
function fail_by_rc {
  echo -e "Executing '${@}'\n"
  "$@"
  rc=$?
  if [ ${rc} -ne 0 ]; then
      exit_with_error "Failed to generate SSL certificates!" $rc
  fi
}

function is_user_root { 
  [ "${EUID:-$(id -u)}" -eq 0 ]; 
}

# arg1: command to run as root user
function run_as_root {
  if is_user_root; then
    fail_by_rc ${@}
  else
    fail_by_rc sudo ${@}
  fi
}

# tools installation done at docker level for caching 

# arg1: name of the program(s) to install
# function install_programs {
#   # run_as_root apt-get update
#   run_as_root apt-get install -y --no-install-recommends ${@} 
#   # run_as_root rm -rf /var/lib/apt/lists/*
# }


# # install dependencies
# if ! [ -x "$(command -v keytool)" ] || ! [ -x "$(command -v openssl)" ] || ! [ -x "$(command -v curl)" ]; then
#   echo -e "\nRequired tools are not installed...installing cURL, openssl, openjdk-8-jre-headless now..."
#   install_programs curl openssl openjdk-8-jre-headless
# fi

# set the CERTS_ROOT
if [ -z "$CERTS_ROOT" ]; then
  CERTS_ROOT="$(pwd)"
  echo -e "\nEnv var CERTS_ROOT is not defined...using PWD ($CERTS_ROOT) as CERTS_ROOT"
fi

# Check if script is running on Host/Physical machine
RUNNING_ON_HOST=$(grep 'docker\|lxc' /proc/1/cgroup)
if ! [ -z "$RUNNING_ON_HOST" ]; then
  echo -e "\nScript is running inside docker container...auto detecting hostname..."
  # Get hostname from EC2 Instance Metadata Service
  DOMAINNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
  if [ -z "$DOMAINNAME" ]; then
    # read -p 'Enter Domain Name [FQDN]: ' DOMAINNAME
    DOMAINNAME="${DOMAINNAME:-localhost}"
    echo -e "\nUnable to get hostname/FQDN from EC2 Instance Metadata Service...Using DOMAINNAME as '${DOMAINNAME}'" 
  else
    echo -e "\nAutodected FQDN for EC2: ${DOMAINNAME}"
  fi
else
  DOMAINNAME="${DOMAINNAME:-localhost}"
  echo -e "\nScript is running on host machine...using DOMAINNAME as '${DOMAINNAME}'"
fi

cd $CERTS_ROOT
rm -rf certs
mkdir -p certs
pushd certs


cat <<EOF >server.csr.cnf
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=$COUNTRY
ST=$STATE
L=$LOCALITY
O=$ORGNAME
OU=$ORGUNIT
emailAddress=admin@$DOMAINNAME
CN=$DOMAINNAME
EOF

cat <<EOF >client.csr.cnf
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=$COUNTRY
ST=$STATE
L=$LOCALITY
O=$ORGNAME
OU=$ORGUNIT
emailAddress=client@$DOMAINNAME
CN=$DOMAINNAME
EOF

cat <<EOF >server.ext
authorityKeyIdentifier = keyid,issuer
basicConstraints       = CA:FALSE
keyUsage               = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign
subjectAltName         = @alt_names
issuerAltName          = issuer:copy

[alt_names]
DNS.1=$DOMAINNAME
DNS.2=*.$DOMAINNAME
EOF


echo -e "\n*******  STEP 1/11: Creating private key for root CA  *******"
fail_by_rc openssl genrsa -out $ROOT_CA_KEY 2048

echo -e "\n*******  STEP 2/11: Creating root CA certificate  *******"
cat <<__EOF__ | openssl req -new -x509 -nodes -days 1024 -key $ROOT_CA_KEY -sha256 -out $ROOT_CA_CRT
$COUNTRY
$STATE
$LOCALITY
$ORGNAME
$ORGUNIT
$COMMONNAMEFQDN
admin@rootca.$DOMAINNAME
__EOF__

echo -e "\n*******  STEP 3/11: Creating private key for server  *******"
fail_by_rc openssl genrsa -out $SERVER_KEY 2048

echo -e "\n*******  STEP 4/11: Creating CSR for server  *******"
fail_by_rc openssl req -new -key $SERVER_KEY -out server.csr -config <(cat server.csr.cnf)

echo -e "\n*******  STEP 5/11: Creating server certificate  *******"
fail_by_rc openssl x509 -req -in server.csr -CA $ROOT_CA_CRT -CAkey $ROOT_CA_KEY -CAcreateserial -out $SERVER_CRT -days 1024 -sha256 -extfile server.ext

echo -e "\n*******  STEP 6/11: Creating private key for client  *******"
fail_by_rc openssl genrsa -out $CLIENT_KEY 2048

echo -e "\n*******  STEP 7/11: Creating CSR for client  *******"
fail_by_rc openssl req -new -key $CLIENT_KEY -out client.csr -config <(cat client.csr.cnf)

echo -e "\n*******  STEP 8/11: Creating client certificate  *******"
fail_by_rc openssl x509 -req -in client.csr -CA $ROOT_CA_CRT -CAkey $ROOT_CA_KEY -CAcreateserial -out $CLIENT_CRT -days 1024 -sha256

# echo -e "\n*******  STEP 9/11: Converting all keys in PKCS1 format for backward compatibility  *******"
# openssl rsa -in $ROOT_CA_KEY -out rootCA.pkcs1.key
# openssl rsa -in $SERVER_KEY -out server.pkcs1.key
# openssl rsa -in $CLIENT_KEY -out client.pkcs1.key

echo -e "\n*******  STEP 9/11: Converting all certs in PKCS12 format using export password as '${P12_EXPORT_PASSWORD}'  *******"
fail_by_rc openssl pkcs12 -export -in $ROOT_CA_CRT -inkey $ROOT_CA_KEY -out $ROOT_CA_P12 -passout pass:$P12_EXPORT_PASSWORD -name "rootca"

fail_by_rc openssl pkcs12 -export -in $SERVER_CRT -inkey $SERVER_KEY -out $SERVER_P12 -passout pass:$P12_EXPORT_PASSWORD -name "server"

fail_by_rc openssl pkcs12 -export -in $CLIENT_CRT -inkey $CLIENT_KEY -out $CLIENT_P12 -passout pass:$P12_EXPORT_PASSWORD -name "client"

echo -e "\n*******  STEP 10/11: Converting all certs from PKCS#12 to JKS format  *******"
fail_by_rc keytool -importkeystore -srckeystore $ROOT_CA_P12 -srcstoretype pkcs12 -srcstorepass $P12_EXPORT_PASSWORD -srcalias rootca -destkeystore $ROOT_CA_JKS -deststorepass $P12_EXPORT_PASSWORD -destalias rootca

fail_by_rc keytool -importkeystore -srckeystore $SERVER_P12 -srcstoretype pkcs12 -srcstorepass $P12_EXPORT_PASSWORD -srcalias server -destkeystore $SERVER_JKS -deststorepass $P12_EXPORT_PASSWORD -destalias server

fail_by_rc keytool -importkeystore -srckeystore $CLIENT_P12 -srcstoretype pkcs12 -srcstorepass $P12_EXPORT_PASSWORD -srcalias client -destkeystore $CLIENT_JKS -deststorepass $P12_EXPORT_PASSWORD -destalias client

echo -e "\n*******  STEP 11/11: Deleting extra files  *******"
fail_by_rc rm -f *.csr *.ext *.srl *.cnf

popd