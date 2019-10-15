#!/usr/bin/python

import argparse
import datetime
import json
import logging
import shelve
import sys
import time

import requests
import urllib3


parser = argparse.ArgumentParser()
parser.add_argument("-H", action="store", dest="icinga_server")
parser.add_argument("-u", action="store", dest="username")
parser.add_argument("-p", action="store", dest="password")
parser.add_argument("-c", action="store", dest="cache_file")
parser.add_argument("-f", action="store", dest="host_filter")

arguments = parser.parse_args()

icinga_server        = arguments.icinga_server
icinga_api_username  = arguments.username
icinga_api_password  = arguments.password
local_cache_filename = arguments.cache_file
hostname_filter      = arguments.host_filter

#Icinga API Username and password
#icinga_api_username = "root"
#icinga_api_password = "45fc50c9c9d1b157"
#Host name used to restrict services to those hosts implementing serialized services
#hostname_filter     = 'dummy-host1*'
#Number of seconds the script will wait when the local services cache is empty.
#This waiting will not happen in case both Icinga2 service cache and local services cache are empty
wait_time_on_empty_cache = 60
#Full path to local cache file (cache is managed via shelve)
#local_cache_filename = 'cache.db'
#Title of the local cache. Please do not change: previously cached data will become unreadable.
local_cache_name = 'cached_services'

STATUS_OK       = 0
STATUS_WARNING  = 1
STATUS_CRITICAL = 2
STATUS_UNKNOWN  = 4

#Keeps track of service data and status
class service_status:
    def __init__(self, service_name, service_timeout, flag_value = 0):
        logging.debug("Creating new service instance.")
        logging.debug("Service name   : " + service_name         + ".")
        logging.debug("Service timeout: " + str(service_timeout) + ".")
        logging.debug("Flag value     : " + str(flag_value)      + ".")
        
        self.name         = service_name
        self.started      = False
        self.ended        = False
        self.start_time   = None
        self.timeout      = service_timeout
        self.flag_value   = flag_value

def print_performance_and_quit(status_code, performance):
    if ((status_code < 0) or (status_code > 3)):
        raise Exception("Unknown status code specified: " + str(status_code))

    status_literals = ("OK", "WARNING", "CRITICAL", "UNKNOWN")

    print(status_literals[status_code] + " - " + performance)
    sys.exit(status_code)

#Opens the local cache file using shelve functions
def open_local_cache(cache_filename):
    logging.info("Opening local cache file.")
    logging.debug("Local cache file name: " + cache_filename + ".")

    cache = shelve.open(cache_filename, writeback=True)

    logging.debug("Local cache file opened.")

    return cache

def get_service_flag_value(json_service):
    if (json_service["attrs"]["last_check_result"] == None):
        return 0

    return json_service["attrs"]["last_check_result"]["execution_end"]

#Creates a service from json returnet by requests module
def build_service_state(json_service):
    logging.debug("Reading service state from JSON data.")
    service_name    = json_service["attrs"]["__name"]
    service_timeout = json_service["attrs"]["check_timeout"]
    flag_value      = get_service_flag_value(json_service)

    logging.debug("JSON Service name   : " + service_name         + ".")
    logging.debug("JSON Service timeout: " + str(service_timeout) + ".")
    logging.debug("JSON Flag value     : " + str(flag_value)      + ".")

    return service_status(service_name, service_timeout, flag_value)

