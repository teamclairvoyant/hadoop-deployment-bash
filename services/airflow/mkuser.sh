#!/usr/bin/python
# https://airflow.incubator.apache.org/security.html
username = 'admin'
email = 'admin@example.com'
#####

import airflow
from airflow import models, settings
from airflow.contrib.auth.backends.password_auth import PasswordUser

# https://stackoverflow.com/questions/3854692/generate-password-in-python
import string
from random import sample, choice
chars = string.letters + string.digits
length = 20
password = ''.join(choice(chars) for _ in range(length))
print "%s : %s" % (username, password)

user = PasswordUser(models.User())
user.username = username
user.email = email
user.password = password
session = settings.Session()
session.add(user)
session.commit()
session.close()

exit()

