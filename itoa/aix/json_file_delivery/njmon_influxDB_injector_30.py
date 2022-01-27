#!/usr/bin/python3
# This takes njmon output JSON files and uploads the stats into InfluxDB
# NOTE YOU NEED TO CHANGE THIS FILE FOR
# Your InfluxDB hostname or localhost
# Your InfluxDB username and password
# Your InfluxDB database (bucket) name as created in the influx command "create database xxx" 
# To decide it this is for file loading in bulk batch=True or real-time adding stats as they arrive batch=False
# This version 
## ignores the now optinal the "sample": [ and ] lines
## for AIX renames some stats like logical_cpu becomes cpu_logical so all cpu stats in a pop down lits are together
## handles sub-sections for cpus, disks, networks, filesystem etc. as tags for much better handling with Grafana GroupBY

import sys
import json
import datetime

host="localhost"
port=8086
user = 'Nigel'
password = 'SECRET'
dbname = 'njmon30aix'

batch = True
#batch = False

def log(string1,string2):
    debug = False    # move the comment # to switch on
    #debug = True
    if debug:
        logger(string1,string2)

def logger(string1,string2):
    with open('injector.log','a') as f:
        f.write(string1 + ":" + string2 + "\n")
    return

taglist = {}
first_time = True
serial_no = 'NotKnown'
mtm = 'NotKnown'

def inject_snapshot(sample):
    global taglist
    global first_time
    global serial_no
    global mtm
    global os_name
    global arch
    timestamp = sample["timestamp"]["UTC"]
    log("timestamp",timestamp)
    if first_time == True:
        first_time = False

        try:
            os_name = sample["config"]["OSname"]
            arch = sample["config"]["processorFamily"]
            mtm = sample["server"]["machine_type"]
            serial_no = sample["server"]["serial_no"]
            aix = True
        except: # Not AIX imples Linux
            os_name = sample["os_release"]["name"]
            if os_name == "Red Hat Enterprise Linux Server":
                os_name = "RHEL"
            if os_name == "SUSE Linux Enterprise Server":
                os_name = "SLES"
            arch = "unknown"
            aix = False

        if aix == False:
            try:            # Linux under PowerVM
                serial_no = sample['ppc64_lparcfg']['serial_number']
                mtm = sample['ppc64_lparcfg']['system_type']
            except:
                serial_no = "unknown"
                mtm = "unknown"
        if arch == "unknown":
            try:
                arch = sample['lscpu']['architecture']
            except:
                arch = "unknown"

        if serial_no == "unknown":
            try:
                serial_no = sample['identity']['serial-number']
            except:
                serial_no = "unknown"

        if mtm == "unknown":
            try:
                mtm = sample['identity']['model']
            except:
                mtm = "unknown"

        mtm    = mtm.replace('IBM,','')
        serial_no = serial_no.replace('IBM,','')
        print("os_name:%s"%(os_name))
        print("architecture:%s"%(arch))
        print("mtm: %s"%(mtm))
        print("serial_no: %s"%(serial_no))

    for section in sample.keys():
        log("section", section)
        for sub in sample[section].keys():
            log("members are type", str(type(sample[section][sub])))
            if type(sample[section][sub]) is dict:
                fieldlist = sample[section][sub]
                measurename = str(section)
                # Rename so all the cpu stats start "cpu..."
                if measurename == "logical_cpu": measurename = "cpu_logical"
                if measurename == "physical_cpu": measurename = "cpu_physical"
                name = measurename
                if name[-1] == "s": # has a training "s" like disks or networks
                    name = name[0:-1] + "_name" # remove the trailing "s"
                else:
                    name = name + "_name"
                taglist = {'host': sample['identity']['hostname'], 'os': os_name, 'architecture': arch, 'serial_no': serial_no, 'mtm': mtm, name: sub }
                measure = { 'measurement': measurename, 'tags': taglist, 'time': timestamp, 'fields': fieldlist }
                entry.append(measure)
            else:
                fieldlist = sample[section]
                measurename = str(section)
                # Rename so all the cpu stats start "cpu..."
                if measurename == "total_logical_cpu": measurename = "cpu_logical_total"
                if measurename == "total_physical_cpu": measurename = "cpu_physical_total"
                if measurename == "total_physical_cpu_spurr": measurename = "cpu_physical_total_spurr"
                taglist = {'host': sample['identity']['hostname'], 'os': os_name, 'architecture': arch, 'serial_no': serial_no, 'mtm': mtm }
                measure = { 'measurement': measurename, 'tags': taglist, 'time': timestamp, 'fields': fieldlist }
                entry.append(measure)
                break
    return sample['identity']['hostname']

def push(host):
    if len(entry) >= 1:
        if client.write_points(entry) == False:
            logger("write.points() to Influxdb failed length=", str(len(entry)))
            logger("FAILED ENTRY",entry)
        else:
            now = datetime.datetime.now()
            logger(now.strftime("%Y-%m-%d %H:%M:%S") + " -- Injected snapshot " + str(count) + " for " + host + " Database",  str(dbname))
            entry.clear()
    return

#  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Login to InfluxDB
#  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
from influxdb import InfluxDBClient
client = InfluxDBClient(host, port, user, password, dbname)

count = 0
saving = 0
text = ""
cached = 0
entry = []

for line in sys.stdin:
    log("INPUT line",line)
    if line[0:3] == "  {":
        saving=1
    if saving and line[0:3] == "  }":
        count=count+1
        saving=0
        text=text + "}"
        log("Sample Dictionary TEXT size ",str(len(text)))
        host = inject_snapshot(json.loads(text))
        if batch:
            cached = cached + 1
            if cached == 100:
                #print("push count=%d cache=%d"%(count, cached))
                push(host)
                cached=0
        else:
            push(host)
        text=""
    if saving:
        text=text+line

push(host)
