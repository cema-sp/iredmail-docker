#!/bin/bash

# **********************************************************
# Add crontab job for root user (or whatever user you want):
# 
# crontab -e -u root
#
# # iRedMail: Backup LDAP, MySQL, VMAIL on 04:00 AM
# 0   4   *   *   *   /bin/bash /var/vmail/backup/backup.sh
#
# OR
#
# echo '0   4   *   *   *   /bin/bash /var/vmail/backup/backup.sh' \
#   > /etc/cron.d/backup
# **********************************************************

rsync -ravzX --delete /var/vmail/ /backups 2>&1 >> /backups/backup.log

# Remove files oldef than 14 days
find /var/vmail/backup/ldap/* -mtime +14 -exec rm {} \; 2>&1 >> /backups/backup.log
find /var/vmail/backup/mysql/* -mtime +14 -exec rm {} \; 2>&1 >> /backups/backup.log
