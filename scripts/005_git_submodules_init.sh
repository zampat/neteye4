#!/bin/bash

echo "[i] 005: Initializing git submodules"
#init provided submodules
git submodule init

#update provided submodules
git submodule update
