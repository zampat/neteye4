### Tuning of settings for ideal performance 

Adjust settins of modules for better performance 

Configurations changed from settings in config.yml
- keycloak: Raise JVM limit from MIN 64m MAX 512m


```
ansible-playbook -i inventory/neteye_vms.ini neteye_module_settings_tuning.yum
```

Arguments for running playbook:
-v to run in debug mode
