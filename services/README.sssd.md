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
PASSWORD=hahahahaha

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/install_sssd-ad.sh ${HOST}:
ssh -t $HOST "sudo bash -x install_sssd-ad.sh --domain $ADDOMAIN --batch <<< $PASSWORD"
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

## Authorization

In order to restrict which users can authenticate to the system (for example via SSH) SSSD can be configured for [client-side access control](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/windows_integration_guide/realmd-logins) in order [to only allow certain users or groups](https://www.freedesktop.org/software/realmd/docs/realm.html).

### Active Directory

Users:
```
realm permit user@example.com
realm permit 'AD.EXAMPLE.COM\user'
```

Groups:
```
realm permit -g group@example.com
```