#Get services from Icinga2 using API, then create a service list
def read_services_from_icinga(server_name, username, password, hostname_filter = "*"):
    logging.info("Loading services data from Icinga2."      )
    logging.debug("Icinga2 server: " + server_name     + ".")
    logging.debug("Username      : " + username        + ".")
    logging.debug("Password      : ***."                    )
    logging.debug("Host filter   : " + hostname_filter + ".")
    
    #Preparing access data
    credentials = (username, password)
    request_url = 'https://' + server_name + ':5665/v1/objects/services'
    headers = {
        'Accept': 'application/json',
        'X-HTTP-Method-Override': 'GET'
    }
    data = {
        "filter": 'match("' + hostname_filter + '",host.name)&&match("true",service.vars.serializable)'
    }

    #Requesting services list ignoring HTTPS certificate verification
    logging.info("Invoking Icinga2 API via HTTP request.")
    response = requests.post(request_url,
                             headers=headers,
                             auth=credentials,
                             data=json.dumps(data),
                             verify=False)

    #In case the request goes wrong, an exception should be raised
    logging.info("HTTP response received.") 
    if (response.status_code != 200):
        logging.critical("KO response received from Icinga2 API.")
        logging.debug("HTTP Status code received: " + str(response.status_code) + ".")
        error_message = "Unable to retrieve json data from Icinga2 server.\n" + str(response)
        logging.critical(error_message)
        raise Exception(error_message)
    
    results = response.json()["results"]

    logging.info("Parsing HTTP response data.")
    services = {}
    count = int(0)
    for service in results:
        #Invoke a factory function to create a service state object
        service_status = build_service_state(service)
        services[service_status.name] = service_status
        logging.debug("Found service from Icinga2: " + service_status.name + ".")
        count += 1

    logging.debug("Got " + str(count) + " service(s) from Icinga2 server.")
    if (count == 0):
        logging.warning("No services data from Icinga2.")
    
    return services

#Create a service list based on contents cached by shelve module
def read_services_from_cache(cache_filename, cache_name):
    logging.info("Loading services data from local cache.")

    #Open local cache file
    global local_cache
    local_cache = open_local_cache(cache_filename)

    logging.debug("Searching for cached services list.")
    if (local_cache.has_key(cache_name)):
        logging.info("Found cached services data. Loading into memory.")
        services = local_cache[cache_name]

        count = int(0)
        for service_name in services:
            service = services[service_name]
            count += 1

        logging.debug("  Got " + str(count) + " service(s) from local cache.")
        if (count == 0):
            logging.warning("No services data from local cache.")
    else:
        logging.warning("Local cache is empty.")
        services = {}

    return services

#Add all services from source_list to target_list
def add_all_services(target_list, source_list):
    logging.debug("Add all source list's services to target list.")
    keys_list = source_list.keys()
    for service_name in keys_list:
        logging.debug("Service " + service_name + " is missing into target list. Adding.")
        target_list[service_name] = source_list[service_name]

#Add all services from source_list that are missing into tartet_list
def add_missing_services(target_list, source_list):
    logging.debug("Add source list's missing services to target list.")
    keys_list = source_list.keys()
    for service_name in keys_list:
        if (target_list.has_key(service_name) == False):
            logging.debug("Service " + service_name + " is missing into target list. Adding.")
            target_list[service_name] = source_list[service_name]

#Remove all services from target_list that are missing in source_list
#ONLY if the service has not yet started
def remove_extra_services(target_list, source_list):
    logging.debug("Remove from target list all services not presents inside source list.")
    keys_list = target_list.keys()
    for service_name in keys_list:
        if (target_list[service_name].started == False):
            if (source_list.has_key(service_name) == False):
                logging.debug("Service " + service_name + " is missing from source list and is not started yet. Removing from target list.")
                target_list.pop(service_name)

#Compare contents from local_services_list to contents from icinga_services_list
# - New service from icinga2 will be added
# - Missing services from icinga2 will be removed
# - Already run/running services will not touched
def update_services_list(local_services_list, icinga_services_list):
    logging.info("Updating services lists.")
    
    #Local serivces list empty can means two things:
    # 1 - All services has run once, then the list has been emptied
    # 2 - No services available from Icinga2 server
    #In case 1, a reload will suffice. In case 2, there is nothing to do; then exit with unknown state
    if(len(local_services_list) == 0):
        if (len(icinga_services_list) == 0):
            logging.critical("Icinga2 services list is empty. No services to run.")
            print_performance_and_quit(STATUS_UNKNOWN, "No service to run can be found")

        logging.debug("Adding all services from Icina2 list to local list.")
        add_all_services(local_services_list, icinga_services_list)
        print_performance_and_quit(STATUS_OK, "Services list has been rebuilt")

    #At this point, local services list contains at leas one runnable service
    #Now, a sync betweent the two services lists should be done
    logging.debug("Adding missing services.")
    add_missing_services (local_services_list, icinga_services_list)
    logging.debug("Removing not-started unnecessary services.")
    remove_extra_services(local_services_list, icinga_services_list)
    logging.info("Local services list updated.")

