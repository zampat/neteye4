#!/usr/bin/python3
# This takes jnmon output JSON files and uploads the stats into InfluxDB
# NOTE YOU NEED TO CHANGE THIS FILE FOR
# You InfluxDB hostname
# Your InfuleDB username and password
# To decide it this is for file loading in bulk or real-time adding stats as they arrive

import sys
import json

def log(string1,string2):
    debug = False
    if debug:
        logger(string1,string2)

def logger(string1,string2):
    with open('injector.log','a') as f:
        f.write(string1 + ":" + string2 + "\n")
    return

taglist = []
first_time = True

def inject_snapshot(sample):
    global taglist
    global first_time
    timestamp = sample["timestamp"]["UTC"]
    log("timestamp",timestamp)
    if first_time == True:
        first_time = False

        try:
            os_name = sample["config"]["OSname"] 
            os_base = os_name + " " + str(sample["server"]["aix_version"]) 
            os_long = os_base + " TL" + str(sample["server"]["aix_technology_level"]) 
            os_long = os_long + " sp" + str(sample["server"]["aix_service_pack"])
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
            os_base = os_name + " " + sample["os_release"]["version_id"]

            os_long = sample["os_release"]["pretty_name"]
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
        #processor = "unknown"
        #if processor == "unknown":
        #    try:
        #        processor = sample['identity']['model']
        #    except:
        #        processor = "unknown"

        #try:
        #    xprocessor = sample['lscpu']['model_name'] 
        #except:
        #    xprocessor = "unknown"

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
        print("os_name:%s os_base:%s os_long:%s"%(os_name,os_base,os_long))
        print("arch:%s"%(arch))
        #print("processor:%s   xprocessor: %s"%(processor,xprocessor))
        print("mtm: %s"%(mtm))
        print("serial_no: %s"%(serial_no))

        taglist = {'host': sample['identity']['hostname'], 
                    'os':os_long, 
                    'os_name':os_name, 
                    'os_base':os_base, 
                    'architecture':arch, 
                    'serial_no': serial_no,
                    'mtm': mtm } 
        print(taglist)
        log("os_long",str(os_long))
        log("taglist",str(taglist))

    for section in sample.keys():
        log("section", section)
        for sub in sample[section].keys():
            log("members are type", str(type(sample[section][sub])))
            if type(sample[section][sub]) is dict:
                measurename = str(section) + "_" + str(sub)
                log("Measurement section and subsection", str(measurename));
                fieldlist = sample[section][sub]
                log("fieldlist", str(fieldlist))
                measure = { 'measurement': measurename, 'tags': taglist, 'time': timestamp, 'fields': fieldlist }
                log("SSS", "MMM")
                log("measure", str(measure))
                entry.append(measure)
            else:
                measurename = str(section)
                log("Measurement section", str(measurename))
                fieldlist = sample[section] 
                log("fieldlist", str(fieldlist))
                measure = { 'measurement': measurename, 'tags': taglist, 'time': timestamp, 'fields': fieldlist }
                log("MMM", "MMM")
                log("measure", str(measure))
                entry.append(measure)
                break
    return sample['identity']['hostname']

def push(host):
    if client.write_points(entry) == False:
        logger("write.points() to Influxdb failed length=", str(len(entry)))            
        logger("FAILED ENTRY",entry)            
    else:
        logger("Injected snapshot " + str(count) + " for " + host + " Database",  str(dbname))
        entry.clear()
    return

#  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
host="localhost"
port=8086
user = ''
password = ''
dbname = 'njmon'

from influxdb import InfluxDBClient
client = InfluxDBClient(host, port, user, password, dbname)

batch=True

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
exit()
