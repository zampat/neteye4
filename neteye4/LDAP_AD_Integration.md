# LDAPS Integration

When using provided resources for LDAP-AD integration there might be the PHP client certificate error.
[Here additional info regarding openldap usage](https://www.openldap.org/lists/openldap-technical/201110/msg00154.html)

To trust provided AD certificate ignoring CA root certificate errors add the `TLS_REQCERT` directive to `/etc/openldap/ldap.conf`
```
# echo "TLS_REQCERT allow" >> /etc/openldap/ldap.conf
```
