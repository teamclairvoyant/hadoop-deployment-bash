# Cloudera Navigator Encrypt Installation

These are shell scripts to deploy [Cloudera Navigator Encrypt](https://www.cloudera.com/documentation/enterprise/latest/topics/sg_navigator_encrypt.html) to a node.  The goal of these scripts are to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

* Assumes RHEL/CentOS 7 x86_64.

Scripts should be run in the following order:

* navencrypt_register.sh
* navencrypt_preprepare.sh
* navencrypt_prepare.sh
* navencrypt_move.sh

