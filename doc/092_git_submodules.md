# Submodules: Integration of third-party repos into another repo

[Mastering Submodules](https://medium.com/@porteneuve/mastering-git-submodules-34c65e940407)

Clone repository with submodules automatically:
Note: neteye run_setup.sh initializes submodules.
```
git clone --recursive git@github.com:name/repo.git
```

## Add new submodules

Register a new submodule:
Example done for icinga2-powershell-module
```
git submodule add https://github.com/Icinga/icinga2-powershell-module monitoring/agents/microsoft/icinga/icinga2-powershell-module
```
