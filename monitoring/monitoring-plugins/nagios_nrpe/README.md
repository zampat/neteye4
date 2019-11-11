# Security advice for using NRPE

The NRPE is an old protocol used in the Nagios world to communicate to remote Nagios NRPE agents.
The protocol design has security weaknesses and lacks a reliable encryption and authentication handshake mechanism.

Therefore it is NOT suggested to use NRPE as communication protocol for NetEye.
Anyway there might be situations where NRPE is the only suitable solution for monitoring remotely systems ( i.e. icinga agents is not provided for the environment and compiling it results difficult ) and the provided `check_nrpe` could be used on NetEye 4 to handle this exceptional cases. 
