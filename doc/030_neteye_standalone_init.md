# NetEye node system setup - Assisted Setup

Proceed on neteye.guide section Getting Started for "Single nodes and satellites". Hint: [Link may change](https://neteye.guide/4.45/getting-started/system-installation/single-node-and-satellites.html)

The steps documented in user guide automate the setup. Commands:
```
# neteye install

# neteye start

# neteye status
```

## Adjust and customizations

### Tuning of settings of neteye modules
```
# cd ./neteye4/neteye4_operations/neteye_config_tuning
# ansible-playbook -i inventory/neteye_vms.ini neteye_module_settings_tuning.yum
```

## Login on NetEye web interface

Login following instructions in section on neteye.guide

[<<< Back to documentation overview <<<](./README.md)
