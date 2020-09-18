#!/bin/bash

su - svnadmin -c "svnserve -d -r /srv/svn"
/usr/sbin/sshd -D
