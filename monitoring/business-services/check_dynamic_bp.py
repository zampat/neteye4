#!/neteye/local/monitoring/plugins/pve/bin/python
"""
(WIP) Dynamic Business Process check for icinga 2

authors: Mirko Bez <mirko.bez@wuerth-phoenix.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""
import sys
import requests
import toml
import logging
import urllib3
import functools
import re
import argparse
from typing import List, Dict

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

states_map: Dict[str, Dict[float, str]] = {
    "hosts": {
        0.0: "OK: Level of UP-Hosts is reached",
        1.0: "WARNING: Too many Hosts are DOWN",
        2.0: "CRITICAL: Too many Hosts are DOWN",
        3.0: "UNKNOWN: Too many Hosts are DOWN"
    },
    "services": {
        0.0: "OK",
        1.0: "WARNING",
        2.0: "CRITICAL",
        3.0: "UNKNOWN",
    }
}

def parse_args():
    parser = argparse.ArgumentParser(description='Bussiness Process')
    parser = argparse.ArgumentParser(description=f"Example: {sys.argv[0]}")
    parser.add_argument('-a', '--aggregator' , dest='aggregator', required=True, type=lambda x: x.lower(), help='Choose your aggregator Activity Service (AND, OR, MIN[\d+], MINOK([\d+], [\d+]))')
    parser.add_argument('-f', '--filter' , dest='myfilter', required=True, type=str, help="API filter, examples: '\"location_Bozen\" in host.groups'\n 'match(\"pbzesxi*\",host.name)'")
    parser.add_argument('-s', '--softness' , dest='softness', required=False, action='store_true', default=False, help='Consider soft states')
    parser.add_argument('-t', '--type' , dest='object_type', required=True, default="hosts", choices=["hosts", "services"], help='Whether to use hosts or services')
    parser.add_argument('--degrade' , dest='', required=False, default=True, help='')

    parser.add_argument('--log_level', dest='log_level', required=False, default="WARNING", help="logging level: WARNING, INFO, DEBUG")

    return parser.parse_args()



def count_el_with_value(mylist, value):
    """
    Count the elements equals to
    """
    s = 0
    for x in mylist:
        if (x == value):
            s += 1
    return s

def to_service_state(object_type: str, res: float):
   if object_type == "hosts":
       if res == 1.0:
          return 2.0
       else:
          return res
   else:
       return res


# Host status: Host status NOT OK (ie 1.0) => Critical 2.0
def compute_aggregation(operator: str, mylist: List[float], object_type: str) -> float:

    sys.num_of_aggregated_objects = len(mylist)
    logging.debug(sys.num_of_aggregated_objects)

    if operator == "and": return max(mylist)
    if operator == "or": return min(mylist)
    if operator == "not":
        res = max(mylist)
        # Negation of "AND"
        if object_type == "hosts":
            if res == 1.0: return 0.0
            return 1.0
        # Negation of "AND". At least one object must be CRITICAL (status = 2 )
        # to return OK. If WORST status is WARNING, then return status = 1
        else:
            if res == 2.0: return 0.0
            elif res == 0.0: return 2.0
            else: return res


    if operator == "deg":
        if object_type == "hosts":
            raise ValueError("Unsupported operator for hosts")
        res = max(mylist)
        # Critical is lowered to warning
        if res == 2.0:
            res = 1.0
        return res

    t = re.match("min(\d+)", operator)
    if t:
        minimum = int(t.groups()[0])
        if minimum < 1:
            raise ValueError("Min cannot be negative")
        if minimum > len(mylist):
            raise ValueError("Min cannot be greater than the length of the list")
        return max(sorted(mylist)[0:minimum])
    
    t = re.match("minok(\d+)\-(\d+)", operator)
    if t:
        groups = t.groups()
        logging.debug(groups)
        m = int(groups[0])
        n = int(groups[1])
        count_ok = len([x for x in mylist if x == 0])
        count_warn = len([x for x in mylist if x == 1])
        count_critical = len([x for x in mylist if x == 2])


        if count_ok >= n:
            return 0
        # Have at least m OKs
        if count_ok < m:
            return 2
        # Have no more than m Criticals OR have less than n OKs
        if count_critical >= m or count_ok < n:
            return 1
        
        

def compute_perfdata(mylist: List[Dict], softness: bool) -> List[List[str]]:
    res = [
        [],
        [],
        [],
        []
    ]
    for x in mylist:
        res[int(considered_state(softness, x["attrs"]["state"], x["attrs"]["state_type"]))].append(x["name"])
    return res


def is_soft(state_type: float) -> bool:
    return state_type == 0.0

def considered_state(softness: bool, state: float, state_type: float):
    """
    Transform the state
    """
    if not softness:
        if is_soft(state_type):
            return 0.0
        else:
            return state
    return state


def remap_unknown(state: float, from_icinga_to_order: bool) -> float:
    """
    The unknown state should be remapped to a value, such that the order of
    the states is as follows:

    OK < UNKNWON < WARNING < CRITICAL
    """
    if from_icinga_to_order:
        if state == 3.0: return 0.5
    else:
        if state == 0.5: return 3.0
    return state


def process(aggregator: str, softness: bool, object_type: str, objects: List[Dict]):
    return to_service_state(
       object_type, 
       remap_unknown(
          compute_aggregation(
              aggregator,
              [remap_unknown(considered_state(softness, el["attrs"]["state"], el["attrs"]["state_type"]), True) for el in objects],
              object_type
          ),
          False
        )
      )  


def print_html_details_table(table: List[str], label: str = "NOT OK"):
    table_output = f"<tr><th>{label}</th><td>"
    for row in table:
        table_output += f"{row} "
    table_output += f"</td></tr>"
    return table_output


def main():

    args = parse_args()

    logging.basicConfig(format='[%(asctime)s][%(levelname)-7s] %(pathname)s at line '
                        '%(lineno)4d (%(funcName)20s): %(message)s', level=logging.getLevelName(args.log_level.upper()))



    tmp = ""

    sys.num_of_aggregated_objects = ""

    with open("/neteye/local/monitoring/configs/icinga2_api_monitoring_user.toml") as f:
        tmp = f.read()
    config = toml.loads(tmp)
    payload = {
        "filter": args.myfilter
        # "match(\"pbzesxi*\",host.name)",
    }

    logging.info(payload)

    logging.debug("Icinga2 API Query: https://localhost:5665/v1/objects/" + args.object_type)


    r = requests.get(f"https://localhost:5665/v1/objects/{args.object_type}",
                    auth=(config["username"], config["password"]),
                    verify=False,
                    headers={'Accept': 'application/json'},
                    json=payload)

    logging.debug([key for key in r.json()["results"][0]])

    #print ("Status: STATE, TYPE, consider_soft_states, state, state_type") 
    #for el in r.json()["results"]:
    #    print("Status: " + str(el["attrs"]["state"]) + "," + str(is_soft(el["attrs"]["state_type"])) + "," + str(considered_state(args.softness, el["attrs"]["state"], el["attrs"]["state_type"])))

    # Calculate the Return Status
    res = process(args.aggregator, args.softness, args.object_type, r.json()["results"])

    # Prepare details overviews of indicating evaluated host and service objects
    details_list = compute_perfdata(r.json()["results"], args.softness)

    num_of_ok = int(len(details_list[0]))
    num_of_crit = int(len(details_list[1]))
    html_details_table = "<table border='1'><thead><tr><th>Status</th><th>Objects</th></tr></thead><tbody>"

    if args.object_type == "hosts":
       html_details_table += print_html_details_table(details_list[1], "DOWN HOSTS")
       html_details_table += print_html_details_table(details_list[0], "UP HOSTS")
    if args.object_type == "services":
       html_details_table += print_html_details_table(details_list[2], "CRITICAL SERVICES")
       html_details_table += print_html_details_table(details_list[1], "WARNING SERVICES")
       html_details_table += print_html_details_table(details_list[0], "OK SERVICES")
    html_details_table += "</tbody></table>"


    # Return the overall check result message
    print("BP aggregator: " + states_map[args.object_type][res] + " | total_objects=" + str(sys.num_of_aggregated_objects) + " ok_objects=" + str(num_of_ok) + " crit_objects=" + str(num_of_crit))

    print(html_details_table)

    sys.exit(int(res))

    #print(functools.reduce(operator_map[sys.argv[1].lower()], [considered_state(softness, el["attrs"]["state"], el["attrs"]["state_type"]) for el in r.json()["results"]]))

if __name__ == "__main__":
    main()