#Returns the first service in the list that has been started but has not ended yet
def look_for_running_service(services_list):
    logging.info("Searching for running services.")
    for service_name in services_list:
        service = services_list[service_name]
        if ((service.started) and (not (service.ended))):
            logging.info("Found a running service: " + service.name + ".")
            return service
        else:
            logging.debug("Service " + service_name + " is not running. Skipping.")
    
    logging.info("No running service found.")

    return None

#Just returns a service from a list based on a name
def get_service_by_name(services_list, service_name):
    if (services_list.has_key(service_name)):
        return services_list[service_name]

    return None

#Check a service execution state and, if it is not termianted, report the current state and exit
def report_service_execution_status_and_quit(running_service, service_data):
    service_name = running_service.name
    now = datetime.datetime.utcnow()    #Used in case of missing reference, to do timeout comparison

    logging.info("Checking if service " + service_name + " is still running.")

    ###ASSERTION: the service is acqually running
    if (running_service.start_time == None):
        raise Exception("No start date for service " + running_service.name + ". Maybe it has not yet started?")

    if(service_data == None):
        #In case no reference service data is provided, using timeout to determine if execution has ended.
        logging.info("No reference service data provided. Using timeout to determine execution status.")

        #Checking if execution timeout expired
        if(now >= running_service.start_time + datetime.timedelta(seconds=running_service.timeout)):
            #Timeout expired. Execution should (and must) be terminated
            running_service.ended = True
            logging.info("Service " + service_name + " timeout has expired. Reporting execution as ended.")
            print_performance_and_quit(STATUS_OK, "Service " + service_name + " execution has ended. Timed out expired.")
        else:
            #Timeout is not yet expired. Reporting exectution as running.
            logging.debug("Timeout not yet expired. To avoid possible issues of execution overlapping, waiting until timeout expires.")
            print_performance_and_quit(STATUS_OK, "Service " + service_name + " is still running (waiting for timeout).")

    else:
        #If reference data is provided, then a comparinson between flag values is done to determine if service execution has ended
        logging.debug("Reference data provided: comparing service flag values.")
        if (running_service.flag_value != service_data.flag_value):
            #SERVICE EXECUTION TERMINATED
            running_service.ended = True
            logging.info("Service " + service_name + " execution has ended.")
            print_performance_and_quit(STATUS_OK, "Service " + service_name + " execution has ended.")
        else:
            #SERVICE IS STILL RUNNING? Should check timeout expiration
            if(now >= running_service.start_time + datetime.timedelta(seconds=running_service.timeout)):
                #Timeout expired
                running_service.ended = True
                logging.info("Service " + service_name + " timeout has expired. Reporting execution as ended.")
                print_performance_and_quit(STATUS_OK, "Service " + service_name + " execution has ended. Timed out expired.")
            else:
                #Timeout not expired yet; service execution stil running
                logging.info("Service " + service_name + " is still running.")
                print_performance_and_quit(STATUS_OK, "Service " + service_name + " still running.")

#Search for a running service into the local service list.
#If one is found, check if the service is still running, then reports its state and exit
def wait_for_running_service_to_end(local_services_list, icinga_services_list):
    #Search for a running service. If a running service is found, updates its status and exits
    running_service = look_for_running_service(local_services_list)
    if (running_service != None):
        #Look for service data from Icinga2 services list
        service_data = get_service_by_name(icinga_services_list, running_service.name)

        #Check if the running service has completed its execution or if its timeout has expired, then updates the cached status value and exit
        report_service_execution_status_and_quit(running_service, service_data)

