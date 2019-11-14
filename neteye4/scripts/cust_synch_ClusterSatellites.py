#!/bin/python

# Script action: 
# Syncronize the any customer data to all cluster nodes and satellites
# Using rpm function: 
#

import subprocess

# Python3 code to iterate over a list 
hosts = ["neteye02p", "neteye03p", "neteye04p"] 
files = ["/neteye/local/icinga2/conf/icinga2/conf.d/service_apply.conf",
         "/neteye/shared/monitoring"] 
   
# Using for loop 
for host in hosts: 
    for file in files: 
       print ("Sending " + file + " to " + host) 

       # assemble rsync commandline and run it
       rsynccmd  = 'rsync -av ' + file + ' ' + host + ':' + file
       print ("Run command: " + rsynccmd)
       rsyncproc = subprocess.Popen(rsynccmd,
                                       shell=True,
                                       stdin=subprocess.PIPE,
                                       stdout=subprocess.PIPE,
       )

       # read rsync output and print to console
       log = ""
       while True:
           next_line = rsyncproc.stdout.readline().decode("utf-8")
           if not next_line:
               break
           log += next_line

       print "Output: " + log

       # wait until process is really terminated
       exitcode = rsyncproc.wait()
