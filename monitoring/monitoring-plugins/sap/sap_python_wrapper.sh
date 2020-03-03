#!/bin/bash
# IDEA: Activate virtualenv, execute command, deactivate virtualenv


/opt/neteye/saprfc/bin/python /neteye/shared/monitoring/plugins/saprfc/old_perl_scripts/check_sap_rfc.py "$@"
exit $?