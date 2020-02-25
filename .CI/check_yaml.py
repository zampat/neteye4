import sys
import yaml
import os

for root, dirs, files in os.walk(sys.argv[1]):
    for f in files:
        if f.endswith(".yml"):
            my_file = os.path.join(root, f)
            print("Checking if {} is a valid yaml".format(my_file))
            yaml.safe_load(open(my_file))