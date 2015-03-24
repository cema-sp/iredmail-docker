# iRedMail Docker Container #

This is **_example_** of [iRedMail][1] Docker Container built 
from [cema-sp/iredmail-docker][2] GitHub source just for proof of concept.  
For further information go to [cema-sp/iredmail-docker][2] 
and build your own image.  

What is inside:  

* Debian Wheezy
* OpenLDAP
* Apache
* Roundcube
* SOGo
* MySQL


*Image size: ~800Mb.*  

## Try it ##

1. **Pull it**:  

    ```bash
    sudo docker pull cema/iredmail:example
    ```

2. **Run it**:  

    ```bash
    sudo docker run -d -p 10443:443 -P -h mail.example.com cema/iredmail:example init 2
    ```

3. **Try it**:  
    In your browser: [https://localhost:10443/mail](https://localhost:10443/mail)  
    With login: postmaster@example.com  
    And password: password_pm

[1]: http://www.iredmail.org/ "iRedMail"
[2]: https://github.com/cema-sp/iredmail-docker "cema/iredmail-docker"
