#!/bin/bash

echo "[ ] Initializing git submodules"
#init provided submodules
git submodule init

#update provided submodules
git submodule update
