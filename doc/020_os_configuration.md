# NetEye operating system setup

## Accessing the system
Access the console via monitor and keyboard in case of hardware, via VM console in case of virtual environment.
The default credential must be changed after login (enforced by system policy)
```
user: root
password: admin
```

## Configure OS

NetEye 4 provides a logic to automate many setup tasks. Basic OS configurations are still required:
- System Hostname and DNS registration
- Timezone
- Network configuration
- Mail relay
- Customize credentials

Important Information on Host Names
NetEye 4 uses encrypted communications everywhere.  One of the parameters for the certificates is the host name.  This means that if you have a typo when you enter the host name, or use upper case one time and lower case another, then the certificate will not be accepted and communication with the server will not be possible.

