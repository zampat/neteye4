### Tuning of settings for ideal performance 

Update local dnf repo mapping to point to internal pulp
'''
ansible-playbook -i inventory/neteye_vms.ini neteye_module_settings_tuning.yum
'''

Arguments for running playbook:
-v to run in debug mode
