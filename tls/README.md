# TLS Configuration

All of these instructions are specific to a Cloudera Hadoop environment.  All the details can be found in [Configuring Cloudera Manager Clusters for TLS/SSL](https://www.cloudera.com/documentation/enterprise/latest/topics/cm_sg_config_tls_security.html)

## Generate a TLS Certificate Signing Request

This script will generate a private key and a certificate signing request (CSR) with the correct attributes and in the correct formats for configuration of the Cloudera Hadoop infrastructure.  It will deal with creating the Java KeyStores and the PEM-formatted x.509 files as well as preparing for the use of TLS by the Cloudera Manager Agent.

Command arguments for `generate_csr.sh`:
- ARGV 1 - TLS certificate Common Name - required
- ARGV 2 - JKS store password - required
- ARGV 3 - JKS key password (should be the same as JKS store password) - required
- ARGV 4 - Extra parameters for keytool (ie Subject Alternative Name (SAN)) - optional

### Simple Example

This will generate a certificate signing request (CSR) on a single host and copy the CSR to the local machine.  The first argument to `generate_csr.sh` can be modified to use whatever custom x.500 distinguishedName format is required for the certificate.

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost
CMPASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo)
# Save this output
echo "CMPASS : $CMPASS"

scp -p ${GITREPO}/tls/create_security.sh ${GITREPO}/tls/generate_csr.sh ${MACHINE}:
ssh -t $MACHINE "sudo bash ./create_security.sh;\
  sudo bash ./generate_csr.sh \"CN=\`hostname -f\`\" $CMPASS $CMPASS"
scp -p ${MACHINE}:/opt/cloudera/security/x509/localhost.csr ${MACHINE}.csr
```

### Complex Example

This will generate CSRs with a SAN that includes a load balancer and a friendly name.  Remove "`,DNS:${LOADBALANCER_DNS_NAME}`" and/or "`,DNS:${FRIENDLY_DNS_NAME}`" if they are not used.

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost
LOADBALANCER_DNS_NAME=ELB-1234567890.us-east-2.elb.amazonaws.com
FRIENDLY_DNS_NAME=service.example.com
CMPASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo)
# Save this output
echo "CMPASS : $CMPASS"

scp -p ${GITREPO}/tls/create_security.sh ${GITREPO}/tls/generate_csr.sh ${MACHINE}:
ssh -t $MACHINE "sudo bash ./create_security.sh;\
  sudo bash ./generate_csr.sh \"CN=\`hostname -f\`\" $CMPASS $CMPASS \
  \"SAN=DNS:\`hostname -f\`,DNS:${LOADBALANCER_DNS_NAME},DNS:${FRIENDLY_DNS_NAME}\""
scp -p ${MACHINE}:/opt/cloudera/security/x509/localhost.csr ${MACHINE}.csr
```

At this point, have the CSRs signed by the certificate authority (CA).

__The `CMPASS` variable is the keypassword and storepassword for the Java KeyStore.  It should be the same for all hosts.  Make sure you do not lose this value as it will be needed in Cloudera Manager.__

## Install a TLS Signed Certificate

Once the CSR has been signed by the CA, we need to send the resulting public x.509 certificate to the host and install it and the CA chain into the keystore.  Also install the CA chain in the Java and the system truststores.

