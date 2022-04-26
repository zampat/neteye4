# Configuring and testing api access

Configure api user object and detailed permissions 
```
# cat api-escal-user.conf
/**
 * The APIUser objects are used for authentication against the API.
 */
object ApiUser "api-user" {
  password = "hjdqAasdafUsdfsDXfa"
  // client_cn = ""

  permissions = [ "events/statechange","objects/query/host","objects/query/service","events/acknowledgementset","events/acknowledgementcleared","events/commentadded","events/commentremoved" ]
}
```

Define a Permission with a Filter on Object of Type array:
```
permission = "objects/query/Host"
filter= {{ "Monitoring_Group" in host.groups }}
```

Get all services:
```
# curl -k -s -G -u root:0123456789abcdefc 'https://localhost:5665/v1/objects/services' | jq
```
Read a specific service with special characters or spaces
```
# curl -k -s -G -u root:0123456789abcdefc 'https://localhost:5665/v1/objects/services' --data-urlencode 'service=myhost.lan!Processor_Interrupts/sec'
```
### Get event streams via post
[Icinga API Event Streams](https://icinga.com/docs/icinga2/latest/doc/12-icinga2-api/#icinga2-api-clients-event-streams)

