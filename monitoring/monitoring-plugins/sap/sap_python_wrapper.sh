#!/bin/bash
# IDEA: Activate virtualenv, execute command, deactivate virtualenv


source /opt/neteye/saprfc/bin/activate

python /neteye/shared/monitoring/plugins/saprfc/old_perl_scripts/check_sap_rfc.py "$@" 
result=$?

deactivate

exit $result
