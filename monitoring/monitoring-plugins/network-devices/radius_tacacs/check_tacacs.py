#!/usr/bin/python3
#
# Check script to check status of TACACS server
#
# Saskia Oppenlaender, 6.7.2021 v0.1

from tacacs_plus.client import TACACSClient
import sys, getopt
import socket
from pprint import pprint

# Get options
argv = sys.argv[1:]
host = ''
username = ''
password = ''
secret = ''
try:
   opts, args = getopt.getopt(argv,"h:u:p:s:",["username=", "host=", "password=", "secret="])
except getopt.GetoptError:
   print("check_tacacs.py -h <host> -u <username> -p <password> -s <secret>")
   sys.exit(3)
for opt, arg in opts:
   if opt in ("-h", "--host"):
      host = arg
   elif opt in ("-u", "--username"):
      username = arg
   elif opt in ("-p", "--password"):
      password = arg
   elif opt in ("-s", "--secret"):
      secret = arg


# Check if necessary options are set
if(host == "" or username == "" or password == "" or secret == ""):
    print("Missing mandatory parameters!")
    print("check_tacacs.py -h <host> -u <username> -p <password> -s <secret>")
    sys.exit(3)

# initialize TACACS
try:
    cli = TACACSClient(host, 49, secret, timeout=10, family=socket.AF_INET)
except:
    print("Error connecting to TACACS server")
    exit(3)

# authenticate user and pass
try:
    authen = cli.authenticate(username, password)
except:
    print("Error trying authentication")
    exit(3)


if(authen.valid):
    print("OK")
    exit(0)
else:
    print("Authentication failed")
    exit(3)
