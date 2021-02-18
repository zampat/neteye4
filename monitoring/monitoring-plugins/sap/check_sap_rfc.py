#!/opt/neteye/saprfc/bin/python

# Author: Mirko Bez mirko.bez<at>wuerth-phoenix.com

import argparse
import logging
from typing import Dict, Any, List, Tuple, Optional

import yaml
import csv
import json
import sys
import re
import requests
import urllib3

from enum import Enum
from pyrfc import Connection
import datetime

class IcingaServiceStatus(Enum):
    OK = 0
    WARNING = 1
    CRITICAL = 2
    UNKNOWN = 3


class ArgumentParser(argparse.ArgumentParser):
    """Subclass of Argument Parser that overrides the exit status to Icinga's Unknown"""

    def error(self, message):
        print('%s: error: %s\n' % (self.prog, message))
        self.exit(IcingaServiceStatus.UNKNOWN.value)


def read_file(file_name: str) -> str:
    """
    Simple utility to read the content of a file

    :param file_name: the name of the file to read
    :return: the content of the file
    """
    with open(file_name, "r") as file_descriptor:
        content = file_descriptor.read()
        return content


def load_my_csv_configuration(filename: str, sysid: str, mandant: Optional[str], header: bool = True) -> Dict[str, str]:
    """Read the csv config. Reads entirely only the needed line"""
    with open(filename, "r") as fd:
        csv_reader = csv.reader(fd, delimiter=' ')
        # Skip the first line if header is true
        if header:
            next(csv_reader)
        conf = {}
        for row in csv_reader:
            if row[0] == sysid and (mandant is None or row[2] == mandant):
                # conf[key]["trace"] = "3"
                conf["sysid"] = row[0]
                conf["sysnr"] = row[1]
                conf["client"] = row[2]
                conf["user"] = row[3]
                conf["passwd"] = row[4]
                try:
                    conf["ashost"] = row[5]
                except KeyError:  # as host is an optional parameter
                    conf["ashost"] = row[0]
                if len(row) > 7:
                    conf["group"] = row[6]
                    conf["mshost"] =  conf["ashost"]
                    conf["msserv"] = "36" + conf["sysnr"]
                    conf["saprouter"] = row[7]
                    conf["language"] = "en"
                    conf["codepage"] = "4110"
                    conf.pop("ashost", None)
                break
        else:
            print(f"Check Unknown - Could not find configuration for sysid {sysid} and mandant {mandant}")
            sys.exit(IcingaServiceStatus.UNKNOWN.value)

    return conf


def get_check_status(result: Dict[str, Any]) -> int:
    """
    Return the status of the check
    """
    status: int = int(result["KPI"]["STATUS"])
    return status

def build_json_payload_alternative(args):
    data: Dict[str, Any] = dict()
    data["KPI"] = args.key_performance_indicator
    data["PARAMS"] = []
    logging.debug("INPUT PARAM: " + args.parameters)
    # Sample arguments:  "I_WORKPROCESS_TYPE=DIALOG;2" "it_WARNING_VALUE=;" "I_UPPER_BORDER=;" "I_CRITICAL_VALUE=0;"
    for p in args.parameters.split():
        if re.match(r"(\w*)=([^;]*;)+", p):
            # ['I_WORKPROCESS_TYPE', 'DIALOG;2']
            namevalues = p.split("=")
            # ['I_WORKPROCESS_TYPE']
            name = namevalues[0]
            # ['DIALOG;2'] --> split produces ['DIALOG', '2', ''] we get rid of the last spurious element
            values = namevalues[1].split(";")[:-1]
            data["PARAMS"].append({"NAME": name, "VALUE": [v.strip() for v in values]})
    return json.dumps(data)


def check_for_special_cases(result: Dict[str, Any]):
    logging.debug("Checking for special cases")
    if "KPI" not in result:
        print(json.dumps(result, indent=4))
        sys.exit(IcingaServiceStatus.UNKNOWN.value)

    kpi = result["KPI"]
    output = kpi["OUTPUT"]
    if "PERFORMANCE" not in result:
        print(output)
        if "STATUS" in kpi:
            sys.exit(int(kpi["STATUS"]))
        else:
            sys.exit(IcingaServiceStatus.UNKNOWN.value)


