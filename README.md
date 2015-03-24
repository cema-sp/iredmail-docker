# iRedMail Docker Container #
## Information ##

This project uses [iRedMail-0.9.0][1] (as on 02/2015) with:

* iRedAdmin-0.4.1
* iRedAPD-1.4.4
* roundcubemail-1.0.4

## What is inside ##

Image builds with:  

* Debian Wheezy
* OpenLDAP
* Apache
* Roundcube
* SOGo
* MySQL

## Building image ##
### 1. Editing iRedMail config file ###

You have to edit *files/config.example* file:  

1. Rename *files/config.example* to *files/config*
2. Replace "example.com" with your domain (lines marked with "!")
3. Replace "password_pm", "password_ldap", "password_db" with postmaster password, 
ldap manager password, DBA password (lines marked with "!!")__*__
4. Replace "password_random" with line from `date | sha256sum | base64 | head -c 30 ; echo` 
(lines marked with "!!!")
5. Remove all "!" signs from file

__*__ - _It is strongly recommended to use random passwords_

### 2. Editing hostname & uname fakes ###

You have to edit *files/hostname.example* and *files/uname.example* files 
by changing hostnames in them and renaming files (removing *.example* 
from their names).  

### 3. Editing Dockerfile ###

You have to edit *Dockerfile.example*:  

1. Rename *Dockerfile.example* to *Dockerfile*
2. Replace hostname and passwords near **TODO** comments with yours

### 4. (Optional) Configure mail users ###

You can add initial mail users to OpenLDAP:  

1. Rename *mail_users.csv.example* to *mail_users.csv*
2. Fill this file with data (see below)
3. For passwords please use `date | sha256sum | base64 | head -c 8 ; echo`

> CSV file format:  
>  domain name, username, password, [common name], [quota_in_bytes], [groups]  
>
> Example:
>> iredmail.org, zhang, plain_password, Zhang Huangbin, 104857600, group1:group2  
>> iredmail.org, zhang, plain_password, Zhang Huangbin, ,  
>> iredmail.org, zhang, plain_password, , 104857600, group1:group2  
>     
> Note:  
> - Domain name, username and password are REQUIRED, others are optional:  
>    + common name.  
>        * It will be the same as username if it's empty.  
>        * Non-ascii character is allowed in this field, they will be  
>          encoded automaticly. Such as Chinese, Korea, Japanese, etc.  
>    + quota. It will be 0 (unlimited quota) if it's empty.  
>    + groups.  
>        * valid group name (hr@a.cn): hr  
>        * incorrect group name: hr@a.cn  
>        * Do *NOT* include domain name in group name, it will be  
>          appended automaticly.  
>        * Multiple groups must be seperated by colon.  
> - Leading and trailing Space will be ignored.  

### 5. (Optional) Configure mail lists, modify users, tool ###

You can add mail lists by placing your _*.ldif_ files 
into *files/ldifs* directory and naming them like *10_any_name.ldif*.  
Moreover, you can place there any _*.ldif_ you like naming it *30_name.ldif*.  
To prepare your ldif files read corresponding [iRedMail docs][2].  
You can copy any necessary tools to *files/tools* directory to be added to image.  

### 6. (Optional) Replacing sources.list ###

File *sources.list.ru* contains sources list for Russia, 
you could replace it with more adequate fro your region.

### 7. Building image ###

To build image, run:  
```bash
sudo docker build -t cema/iredmail:latest .
```

## Running image ##
### Running with docker run ###

To run image use command:  
```bash
sudo docker run -d -P -h mail.example.com \
  -v /opt/containers/iredmail/backups/:/backups \
  --name iredmail cema/iredmail:latest /sbin/init 2
```

