### Tuning of settings for ideal performance 

Adjust some settings and user properties for better operation.

To get an overview of the changes provided:
```
cat config.yml
```

Run playbook: 
```
ansible-playbook -i inventory/neteye_vms.ini neteye_user_preferences_set.yml
```

Arguments for running playbook:
-v to run in debug mode
