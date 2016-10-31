#!/usr/bin/python
# https://airflow.incubator.apache.org/security.html

import airflow
from airflow import models, settings
from airflow.contrib.auth.backends.password_auth import PasswordUser

# https://stackoverflow.com/questions/3854692/generate-password-in-python
import string
from random import sample, choice
chars = string.letters + string.digits
length = 20
password = ''.join(choice(chars) for _ in range(length))

user = PasswordUser(models.User())
user.username = 'admin'
user.email = 'admin@example.com'
#user.password = 'set_the_password'
user.password = password
session = settings.Session()
session.add(user)
session.commit()
session.close()

print "%s : %s" % (user.username, password)
exit()

