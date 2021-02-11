#!/bin/sh

mkdir -p /kopano/ssl/clients/

set -euo

# clean out any potential port numbers
FQDN=${FQDN%:*}

# create files so that konnect can write to it
touch /kopano/ssl/konnectd-identifier-registration.yaml /kopano/ssl/ecparam.pem /kopano/ssl/meet-kwmserver.pem
# chown to the numerical representation of nobody/nogroup
chown 65534:65534 /kopano/ssl/konnectd-identifier-registration.yaml /kopano/ssl/ecparam.pem /kopano/ssl/meet-kwmserver.pem


if [ ! -f /kopano/ssl/ca.pem ]; then
	# https://github.com/google/easypki
	echo "Creating CA certificate..."
	easypki create --filename internalca --organizational-unit primary --expire 3650 --ca "Internal Kopano System"

	cp /kopano/easypki/internalca/certs/internalca.crt /kopano/ssl/ca.pem.tmp
	mv /kopano/ssl/ca.pem.tmp /kopano/ssl/ca.pem

	for s in kopano_server kopano_server_2 kopano_dagent kopano_monitor kopano_search kopano_spooler kopano_webapp admin; do
		if [ ! -f /kopano/ssl/$s.pem ]; then
			echo "Creating $s certificate..."
			easypki create --ca-name internalca --organizational-unit $s --expire 3650 --dns $s --dns "$FQDN" $s
			cp /kopano/easypki/internalca/keys/$s.key /kopano/ssl/$s.pem.tmp
			cat /kopano/easypki/internalca/certs/$s.crt >> /kopano/ssl/$s.pem.tmp
			openssl x509 -in /kopano/easypki/internalca/certs/$s.crt -pubkey -noout >  /kopano/ssl/clients/$s-public.pem.tmp
			mv /kopano/ssl/$s.pem.tmp /kopano/ssl/$s.pem
			mv /kopano/ssl/clients/$s-public.pem.tmp /kopano/ssl/clients/$s-public.pem
		fi
	done
fi

# Konnect - create encryption key if not already present
enckey="/kopano/ssl/konnectd-encryption.key"
if [ ! -f $enckey ]; then
	echo "Creating Konnect encryption key..."
	openssl rand -out $enckey.tmp 32
	mv $enckey.tmp $enckey
fi

# Konnect - create token signing key if not already present
signkey="/kopano/ssl/konnectd-tokens-signing-key.pem"
if [ ! -L $signkey ] && [ ! -f $signkey ]; then
	echo "Creating Konnect token signing key..."
	openssl genpkey -algorithm RSA -out $signkey.tmp -pkeyopt rsa_keygen_bits:4096 >/dev/null 2>&1
	chmod go+r $signkey.tmp
	mv $signkey.tmp $signkey
fi

# Kapi
secretkey="/kopano/ssl/kapid-pubs-secret.key"
if [ ! -f $secretkey ]; then
	echo "Creating Kapi secret key..."
	openssl rand -out $secretkey.tmp -hex 64
	mv $secretkey.tmp $secretkey
fi

echo "SSL certs:"
ls -l /kopano/ssl/*.*

echo "Client public keys:"
ls -l /kopano/ssl/clients/*
