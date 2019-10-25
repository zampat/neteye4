import argparse
import logging
from typing import Dict, Any

import csv
import json
import sys
import re

from enum import Enum
from pyrfc import Connection


class IcingaServiceStatus(Enum):
    OK = 0
    WARNING = 1
    CRITICAL = 2
    UNKOWN = 3


def load_csv_configuration(filename: str, header: bool = True) -> Dict[str, Dict[str, str]]:
    with open(filename, "r") as fd:
        csv_reader = csv.reader(fd, delimiter=' ')
        # Skip the first line if header is true
        if header:
            next(csv_reader)
        conf = {}
        for row in csv_reader:
            key = row[0]
            if key in conf:
                print("Error: multiple config for same object")
            else:
                conf[key] = {}
            conf[key]["sysid"] = row[0]
            conf[key]["sysnr"] = row[1]
            conf[key]["client"] = row[2]
            conf[key]["user"] = row[3]
            conf[key]["passwd"] = row[4]
            try:
                conf[key]["ashost"] = row[5]
            except KeyError:  # as host is an optional parameter
                conf[key]["ashost"] = row[0]

    return conf


def load_json_configuration(filename: str) -> Dict[str, Dict[str, str]]:
    with open(filename, "r") as fd:
        data = json.load(fd)
        conf = {}
        for row in data:
            key = row["sysid"]
            conf[key] = row

    return conf


def parse_args():
    """
    Parse the command line input. It returns the list of arguments and the parameters
    """
    parser = argparse.ArgumentParser(description='RFC SAP')
    parser.add_argument('--version', '-V', dest="version",
                        help='print the program version and exit', action='store_true')
    parser.add_argument('--log_level', dest="logging_level", default="WARNING",
                        help="logging level", type=str),
    parser.add_argument('--sap_config_file', dest="sap_config_file", default="nag_sap.cfg", type=str)

    parser.add_argument('--sysid', '-s', dest='sysid', required=True, type=str, help="sysid, e.g. DE7\n")
    parser.add_argument('--function', '-f', dest='function_name', required=True, type=str,
                        help="function, e.g. /WRP/NEMO_CENTRAL\n")
    parser.add_argument('--kpi', '-k', dest='key_performance_indicator', required=True, type=str,
                        help="key performance indicator, e.g., WPSTA\n")
    # The following parameter are temporarily not required, check the old perl version to find out how they were used
    parser.add_argument('--checktype', '-c', dest='checktype', required=False, type=str, help='checktype')
    parser.add_argument('--attribute', '-a', dest='attribute', required=False, type=str, help='attribute')
    parser.add_argument('--master-attribute', '-m', dest='master_attribute', required=False, type=str,
                        help='master-attribute')
    # Finished
    parser.add_argument('--timeout', '-t', dest='timeout', required=False, default=25, type=int,
                        help='timeout for the call (default 25)')

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--import-json-file', '-i', dest="import_json_file", type=str)
    group.add_argument('--import-json', dest="import_json_str", type=str)

    group.add_argument('--param', '-p', help='parameters', dest="parameters", type=str)
    # group.add_argument('--param','-p', nargs=1, action="append", help='parameters', dest="parameters")

    args = parser.parse_args()

    return args


def prepare_icinga_output(result: Dict[str, Any]) -> str:
    """
    Returns the status and the output string for icinga, following the nagios output format
    for performance data, see ref: https://nagios-plugins.org/doc/guidelines.html#AEN200
    """
    kpi = result["KPI"]
    output = kpi["OUTPUT"]
    performance = result["PERFORMANCE"]
    output_string = f"{output[0]} | "
    for p in performance:
        output_string += f"{p};"
        output_string.join(" ")
    return output_string


def get_check_status(result: Dict[str, Any]) -> int:
    """
    Return the status of the check
    """
    status: int = int(result["KPI"]["STATUS"])
    return status


def get_import_json(options) -> str:
    """
    Extract an import json string either from a file or from the input
    """
    if options.import_json_file is not None:
        with open(options.import_json_file) as fd:
            return json.dumps(json.load(fd))
    else:
        return options.import_json_str