This script depends on having followed the [Generate a TLS Certificate Signing Request](#generate-a-tls-certificate-signing-request) instructions.

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost
CMPASS=$CMPASS

scp -p ${GITREPO}/tls/install_rootCA.sh ca.cert.pem intermediate.cert.pem ${MACHINE}:
ssh -t $MACHINE 'sudo install -m 0444 -o root -g root ./ca.cert.pem \
  /opt/cloudera/security/CAcerts/ca.cert.pem; sudo install -m 0444 -o root -g root \
  ./intermediate.cert.pem /opt/cloudera/security/CAcerts/intermediate.cert.pem; \
  sudo bash ./install_rootCA.sh'

scp -p ${GITREPO}/tls/import_cert.sh ${MACHINE}:
scp -p ${MACHINE}.pem ${MACHINE}:localhost.pem
ssh -t $MACHINE "sudo install -m 0444 -o root -g root ./localhost.pem \
  /opt/cloudera/security/x509/localhost.pem; sudo bash ./import_cert.sh $CMPASS"
```

## Create and Install the Cloudera Manager Server Truststore

Cloudera Manager needs to know what agents to trust.  This is acheived by installing each individual host's certificate into a truststore along with the CA chain.

This script depends on having followed the [Install a TLS Signed Certificate](#install-a-tls-signed-certificate) instructions.

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost
CMSERVERHOST=cmhost
SPASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo)
# Save this output
echo "SPASS : $SPASS"

keytool -importcert -noprompt -keystore cmtruststore.jks \
  -alias CAcert -file ca.cert.pem -storepass $SPASS
keytool -importcert -noprompt -keystore cmtruststore.jks \
  -alias CAcertint -file intermediate.cert.pem -storepass $SPASS

for HOST in $MACHINE; do
  echo "*** $HOST"
  keytool -importcert -noprompt -keystore cmtruststore.jks \
    -alias $HOST -file ${HOST}.pem -storepass $SPASS
done

scp -p cmtruststore.jks ${CMSERVERHOST}:
ssh -t $CMSERVERHOST 'sudo install -o root -g cloudera-scm -m 0440 cmtruststore.jks \
  /opt/cloudera/security/jks/cmtruststore.jks'
```

__The `SPASS` variable is the storepassword for the Java TrustStore.  Make sure you do not lose this value as it will be needed in Cloudera Manager.__

## Configure Cloudera Manager Agent to use TLS

Sets up the CM agent to use level 2 or optionally level 3 authentication for encrypted communications with the CM server. [Configuring Cloudera Manager Clusters for TLS/SSL](https://www.cloudera.com/documentation/enterprise/latest/topics/cm_sg_config_tls_security.html)

This script depends on having followed the [Create and Install the Cloudera Manager Server Truststore](#create-and-install-the-cloudera-manager-server-truststore) instructions.

Command arguments for `enable_clouderamanageragentsecurity.sh`:
- ARGV 1 - Whether to enable Level 3 agent authN to server. - optional

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost

scp -p ${GITREPO}/tls/enable_clouderamanageragentsecurity.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash ./enable_clouderamanageragentsecurity.sh LEVEL3'
```

## Install CDH TLS Certificates

This script will create copies of the original Java KeyStore and change ownership and permissions such that each service (hive, hdfs, yarn, etc) will have access to its own file.

This script depends on having followed the [Install a TLS Signed Certificate](#install-a-tls-signed-certificate) instructions.

__WARNING: MUST HAVE PARCELS INSTALLED AT THIS POINT.__

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost

scp -p ${GITREPO}/tls/copy_cert.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash ./copy_cert.sh'
```
You can perform the same actions for the Cloudera Kafka (`copy_cert-kafka.sh`), Key Management Server (`copy_cert-kms.sh`), and Key Trustee Server certificates (`copy_cert-trustee.sh`).

## Configure dump_cm_config to use TLS

This script wil convert the `dump_cm_config.sh` program to use TLS protocol and ports.

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
CMSERVERHOST=cmhost

scp -p ${GITREPO}/tls/configure_dump_cm_config_tls.sh ${CMSERVERHOST}:
ssh -t ${CMSERVERHOST} 'sudo bash ./configure_dump_cm_config_tls.sh'
```

## Configure Apache httpd for TLS

Configure an existing [Apache httpd](https://httpd.apache.org/) installation to use the Cloudera TLS certificates.  This script depends on having followed the [Install a TLS Signed Certificate](#install-a-tls-signed-certificate) instructions.  The configuration also disables SSLv2 and SSLv3 protocols.

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost

scp -p ${GITREPO}/tls/configure_httpd_tls.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash ./configure_httpd_tls.sh'
```

## Configure OpenLDAP for TLS

Configure an existing [OpenLDAP](https://www.openldap.org/) server installation to use the Cloudera TLS certificates.  This script depends on having followed the [Install a TLS Signed Certificate](#install-a-tls-signed-certificate) instructions.  The configuration also disables SSLv2 and SSLv3 protocols.

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost

scp -p ${GITREPO}/tls/configure_openldap_tls.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash ./configure_openldap_tls.sh'
```

## Configure Cloudera Director for TLS

Configure an existing [Cloudera Director](https://www.cloudera.com/products/product-components/cloudera-director.html) server installation to use the Cloudera TLS certificates.  This script depends on having followed the [Install a TLS Signed Certificate](#install-a-tls-signed-certificate) instructions.  The configuration also disables SSLv2, SSLv3, TLSv1.0, and TLSv1.1 protocols.

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost
CMPASS=$CMPASS

scp -p ${GITREPO}/tls/configure_clouderadirector_tls.sh ${MACHINE}:
ssh -t $MACHINE "sudo bash ./configure_clouderadirector_tls.sh $CMPASS"
```