def send_to_webhook(args, result: List[Dict[str, Any]]):

    logger = logging.getLogger(__name__)
    conf = args.webhook_connection_configuration

    scheme = conf["scheme"]
    tornado_host = conf["hostname"]
    tornado_port = conf["port"]
    endpoint = conf["endpoint"]

    url = f"{scheme}://{tornado_host}:{tornado_port}/{endpoint}"
    logging.debug(url)

    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    sap_case = "usual"

    if len(result) > 0 and "SERVICE_NAME" in result[0] and "ABORTED_JOB" in result[0] and isinstance(result[0]["ABORTED_JOB"], list):
        
        tmp_result = result
        result = []
        for t in tmp_result:
            for aborted_job in t["ABORTED_JOB"]:
                result.append(
                    {
                        "SERVICE_NAME": t["SERVICE_NAME"],
                        **aborted_job
                    }
                )
        sap_case = "aborted_jobs"
          
    logger.debug(result)

        response = requests.post(
            url,
            params=conf["params"],
            verify=conf.get("verify", False),
            json={ 
                "host": args.sysid,
                "sap_case": sap_case,
                "sap_response": result
            }
        )

    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError as e:
        logger.info(e)
        print(f"Check Critical - Could not send data to the webhook. Error code: {response.status_code}")
        sys.exit(IcingaServiceStatus.CRITICAL.value)


def check_webhook_configuration(args):
    conf = {}

    if args.webhook_config:
        conf = yaml.load(read_file(args.webhook_config), Loader=yaml.Loader)
    if "params" not in conf:
        conf["params"] = {}
    if args.webhook_hostname:
        conf["hostname"] = args.webhook_hostname
    if args.webhook_endpoint:
        conf["endpoint"] = args.webhook_endpoint.strip()
    if args.webhook_port:
        conf["port"] = args.webhook_port
    if args.webhook_scheme:
        conf["scheme"] = args.webhook_scheme
    if args.webhook_token:
        conf["params"]["token"] = args.webhook_token
    
    if conf["endpoint"][0] == "/":
        conf["endpoint"] = conf["endpoint"][1:]

    try:
        # Check that the needed variables are defined
        conf["scheme"]
        conf["hostname"]
        conf["port"]
        conf["endpoint"]
        conf["params"]["token"]
    except KeyError:
        print("Check Unknown - Webhook connection information not sufficient.. specify them with the webhook_* options")
        
        sys.exit(IcingaServiceStatus.UNKNOWN.value)
    args.webhook_connection_configuration = conf


def reduce_special_cases_to_performance_data(input_performance_data: List[str]) -> List[str]:
    """
    Some checks are not developed internally in Wuerth IT. Therefore there are special
    cases that do not follow Nagios convention. This function reduces these (whitelisted) cases
    to the Nagios Format
    """
    # Heuristics to check if it is worth to perform expensive regexes
    if len(input_performance_data) == 1 and "Fehler" in input_performance_data[0] and "//" in input_performance_data[0]:
        output: List[str] = []
        input_performance_data = input_performance_data[0].split("//")
        for ipd in input_performance_data:
            res = re.match(r"Fehler \( \d+ \/ (.*) \): (\d+(\.\d+)?)", ipd.strip())
            if(res):
                key = res.groups()[0].replace(" (", "_").replace(")", "")
                value = res.groups()[1]
                output += [f"{key}={value}"]
        return output
    else:
        return input_performance_data


def prepare_icinga_output(result: Dict[str, Any], connection_performance_data: str) -> str:
    """
    Returns the status and the output string for icinga, following the nagios output format
    for performance data, see ref: https://nagios-plugins.org/doc/guidelines.html#AEN200
    """
    logger = logging.getLogger(__name__)
    kpi = result["KPI"]
    output = kpi["OUTPUT"]
    performance = reduce_special_cases_to_performance_data(result["PERFORMANCE"])
    logger.debug(result["PERFORMANCE"])
    logger.debug(performance)
    output_string = f"{output[0]} | "
    for p in performance:
        output_string += f"{p}"
        output_string += " "
    output_string += connection_performance_data
        
    return output_string


