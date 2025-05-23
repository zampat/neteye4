### Würth Internal commands. Repository and update procedures for test environments only

Update local dnf repo mapping to point to internal pulp
'''
ansible-playbook -i inventory/neteye_vms.ini point_repos_to_internal_pulp.yml
'''

Arguments for running playbook:
-v to run in debug mode
