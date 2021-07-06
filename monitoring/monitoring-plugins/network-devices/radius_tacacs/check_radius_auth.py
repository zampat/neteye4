#!/usr/bin/python3
#
# Check script to check RADIUS authentication against a server
#
# Saskia Oppenlaender, 6.7.2021 v0.1

import radius
import sys, getopt
from pprint import pprint

# Get options
argv = sys.argv[1:]
host = ''
username = ''
password = ''
secret = ''
port = ''
try:
   opts, args = getopt.getopt(argv,"h:u:p:s:P:",["username=", "host=", "password=", "secret=", "port="])
except getopt.GetoptError:
   print("check_radius_auth.py -h <host> -u <username> -p <password> -s <secret> {-P <port}")
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
   elif opt in ("-P", "--port"):
      port = arg


# Check if necessary options are set
if(host == "" or username == "" or password == "" or secret == ""):
    print("Missing mandatory parameters!")
    print("check_radius_auth.py -h <host> -u <username> -p <password> -s <secret>")
    sys.exit(3)

if(port == ""):
    port = 1812
# initialize RADIUS
try:
    r = radius.Radius(secret, host, port, 1, 3)
except:
    print("Error connecting to RADIUS server")
    exit(3)

# authenticate user and pass
try:
    authen = r.authenticate(username=username, password=password)
except:
    print("Error trying authentication")
    exit(3)


if(authen):
    print("OK")
    exit(0)
else:
    print("Authentication failed")
    exit(3)