Where */opt/containers/iredmail/backups/* is backups path in which 
containers */var/vmail/* directory copied.

### Running with docker-compose ###
To run image with docker-compose you have to modify *docker-compose.yml.example* file:

1. Rename file to *docker-compose.yml*
2. Replace image name if you have changed it
3. Replace hostname and domainname in file

After all run `sudo docker-compose up -d`

## Postinstall ##

After starting up container:

1. Set up DNS records (A, MX, SPF and DKIM) (see [docs][3]).  
  To get DKIM use:  

    ```bash
    sudo docker exec docker_mailserver_1 amavisd-new showkeys
    ```

  To check it use:  

    ```bash
    sudo docker exec docker_mailserver_1 amavisd-new testkeys
    ```

2. (Optional) if you use [jwilder/nginx-proxy][4], copy container certs with commands:  

    ```bash
    sudo docker cp docker_mailserver_1:/etc/ssl/certs/iRedMail.crt \
      /opt/docker/mail-server/certs/
    sudo docker cp docker_mailserver_1:/etc/ssl/private/iRedMail.key \
      /opt/docker/mail-server/certs/
    sudo mv /opt/docker/mail-server/certs/{iRedMail,mx.example.com}.crt
    sudo mv /opt/docker/mail-server/certs/{iRedMail,mx.example.com}.key
    ```


## Testing container ##
### From inside container ###

Enter container:  
```bash
sudo docker exec -it iredmail /bin/bash
```

**Check Manager password**  
`ldapwhoami -x -D 'cn=Manager,dc=example,dc=com' -W`  

**Check added domains**  
`ldapsearch -D 'cn=Manager,dc=example,dc=com' -b 'o=domains,dc=example,dc=com' -W`  

**See users of domain**  
```bash
ldapsearch -D 'cn=Manager,dc=example,dc=com' \
  -b 'ou=Users,domainName=example.com,o=domains,dc=example,dc=com' -W
```

**Check user password**  
```bash
ldapsearch -D 'mail=postmaster@example.com,ou=Users,\
  domainName=example.com,o=domains,dc=example,dc=com' \
  -b 'ou=Users,domainName=example.com,o=domains,dc=example,dc=com' -W
```

### From outside container ###

**Check LDAP**  
`curl ldap://0.0.0.0:49258 -v`  
or  
```bash
curl -u uid=postmaster:password \
  ldap://0.0.0.0:49258/ou=Users,domainName=example.com,\
  o=domains,dc=example,dc=com -v
```

**Check SMTP**  
```bash
curl smtp://0.0.0.0:49251 --ssl -k \
  -u postmaster@example.com:password 
  -v --mail-rcpt "postmaster@example.com" --anyauth
```

## Maintaining container ##
### Reading log files ###

Enter container:  
```bash
sudo docker exec -it iredmail /bin/bash
```

Then use `tail -f -n30 /var/log/logfilename` to read *logfilename*.

### Geting backups from container manualy ###

Run:  
`sudo docker cp iredmail:/var/vmail/* /opt/containers/iredmail/backups/`

## May be useful ##
### Creating SSHA password ###

**Create SSHA password (w/o slap utils)**  
```bash
#!/bin/sh
# http://wiki.nginx.org/Faq#How_do_I_generate_an_htpasswd_file_without_having_Apache_tools_installed.3F
 
PASSWORD=$1;
SALT="$(openssl rand -base64 3)"
SHA1=$(printf "$PASSWORD$SALT" | openssl dgst -binary -sha1 | sed 's#$#'"$SALT"'#' | base64);
 
printf "{SSHA}$SHA1\n"
```

**Create SSHA password (w slap utils)**  
```bash
slappasswd -s passphrase
```

**Create SSHA password (w iRedMail tools)**  
```bash
python /opt/itools/generate_password_hash.py SSHA passphrase
```

### Encrypting/Decrypting files ###

**Encrypt/Decrypt iRedMail.tips file**  
```bash
echo 'passphrase' | openssl enc \
  -in /opt/iredmail/iRedMail.tips \
  -out /opt/iRedMail.tips.enc \
  -e -aes256 -pass stdin
echo 'passphrase' | openssl enc \
  -in /opt/iRedMail.tips.enc \
  -out /opt/iRedMail.tips \
  -d -aes256 -pass stdin
```



[1]: http://www.iredmail.org "iRedMail"
[2]: http://www.iredmail.org/docs "iRedMail docs"
[3]: http://www.iredmail.org/docs/setup.dns.html "iRedMail docs"
[4]: https://github.com/jwilder/nginx-proxy "Docker Nginx proxy"
