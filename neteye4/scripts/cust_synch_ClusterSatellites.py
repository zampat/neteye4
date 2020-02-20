#!/bin/python

# Script action: 
# Syncronize the any customer data to all cluster nodes and satellites
# Using rpm function: 
#

import subprocess
import os
import argparse

# Arguments

parser = argparse.ArgumentParser(description="Arguments")
parser.add_argument('--system-files', '-s', dest='system_files', help='Synch System Files', action='store_true')
parser.add_argument('--files', '-f', dest='files', help='Synch Files', action='store_true')
parser.add_argument('--remote-command', '-r', dest='remote_commands', help='Run Remote Command', action='store_true')

args=parser.parse_args()




# Python3 code to iterate over a list 
hosts = ["neteye02p", "neteye03p", "neteye04p"] 
system_files = ["/etc/hosts",
         "/etc/pki/tls/certs/*.crt",
         "/etc/pki/tls/private/*.key"
        ]
files = ["/neteye/shared/monitoring",
         "/neteye/local/icinga2/conf/icinga2/conf.d/dependency*"
        ]

remote_commands = ["icinga2 daemon --validate && systemctl reload icinga2"
    ]


# Using for loop 
def synch_files(hosts,files):

   for dst_host in hosts: 
       for file in files: 

	  # Distinguish between file or folder
	  if os.path.isfile(file):
             print ("Sending file:" + file + " to " + dst_host) 
             rsynccmd  = 'rsync -av ' + file + ' ' + dst_host + ':' + file

	  elif os.path.isdir(file):
	     dst_path = os.path.abspath(os.path.join("..", os.path.dirname(file)));

             print ("Sending directory:" + file + " to dst path: " + dst_path + " on host: " + dst_host) 
             rsynccmd  = 'rsync -av ' + file + ' ' + dst_host + ':' + dst_path

	  else:
	     dst_path = os.path.dirname(file)
             print ("Sending file:" + file + " to  dst path: " + dst_path + " on host: " + dst_host) 
             rsynccmd  = 'rsync -av ' + file + ' ' + dst_host + ':' + dst_path

          # assemble rsync commandline and run it
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


# Restart remote servcies
def run_remote_commands(hosts,remote_commands):

   for dst_host in hosts:
      for cmd in remote_commands:

	  # assemble ssh commandline and run it
          run_cmd  = 'ssh ' + dst_host + ' \'' + cmd + '\''
          print ("Would run remote command: " + run_cmd + " on host: " + dst_host)

          ssh_proc = subprocess.Popen(run_cmd,
                                       shell=True,
                                       stdin=subprocess.PIPE,
                                       stdout=subprocess.PIPE,
          )

          # read rsync output and print to console
          log = ""
          while True:
              next_line = ssh_proc.stdout.readline().decode("utf-8")
              if not next_line:
                  break
              log += next_line

          print "Output: " + log

          # wait until process is really terminated
          exitcode = ssh_proc.wait()




########################

#Synchronize files to all hosts
#synch_files(hosts,files)

#Run command on all hosts
#run_remote_commands(hosts,remote_commands)

if args.files is True:
    synch_files(hosts,files)

if args.remote_commands is True:
    run_remote_commands(hosts,remote_commands)
    
#if args.system_files is True:
#    xxxxxxx
