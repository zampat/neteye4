# HTTP Web Monitoring

## Web service with kerberos authentication

To monitor web service with kerberos authentication, a dedicated curl check allows to make use of
- a provided keytab file providing the krb principal
- the feature the initialize the ticket grant
- the call of the web service
- a comparision of provided http string
- destroy of kerberos ticket

### Setup and configuration

Configuration of global kerberos settings:
define: default_realm value
```
# cat /etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = MYDOMAIN.LAN
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 kdc_timesync = 1
 ccache_type = 4
 proxiable = true

[realms]

[domain_realm]
```

[Prepare adding principal to keytab file using ktutil.](https://web.mit.edu/kerberos/krb5-1.12/doc/admin/admin_commands/ktutil.html)
[Howto reference](https://kb.iu.edu/d/aumh)

```
# ktutil
ktutil:  list
slot KVNO Principal
---- ---- ---------------------------------------------------------------------
ktutil:  add_entry -password -p user_neteye_kerberos@mydomain.lan -k 1 -e arcfour-hmac-md5
Password for user_neteye_kerberos@mydomain.lan:
ktutil:  list
slot KVNO Principal
---- ---- ---------------------------------------------------------------------
   1    1      user_neteye_kerberos@mydomain.lan

ktutil:  write_kt /root/kerberos/keytab_neteye
ktutil:  exit

[root@neteye99 kerberos]# klist -k keytab_neteye
Keytab name: FILE:keytab_neteye
KVNO Principal
---- --------------------------------------------------------------------------
   1 user_neteye_kerberos@mydomain.lan
``` 

Test of kerberos ticket generation via kinit:
```
# kinit -t /root/kerberos/keytab_neteye user_neteye_kerberos@mydomain.lan -V
```

### Usage

```
./check_curl_krb5.sh -u https://myservice.mydomain.lan/Services/api/ping -k keytab_neteye -s desired_string
HTTP OK: desired_string was found in output file
```