def parse_args():
    """
    Parse the command line input. It returns the list of arguments and the parameters
    """
    parser = argparse.ArgumentParser(description='RFC SAP')

    subparsers = parser.add_subparsers(help="Subcommands options")
    parser_healthcheck = subparsers.add_parser("healthcheck", description="Health Check")
    parser_kpi = subparsers.add_parser("kpi", description="Kpi")

    # Generic-Options
    for subparser in [parser_healthcheck, parser_kpi]:
       
        subparser.add_argument('--log_level', dest="logging_level", default="WARNING",
                            help="logging level", type=str),
        subparser.add_argument('--sap_config_file', dest="sap_config_file", default="nag_sap.cfg", type=str)

        subparser.add_argument('--sysid', '-s', dest='sysid', required=True, type=str, help="sysid, e.g. DE7\n")
        subparser.add_argument('--mandant', dest='mandant', required=False, type=str, help="mandant, e.g. 401\n")
        subparser.add_argument('--function', '-f', dest='function_name', required=True, type=str,
                               help="function, e.g. /WRP/NEMO_CENTRAL\n")
        subparser.add_argument('--timeout', '-t', dest='timeout', required=False, default=25, type=int,
                               help='timeout for the call (default 25)')

        


    # HealthCheck Specific
    parser_healthcheck.set_defaults(command="healthcheck")
    parser_healthcheck.add_argument('--healthcheck_name', dest="health_check_name", required=True, type=str, help="Health Check Name")
    parser_healthcheck.add_argument('--webhook_config', dest="webhook_config", required=False, type=str, help="Config files containin webhook configurations")

    parser_healthcheck.add_argument('--webhook_hostname', dest="webhook_hostname", required=False, help="hostname to which send the webhook")
    parser_healthcheck.add_argument('--webhook_endpoint', dest="webhook_endpoint", required=False, help="endpoint to which send the webhook")
    parser_healthcheck.add_argument('--webhook_port', dest="webhook_port", default=443, help="port to which send the webhook")
    parser_healthcheck.add_argument('--webhook_scheme', dest="webhook_scheme", default="https", help="scheme for the webhook")
    parser_healthcheck.add_argument('--webhook_token', dest="webhook_token", required=False, help="secret token parameter for the webhook")

    # webhook_config_group.add_group(webhook_config_group)

    parser_kpi.set_defaults(command="kpi")
    parser_kpi.add_argument('--kpi', '-k', dest='key_performance_indicator', required=True, type=str,
                        help="key performance indicator, e.g., WPSTA\n")
    parser_kpi.add_argument('--param', '-p', help='parameters', dest="parameters", type=str, required=True)
    
    args = parser.parse_args()

    logging.basicConfig(format='[%(asctime)s][%(levelname)-7s] %(pathname)s at line '
                        '%(lineno)4d (%(funcName)20s): %(message)s')


    logger = logging.getLogger(__name__)

    logger.setLevel(getattr(logging, args.logging_level.upper()))

    if args.command == "healthcheck":
        check_webhook_configuration(args)

    return args

def build_function_argument(args):
    if args.command == "kpi":
        return {
            "I_IMPORT": build_json_payload_alternative(args)
        }
    elif args.command == "healthcheck":
        return {
            "I_HEALTHCHECK_NAME": args.health_check_name
        }
    else:
        raise NotImplemented(f"Command {args.command} not yet supported")

    
def get_connection_performance_data(delta_connection, delta_call) -> str:
    return f"connection={delta_connection}s call={delta_call}s"


def main():
    args = parse_args()

    logger = logging.getLogger(__name__)
    
    logger.debug(f"Read config -> {args}")

    sap_conf = load_my_csv_configuration(args.sap_config_file, args.sysid, args.mandant)

    function_argument = build_function_argument(args)

    time_before_connection = datetime.datetime.utcnow()
    conn = Connection(**sap_conf)
    time_after_connection = datetime.datetime.utcnow()

    
    logging.debug("Connection Established")

    logging.debug("Starting Call")
    time_before_call = datetime.datetime.utcnow()
    raw_result = conn.call(args.function_name, **function_argument)
    time_after_call = datetime.datetime.utcnow()
    conn.close()

    logger.debug("Close connection")

    logger.debug(raw_result)

    logger.debug("compute times")
    delta_connection = (time_after_connection - time_before_connection).total_seconds()
    delta_call = (time_after_call - time_before_call).total_seconds()

    logger.debug(raw_result)
    # Parsing the result
    e_return: str  = raw_result["E_RETURN"]

    result = []

    try:
        result = json.loads(e_return)
    except json.decoder.JSONDecodeError:
        print(f"Check Unknown - {e_return}")
        sys.exit(IcingaServiceStatus.UNKNOWN.value)

    connection_performance_data = get_connection_performance_data(delta_connection, delta_call) 

    if args.command == "kpi":
        check_for_special_cases(result)
        
        (output_string) = prepare_icinga_output(result, connection_performance_data)
        status = get_check_status(result)
        print(output_string)
        sys.exit(status)
    elif args.command == "healthcheck":

        send_to_webhook(args, result)

        print(f"Check OK - Execute healthcheck for '{args.health_check_name}' on host '{args.sysid}'. Sent {len(result)} elements to Tornado"
              f"| {connection_performance_data}")
        sys.exit(IcingaServiceStatus.OK.value)
    else:
        raise NotImplemented(f"Command {args.command} not yet supported")



if __name__ == "__main__":
    main()
