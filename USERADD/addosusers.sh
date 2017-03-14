
#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2017
#########################################
# Useradd Script
#########################################
# Bash script (NOT Ansible) that will take 2 data files as input 1st(groups.yaml) containing groupname,group ID from a yaml file and 2nd(users.yaml) containing username, crypted password, Full Name/GECOS, home directory, UID, #GID, groups, email, and SSH public key and use that data to create the following:
#1) A Linux group named for the user in /etc/group.
#2) The Linux user in /etc/passwd.
#3) Add the user to any additional group(s).
#4) Install the user's SSH public key in their home directory in order to allow passwordless SSH.
#The data file should be structured (JSON or YAML). The script should not require user interaction.



# Modify the source location of the $DATAFILE
GROUP_DATAFILE='/path/to/groups.yaml'

for GROUPNAME in $(grep -v '^\ ' $GROUP_DATAFILE | grep -v '^#' | grep -v '^-'| sed 's/://g')
do
	GID=$(cat $GROUP_DATAFILE | shyaml get-value ${GROUPNAME}.gid)
	groupadd -g $GID $GROUPNAME
done

USER_DATAFILE='/path/to/users.yaml'

for USERNAME in $(grep -v '^\ ' $USER_DATAFILE | grep -v '^#'  | grep -v '^-' | sed 's/://g')
do

	COMMENT=`cat $USER_DATAFILE | shyaml get-value ${USERNAME}.comment`
#	HOMEDIR=
	UID_NO=`cat $USER_DATAFILE | shyaml get-value ${USERNAME}.uid`
	GID_NO=`cat $USER_DATAFILE | shyaml get-value ${USERNAME}.gid`
	GROUPS_NAME=`cat $USER_DATAFILE | shyaml get-value ${USERNAME}.groups | sed 's/\-\ //g'`
 	GROUPS_NAME=`echo $GROUPS_NAME | tr ' ' ','`
#	EMAIL =
	SSHKEY=`cat $USER_DATAFILE | shyaml get-value ${USERNAME}.sshkeys | sed 's/\-\ //g'`
	OPTIONS=""
	if [ "$USERNAME" == "" ]; then
		echo"No username Found"
	else
		# if [ "$COMMENT" != "" ]; then OPTIONS="-c '$COMMENT' $OPTIONS" ; fi
		if [ "$UID_NO" != "" ]; then OPTIONS="-u $UID_NO $Hiren" ; fi
		if [ "$HOMEDIR" != "" ]; then OPTIONS="-d $HOMEDIR $Hiren" ; fi
		if [ "$PASSWORD" != "" ]; then OPTIONS="-p $PASSWORD $OPTIONS" ; fi
#   Adding user with respected critaria
		useradd $USERNAME $OPTIONS -c "$COMMENT"
		if [ "$GROUPS_NAME" != "" ]
		then
			usermod -a -G $GROUPS_NAME $USERNAME
		fi

		if [ "$GID_NO" != "" ]
		then
			 groupmod -g $GID_NO $USERNAME
		fi

		if [ "$SSHKEY" != "" ]
		then
		#	Adding ssh key to user's home directory
			su - $USERNAME -c "mkdir ~/.ssh && echo \"ssh-rsa $SSHKEY\" > ~/.ssh/authorized_keys"
		#	Modifying permission of .ssh folder as it should be 700 only and default is 755
			su - $USERNAME -c "chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
		fi
	fi
done
