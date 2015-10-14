FROM debian:wheezy
MAINTAINER Semen Pisarev <s.a.pisarev@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
RUN echo "APT::Install-Recommends 0;" >> /etc/apt/apt.conf.d/01norecommends \
  && echo "APT::Install-Suggests 0;" >> /etc/apt/apt.conf.d/01norecommends

ENV IREDMAIL_VERSION 0.9.0

# TODO: Replace hostname
ENV HOSTNAME mx.example.com
ENV DOCKER_LDAP_DN dc=example,dc=com

# Local sources (for speed-up)
COPY ./sources.list.ru /etc/apt/sources.list
# Install some necessary packages
RUN echo 'deb http://inverse.ca/debian wheezy wheezy' > \
    /etc/apt/sources.list.d/00-inverse-ca.list \
  && apt-key adv --keyserver keys.gnupg.net --recv-key 0x810273C4 \
  && apt-get -q update \
  && apt-get install -y -q \
    apt-utils \
  && apt-get install -y -q \
    curl \
    wget \
    bzip2 \
    dialog \
    openssl \
    rsync \
    rsyslog \
    dovecot-core \
    dovecot-imapd \
    dovecot-ldap \
    dovecot-lmtpd \
    dovecot-managesieved \
    dovecot-mysql \
    dovecot-pop3d \
    dovecot-sieve \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /etc/apt/sources.list.d/00-inverse-ca.list

# Set working directory
WORKDIR /opt/iredmail

# Copy files, extract iRedMail, remove archive, copy & configure tools
COPY ./files ./

RUN wget -O - --no-check-certificate \
    https://bitbucket.org/zhb/iredmail/downloads/iRedMail-"${IREDMAIL_VERSION}".tar.bz2 | \
    tar xvj \
  && cp -rl iRedMail-"${IREDMAIL_VERSION}"/* . \
  && rm -rf iRedMail-"${IREDMAIL_VERSION}"* \
  && mkdir -p /opt/itools \
  && cp ./tools/* /opt/itools \
  && mkdir -p /var/vmail/backup \
  && mv ./backup.sh /var/vmail/backup \
  && sed -i 's/dc=example,dc=com/'"$DOCKER_LDAP_DN"'/' \
    /opt/itools/create_mail_user_OpenLDAP.py

# Fake `uname` and `hostname`
RUN mv /bin/uname /bin/uname_ \
  && mv /bin/hostname /bin/hostname_ \
  && cp -l ./hostname ./uname /bin/

# Set hostname
RUN echo $HOSTNAME > /etc/hostname \
  && echo $HOSTNAME > /etc/mailname \
  && mkdir -p /etc/apache2/ \
  && echo 'ServerName '$HOSTNAME > /etc/apache2/httpd.conf

# Make link to Apache log files
RUN rm -rf /var/www/apache2/ \
  && mkdir -p /var/log/apache2/www/ /var/www/ \
  && ln -s /var/log/apache2/www/ /var/www/apache2 \
  && chown -R www-data:www-data /var/www/ /var/log/apache2/

# Make ClamAV socket file (to avoid installation warning)
RUN touch /tmp/clamd.socket \
  && chmod -Rf 766 /tmp/clamd.socket

# Avoid getty errors in log files
RUN sed -ri 's/^[1-6]:[2-6]{2,4}:.*/#\0/' /etc/inittab

# Enable services startup during install, 
#   run iRedMail installation & remove unneeded, 
#   disable services startup during install
RUN sed -i 's/ 101/ 0/' /usr/sbin/policy-rc.d \
  && IREDMAIL_DEBUG='NO' \
    AUTO_USE_EXISTING_CONFIG_FILE=y \
    AUTO_INSTALL_WITHOUT_CONFIRM=y \
    AUTO_CLEANUP_REMOVE_SENDMAIL=y \
    AUTO_CLEANUP_REMOVE_MOD_PYTHON=y \
    AUTO_CLEANUP_REPLACE_FIREWALL_RULES=n \
    AUTO_CLEANUP_RESTART_IPTABLES=y \
    AUTO_CLEANUP_REPLACE_MYSQL_CONFIG=y \
    AUTO_CLEANUP_RESTART_POSTFIX=n \
    bash iRedMail.sh \
  && apt-get purge -y -q dialog apt-utils \
  && apt-get autoremove -y -q \
  && apt-get clean -y -q \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i 's/ 0/ 101/' /usr/sbin/policy-rc.d

# Create directory for LDIF files
RUN mkdir -p ldifs

# Create users from mail_users.csv
RUN if [ -e mail_users.csv ]; \
    then \
      python /opt/itools/create_mail_user_OpenLDAP.py ./mail_users.csv \
      && mv ./mail_users.csv.ldif ldifs/20_mail_users.ldif; \
    fi

# Run slapd as root
RUN rm -rf /etc/ldap/slapd.d \
  && sed -i 's/openldap/root/g' /etc/default/slapd

# Limit slapd memory (see https://github.com/cema-sp/iredmail-docker/issues/3)
RUN sed -ri 's/^PATH/ulimit -n 1024\nPATH/' /etc/init.d/slapd

# TODO: Replace ldap password (LDAP_ROOTPW)
# Copy initial ldif and add all ldifs to ldap
RUN cp /opt/iredmail/conf/ldap_init.ldif ldifs/00_ldap_init.ldif \
  && service slapd start \
  && for f in ldifs/*.ldif; \
  do \
    ( ldapadd -D 'cn=Manager,'"$DOCKER_LDAP_DN" -w password_ldap -f "$f" || \
    ldapmodify -v -D 'cn=Manager,'"$DOCKER_LDAP_DN" -w password_ldap -f "$f" ); \
  done

# Encrypy iRedMail.tips
# TODO: Replace tips password (random)
RUN echo 'password' | \
    openssl enc -in /opt/iredmail/iRedMail.tips -out /opt/iRedMail.tips.enc \
    -e -aes256 -pass stdin

# Schedule backup script
RUN (crontab -l 2>/dev/null; \
  echo "0   4   *   *   *   /bin/bash /var/vmail/backup/backup.sh") | \
  crontab -

# Force users to change passwords
RUN echo "plugins.append('ldap_force_change_password_in_days')" \
    >> /opt/iredapd/settings.py \
  && echo "CHANGE_PASSWORD_DAYS = 365" >> /opt/iredapd/settings.py \
  && echo "CHANGE_PASSWORD_MESSAGE = 'Please change your password in webmail: https://$HOSTNAME/mail/'" \
    >> /opt/iredapd/settings.py

WORKDIR /opt

# Remove distr, return `uname` and `hostname`
RUN rm -rf /opt/iredmail /root/.bash_history \
  && rm -f /bin/uname /bin/hostname \
  && mv /bin/uname_ /bin/uname \
  && mv /bin/hostname_ /bin/hostname 

# Open Ports: 
# Apache: 80/tcp, 443/tcp Postfix: 25/tcp, 587/tcp 
# Dovecot: 110/tcp, 143/tcp, 993/tcp, 995/tcp OpenLDAP: 389/tcp, 636/tcp
EXPOSE 80 443 25 587 110 143 993 995 389 636

# Volume for backups
VOLUME /backups

# Start all services
CMD ["/sbin/init","2"]