def build_json_payload(args):
    data: Dict[str, Any] = dict()
    data["KPI"] = args.key_performance_indicator
    data["PARAMS"] = []
    if len(args.parameters) % 2 != 0:
        exit(IcingaServiceStatus.UNKOWN)

    i = 0
    while i < len(args.parameters):
        data["PARAMS"] += [{"NAME": args.parameters[i], "VALUE": args.parameters[i + 1]}]
        i += 2
    return json.dumps(data)


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
        sys.exit(IcingaServiceStatus.UNKOWN.value)

    kpi = result["KPI"]
    output = kpi["OUTPUT"]
    if "PERFORMANCE" not in result:
        print(output)
        if "STATUS" in kpi:
            sys.exit(int(kpi["STATUS"]))
        else:
            sys.exit(IcingaServiceStatus.UNKOWN.value)


def main():
    args = parse_args()

    if args.version:
        print("Version 0.1.0")
        exit(0)

    logging.basicConfig(level=getattr(logging, args.logging_level.upper()))

    # json_call_payload = get_import_json(options)

    logging.debug(f"Read config -> {args}")

    json_call_payload: str = build_json_payload_alternative(args)

    logging.debug(f"Build this json: {json_call_payload}")

    # Call for help example
    # json_call_payload = '{"KPI": "WPSTA", "PARAMS": [{"NAME": "I_Help", "VALUE": "X" }] }'
    # json_call_payload = '{"KPI": "WPSTA", "PARAMS": [{"NAME": "", "VALUE": "" }] }'
    # Call for Dialog. Bei upper_bound = X == Anzahl laufender Prozesse, bei upper_bound = "", dann Anzahl der freien jobs.

    # json_call_payload = u'{"KPI": "WPSTA", "PARAMS": [{"NAME": "I_WORKPROCESS_TYPE", "VALUE": "DIALOG"}, {"NAME": "I_WARNING_VALUE", "VALUE": ""}, {"NAME": "I_CRITICAL_VALUE", "VALUE": "10" }, {"NAME": "I_UPPER_BORDER", "VALUE": "X" }] }'

    # Call for Batch
    # json_call_payload = '{"KPI": "WPSTA", "PARAMS": [{"NAME": "I_WORKPROCESS_TYPE", "VALUE": "BATCH"}, {"NAME": "I_WARNING_VALUE", "VALUE": "5"}, {"NAME": "I_CRITICAL_VALUE", "VALUE": "10" }, {"NAME": "I_UPPER_BORDER", "VALUE": "X" }] }'
    # Call for Update workptozesse
    # json_call_payload = '{"KPI": "WPSTA", "PARAMS": [{"NAME": "I_WORKPROCESS_TYPE", "VALUE": "UPDATE"}, {"NAME": "I_WARNING_VALUE", "VALUE": "5"}, {"NAME": "I_CRITICAL_VALUE", "VALUE": "10" }, {"NAME": "I_UPPER_BORDER", "VALUE": "" }] }'
    # Call for enqueue eingeschränkt nach application server
    # json_call_payload = '{"KPI": "WPSTA", "PARAMS": [{"NAME": "I_WORKPROCESS_TYPE", "VALUE": "ENQUEUE"}, {"NAME": "I_WARNING_VALUE", "VALUE": "5"}, {"NAME": "I_CRITICAL_VALUE", "VALUE": "10" }, {"NAME": "I_UPPER_BORDER", "VALUE": "X" },{"NAME": "I_APPSERVER", "VALUE": "db225de7_DE7_14"}] }'

    sap_conf = load_csv_configuration(args.sap_config_file)

    if args.sysid not in sap_conf:
        print(f"No connection parameters available for system-ID {args.sysid:s}\n")
        exit(IcingaServiceStatus.UNKOWN)

    conn = Connection(**sap_conf[args.sysid])

    # Sample call:  python check_sap_rfc.py /WRP/NEMO_FIND_WPSTA a s e DE7
    raw_result = conn.call(args.function_name, I_IMPORT=json_call_payload)

    logging.debug(raw_result)

    # Parsing the result
    e_return: str = raw_result["E_RETURN"]
    result = json.loads(e_return)

    check_for_special_cases(result)

    (output_string) = prepare_icinga_output(result)
    status = get_check_status(result)
    print(output_string)
    sys.exit(status)


if __name__ == "__main__":
    main()
