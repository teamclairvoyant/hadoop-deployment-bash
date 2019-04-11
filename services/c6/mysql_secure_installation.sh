#!/bin/sh
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
# https://bertvv.github.io/notes-to-self/2015/11/16/automating-mysql_secure_installation/
#
# A non-interactive replacement for mysql_secure_installation
#
# Tested on CentOS 6, CentOS 7, Ubuntu 12.04 LTS (Precise Pangolin), Ubuntu
# 14.04 LTS (Trusty Tahr).

set -o errexit # abort on nonzero exitstatus
set -o nounset # abort on unbound variable

#{{{ Functions

usage() {
  cat << _EOF_

Usage: ${0} "ROOT PASSWORD"

  with "ROOT PASSWORD" the desired password for the database root user.

Use quotes if your password contains spaces or other special characters.
_EOF_
}

# Predicate that returns exit status 0 if the database root password
# is set, a nonzero exit status otherwise.
is_mysql_root_password_set() {
  ! mysqladmin --user=root status > /dev/null 2>&1
}

# Predicate that returns exit status 0 if the mysql(1) command is available,
# nonzero exit status otherwise.
is_mysql_command_available() {
  command -v mysql > /dev/null 2>&1
}

# Command line parsing
if [ "$#" -ne "1" ]; then
  echo "ERROR: Expected 1 argument, got $#" >&2
  usage
  exit 2
fi

# Variables
db_root_password="${1}"

# Script proper
if ! is_mysql_command_available; then
  echo "ERROR: The MySQL client mysql(1) is not installed."
  exit 1
fi

if is_mysql_root_password_set; then
  echo "ERROR: Database root password already set."
  exit 3
fi

mysql --user=root <<_EOF_
  #UPDATE mysql.user SET Password=PASSWORD('${db_root_password}') WHERE User='root';
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${db_root_password}';
  DELETE FROM mysql.user WHERE User='';
  #DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
_EOF_

echo "SUCCESS: mysql_secure_installation"

