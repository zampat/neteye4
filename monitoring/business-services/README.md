# Business Services Monitoring

Plugin providing a dynamic approach to aggregate the status of monitored objects. With this approach you can realize a form of Business Service by aggregating the status of objects ( hosts or services ) based on object's attributes. 

ADVICE: This section is considered "work in progress"

## Feature description

The plugin allows the definition of filter expressions to group Icinga2 objects using the Icinga DSL query language
Example: match all hosts having name "*neteye*"
```
match("*1401*",host.name)
```

Aggregators:
- `AND`    All objects must be ok, the worst status is extracted as return value
- `OR`     At least one object must be ok, the best status is extracted as return value
- `NOT`    Inverted logic of ANY, none must be ok
- `DEG`    For service only: Critical status is degraded to warning
- `MINn`   Like OR, just with a condition for having at least n objects ok


## Content of this folder for dynamic business services monitoring:
- plugin scripts
- service templates
- virtual python environment for running the check. Consider creating your own virtual environment instead.


## Legacy Neteye 3 Business Service Status aggregation check

Contents introduced in NetEye Blog article [IT Service Status Aggregation for Distributed Monitoring Scenarios](https://www.neteye-blog.com/2018/09/it-service-status-aggregation-for-distributed-monitoring-scenarios/) has been moved into a [dedicated section in Repository of Neteye 3](https://github.com/zampat/neteye3/tree/master/business-services/)

