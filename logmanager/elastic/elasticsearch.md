## Reference of useful elastic queries

Query to see cluster health:

**TODO: Adapt ssl authentication for NetEye 4**

```
neteye01]:/elastic-data# curl http://localhost:9200/_cluster/health?pretty=true
{
  "cluster_name" : "neteye-elasticsearch",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 2,
  "number_of_data_nodes" : 2,
  "active_primary_shards" : 2,
  "active_shards" : 4,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0
}
```

## Backup and Restore

[Reference blog post about snapshot and restore](https://www.elastic.co/blog/introducing-snapshot-restore).


```/data/backup/elastic_snapshot```

Define Backup path in elastic Configuration:

```
[root@neteye_ZAPA elastic_backup]# cat /etc/elasticsearch/etc/elasticsearch.yml | grep repo
path.repo: /data/backup/elastic_backup
```

Register Backup:
```
curl -XPUT 'http://localhost:9200/_snapshot/elastic_backup' -d '{  "type": "fs",  "settings": {    "location": "/data/backup/elastic_snapshot",    "compress": true  }}'
```
Run Backup
```
curl -XPUT "localhost:9200/_snapshot/elastic_backup/snapshot_1?wait_for_completion=true"
```

Remove a snapshot:
```
curl -XDELETE "localhost:9200/_snapshot/elastic_backup/snapshot_1?pretty"
```
