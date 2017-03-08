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
# Copyright Clairvoyant 2015

#Create user Script
#########################################
#Create a shell script (NOT Ansible) that will take a data file containing username, crypted password, Full Name/GECOS, home directory, UID, #GID, groups, email, and SSH public key and use that data to create the following:
#1) A Linux group named for the user in /etc/group.
#2) The Linux user in /etc/passwd.
#3) Add the user to any additional group(s).
#4) Install the user's SSH public key in their home directory in order to allow passwordless SSH.
#The data file should be structured (JSON or YAML). The script should not require user interaction.


# Modify the source location of the $DATAFILE 
DATAFILE='/tmp/datafile'

for USERNAME in $(grep -v '^\ ' $DATAFILE | grep -v '^#' | sed 's/://g')
do
	COMMENT=`cat $DATAFILE | shyaml get-value ${USERNAME}.comment`
#	HOMEDIR=
	UID_NO=`cat $DATAFILE | shyaml get-value ${USERNAME}.uid` 
	GID_NO=`cat $DATAFILE | shyaml get-value ${USERNAME}.gid`
	GROUPS_NAME=`cat $DATAFILE | shyaml get-value ${USERNAME}.groups | sed 's/\-\ //g'`
#	EMAIL =
	SSHKEY=`cat $DATAFILE | shyaml get-value ${USERNAME}.sshkeys | sed 's/\-\ //g'`
	OPTIONS=""
	if [ "$USERNAME" == "" ]; then 
		echo"No username Found"
	else
		# if [ "$COMMENT" != "" ]; then OPTIONS="-c '$COMMENT' $OPTIONS" ; fi
		if [ "$UID_NO" != "" ]; then OPTIONS="-u $UID_NO $OPTIONS" ; fi
		if [ "$HOMEDIR" != "" ]; then OPTIONS="-d $HOMEDIR $OPTIONS" ; fi
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