#Return the first service in the list having started attribute set to false
def get_startable_service(services_list):
    for service_name in services_list:
        service = services_list[service_name]
        if (service.started == False):
            return service

    return None

def set_service_as_started(service):
    logging.info("Mark service " + service.name + " execution as started.")
    service.started = True
    service.start_time = datetime.datetime.utcnow()

def start_service(server_name, username, password, service_to_start):
    logging.info("Trying to start Icinga2 service " + service_to_start.name + ".")
    logging.debug("HTTP request parameters:")
    logging.debug("Icinga2 server: " + server_name)
    logging.debug("Username      : " + username)
    logging.debug("Password      : ***")
    logging.debug("Service name  : " + service_to_start.name)

    #Preparing access data
    logging.info("Preparing request access data.")
    splitted = service_to_start.name.split('!')
    host_name    = splitted[0]
    service_name = splitted[1]

    credentials = (username, password)
    request_url = 'https://' + server_name + ':5665/v1/actions/reschedule-check'
    headers = {
        'Accept': 'application/json',
    }
    data = {
        "type"  : 'Service',
        "filter": 'match("' + host_name + '",host.name)&&match("' + service_name + '",service.name)',
        "force" : 'true'
    }

    #Requesting services list ignoring HTTPS certificate verification
    logging.info("Invoking Icinga API via HTTP request.")
    response = requests.post(request_url,
        headers=headers,
        auth=credentials,
        data=json.dumps(data),
        verify=False)

    #In case the request goes wrong, an exception should be raised
    logging.info("HTTP response received. Parsing data.") 
    if (response.status_code != 200):
        error_message = "Unable to reschedule service on Icinga. " + str(response)
        logging.info(error_message)
        raise Exception(error_message)

    set_service_as_started(service_to_start)
    
    logging.info("Service " + service_to_start.name + "started.")

#Look for the next service to be started, then start its execution
def start_next_service(local_services_list):
    #Pick one service that has not yet started from the local services list
    service_to_start = get_startable_service(local_services_list)

    #If a service is found, just start it then exit
    if (service_to_start != None):
        start_service(icinga_server, icinga_api_username, icinga_api_password, service_to_start)
        print_performance_and_quit(STATUS_OK, "Running service " + service_to_start.name)

    #In case no service is found, the current execution cycle is completed.
    #Local cache contents are no more necessaries: cache should be empty to force a reload from Icinga2
    logging.info("No more services to run. Clearing the cache to force reload from Icinga2.")
    local_services_list.clear()
    print_performance_and_quit(STATUS_OK, "No more services to run. Run cycle completed.")

def write_services_to_cache(shelve_cache, local_services_list):
    logging.info("Updating cache contents.")
    shelve_cache[local_cache_name] = local_services_list
    shelve_cache.sync()


if __name__ == '__main__':
    logging.basicConfig(level=logging.ERROR, format='[%(asctime)s][%(levelname)-8s] %(message)s')
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

local_cache = None

try:
    #Load services list from both local cache and Icinga2
    local_services  = read_services_from_cache(local_cache_filename, local_cache_name)
    icinga_services = read_services_from_icinga(icinga_server, icinga_api_username, icinga_api_password, hostname_filter)

    #Check and update local services list based on contents from Icinga2 services list:
    # - absent non-started services will be removed
    # - new services will be added
    # - already started services will be left as they are
    update_services_list(local_services, icinga_services)

    #Search for a running service.
    #If a running service is found, reports its status (terminated, timed out or still running) and exit
    wait_for_running_service_to_end(local_services, icinga_services)

    #Search for a service that as not yet started, and starts it
    start_next_service(local_services)

except SystemExit:
#Do nothing
    pass

finally:
    #Every time the script terminates, local services list should be written to cache file
    if (len(local_services) > 0):
        write_services_to_cache(local_cache, local_services)
        
    local_cache.close()

