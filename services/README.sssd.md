# System Security Services Daemon (SSSD) Installation

These are shell scripts which can install and configure [SSSD](https://pagure.io/SSSD/sssd/) on a node.  The goal of the scripts are to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

| Script                   | Use                                               |
| ------------------------ | ------------------------------------------------- |
| install_sssd-ad.sh       | Joins the node to an Active Directory domain.     |
| install_sssd-ldap+krb.sh | Authenticate via Kerberos and indentify via LDAP. |
| install_sssd-ldap.sh     | Authenticate and indentify via LDAP.              |

Pass `--help` to each script to see the options.

* Tested on RHEL/CentOS 6 and 7.

## Installation

### Active Directory

```
GITREPO=~/git/teamclairvoyant/bash
ADDOMAIN=HADOOP.COM

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/install_sssd-ad.sh ${HOST}:
ssh -t $HOST "sudo bash -x install_sssd-ad.sh --domain $ADDOMAIN"
```

### LDAP and Kerberos

```
GITREPO=~/git/teamclairvoyant/bash
REALM=HADOOP.COM
KDC=some.host
LDAP=some2.host
BASE="OU=Users,dc=SOME,dc=DOMAIN"

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/install_sssd-ldap+krb.sh ${HOST}:
ssh -t $HOST "sudo bash -x install_sssd-ldap+krb.sh --realm $REALM --krbserver $KDC --ldapserver $LDAP --suffix $BASE"
```

### LDAP

```
GITREPO=~/git/teamclairvoyant/bash
LDAP=some.host
BASE="OU=People,dc=MY,dc=DOMAIN"

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/install_sssd-ldap.sh ${HOST}:
ssh -t $HOST "sudo bash -x install_sssd-ldap.sh --ldapserver $LDAP --suffix $BASE"
```

