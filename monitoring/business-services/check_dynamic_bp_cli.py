#!/usr/bin/python3
"""
Business Services checker: with different filters this script checks the current state of a business service set up by sub-business services

@author: Dominik Gramegna
"""
import argparse
import ast
import sys
import logging
import json
import inspect
import re
import math
import os
from enum import Enum
from typing import List, Union, Dict
import copy

url_show_host = "./monitoring/host/show"
url_show_service = "./monitoring/service/show"


class IcingaObjectType(Enum):
    HOSTS = "hosts"
    SERVICES = "services"


compute_state_map: Dict[float, float] = {
    0.0: 2.0,
    0.5: 0.5,
    1.0: 1.0,
    2.0: 0.0
}

output_objects = {
    IcingaObjectType.HOSTS.value: {
        "down": [],
        "up": []
    },
    IcingaObjectType.SERVICES.value: {
        "critical": [],
        "warning": [],
        "unknown": [],
        "ok": [],
    }
}

states_name_map: Dict[int, str] = {
    IcingaObjectType.HOSTS.value: {
        0.0: "up",
        2.0: "down"
    },
    IcingaObjectType.SERVICES.value: {
        0.0: "ok",
        1.0: "warning",
        2.0: "critical",
        3.0: "unknown"
    }
}


def to_service_state(object_type: str, res: float):
    if object_type == IcingaObjectType.HOSTS.value:
        if res == 1.0:
            return 2.0
        else:
            return res
    else:
        return res


# Host status: Host status NOT OK (ie 1.0) => Critical 2.0
def compute_aggregation(operator: str, mylist: List[float], object_type: str) -> float:

    if operator == "and":
        return max(mylist)
    if operator == "or":
        return min(mylist)
    if operator == "not":
        res = max(mylist)
        # Negation of "AND"
        if object_type == IcingaObjectType.HOSTS.value:
            if res == 1.0:
                return 0.0
            return 1.0
        # Negation of "AND". At least one object must be CRITICAL (status = 2 )
        # to return OK. If WORST status is WARNING, then return status = 1
        else:
            if res == 2.0:
                return 0.0
            elif res == 0.0:
                return 2.0
            else:
                return res

    if operator == "deg":
        if object_type == IcingaObjectType.HOSTS.value:
            raise ValueError("Unsupported operator for hosts")
        res = max(mylist)
        # Critical is lowered to warning
        if res == 2.0:
            res = 1.0
        return res

    t = re.match("min(\d+)(%?)", operator)
    if t:
        minimum = int(t.groups()[0])
        if(t.groups()[1]):
            minimum = math.ceil(minimum*len(mylist)/(100))
        if minimum < 1:
            minimum = 1
        if minimum > len(mylist):
            raise ValueError(
                f"Min cannot be greater than the length of the list (min={minimum}, mylist={mylist})")

        return max(sorted(mylist)[0:minimum])

    t = re.match("max(\d+)(%?)", operator)
    if t:
        maximum = int(t.groups()[0])
        if(t.groups()[1]):
            maximum = math.floor(maximum*len(mylist)/(100))
        if maximum < 1:
            maximum = 1
        if maximum > len(mylist):
            raise ValueError(
                f"Max cannot be greater than the length of the list (max={maximum}, mylist={mylist})")

        # if 100% or length of list is given as max value, it will always be true
        if maximum != len(mylist):
            state = max(sorted(mylist)[0:maximum+1])
            return compute_state_map[to_service_state(args.object_type, state)]
        else:
            return 0.0


def remap_unknown(state: float, from_icinga_to_order: bool) -> float:
    """
    The unknown state should be remapped to a value, such that the order of
    the states is as follows:
    OK < UNKNWON < WARNING < CRITICAL
    """
    if from_icinga_to_order:
        if state == 3.0:
            return 0.5
    else:
        if state == 0.5:
            return 3.0
    return state


def process(aggregator: str, object_type: str, objects: List[Dict]):

    objectss = [remap_unknown(float(el["service_state"] if object_type ==
                                    IcingaObjectType.SERVICES.value else el["host_state"]), True) for el in objects]

    logging.debug(f"filter list={objectss}")

    return to_service_state(
        object_type,
        remap_unknown(
            compute_aggregation(
                aggregator,
                [remap_unknown(float(el["service_state"] if object_type == IcingaObjectType.SERVICES.value else el["host_state"]), True)
                 for el in objects],
                object_type
            ),
            False
        )
    )


class TornadoPrintVisitor(ast.NodeVisitor):
    """
    Tree visitor that prints the type of the nodes and their fields,
    useful for debugging purposes
    """

    def generic_visit(self, node):
        logging.debug(str(type(node)) + " == " + str(node._fields))
        if "ctx" in node._fields:
            logging.debug(node.ctx)
        ast.NodeVisitor.generic_visit(self, node)

    def visit_Load(self, node):
        pass


class TornadoPreprocessor(ast.NodeTransformer):
    """
    Class that rewrites the tree to use only operations currently,
    supported in Tornado
    """

    def generic_visit(self, node):
        # ast.NodeTransformer.generic_visit(self, node)
        return ast.NodeTransformer.generic_visit(self, node)

    def visit_Load(self, node):
        pass


def check(*params):
    """
    Check is a function that can be passed in the filter parameter,
    which checks different states together with the operator
    given as the last argument.
    The passed states could be other nested check functions or simple match functions 
    Example:

    'check( \
        check( \
            match("smart*", "service.name", "min26%"), \
            match("pending*", "service.name", "min1"), \
            match("ping*", "service.name", "max100%"), \
            match("health*", "service.name", "min2"), \
            "max50%" \
        ), \
        match("smart*", "service.name", "min60%"), \
        "min25%" \
    )
    """

    object_type = args.object_type

    mylist = params[:-1]
    operator = params[-1]

    r = compute_aggregation(
        operator,
        mylist,
        object_type
    )

    logging.debug(f"check list={mylist}, r={r}")

    return r


def filter(filter, operator):
    """
    Match is a function that can be passed in the filter parameter and
    calls the api function to calculate the state of the business process
    and sets some variables for the exit output 
    """

    objects = getCliObjects(filter)

    logging.debug(objects)

    for el in objects:
        name = el["host_name"]
        service_description = el.get("service_description")
        name += f":{service_description}" if args.object_type == IcingaObjectType.SERVICES.value else ""

        state = float(el["host_state"]) if args.object_type == IcingaObjectType.HOSTS.value else float(
            el["service_state"])
        state = to_service_state(
            args.object_type,
            remap_unknown(
                state,
                False
            )
        )
        output_objects[args.object_type][states_name_map[args.object_type][state]].append(
            name)

    # Calculate the Return Status
    r = process(operator, args.object_type, objects)

    if r == 2.0:
        sys.num_of_not_ok_aggregations += 1

    return r


def getCliObjects(filter):
    cliObjects = list()
    stream = os.popen(
        f"icingacli monitoring list {args.object_type} {filter} --format=json")
    cliObjects = stream.read()
    stream.close()
    cliObjects = json.loads(cliObjects)

    return cliObjects


# Functions which can be called in the parameters
evaluable_functions = ["check", "filter"]

declared_variables = []


class TornadoWhereClauseVisitor(ast.NodeTransformer):
    """
    Abstract Syntax Tree transformer that generates Tornado Rules
    """

    def generic_visit(self, node):
        print(str(type(node)))
        # ast.NodeTransformer.generic_visit(self, node)
        return ast.NodeTransformer.generic_visit(self, node)

    def visit_Expr(self, node):
        return ast.NodeTransformer.visit(self, node.value)

    def visit_Load(self, node):
        pass

    def visit_Name(self, node):
        return node.id

    def visit_NameConstant(self, node):
        return node.value

    def visit_Constant(self, node):
        return node.value

    def visit_Num(self, node):
        return node.n

    def visit_Not(self, node):
        logging.warning("Currently, Not is not supported by Tornado")
        return "NOT"

    def visit_Eq(self, node):
        return "equals"

    def visit_NotEq(self, node):
        logging.warning("currently, it is not supported by tornado")
        return "ne"

    def visit_Lt(self, node):
        return "lt"

    def visit_LtE(self, node):
        return "le"

    def visit_Gt(self, node):
        return "gt"

    def visit_GtE(self, node):
        return "gte"

    def visit_In(self, node):
        logging.warning(
            "Currently, it works only for strings, you cannot check")
        return "Contains"

    def visit_Str(self, node):
        return "\"{}\"".format(node.s)

    def visit_Index(self, node):
        try:
            index = int(ast.NodeTransformer.visit(self, node.value))
            return "[{}]".format(index)
        except ValueError:
            raise NotImplementedError("String keys not yet supported")

    def visit_Tuple(self, node):
        raise NotImplementedError("Tuples are not supported yet.")

    def visit_List(self, node):
        logging.warning("Currently, it is not supported")
        return [ast.NodeTransformer.visit(self, n) for n in node.elts]

    def visit_If(self, node):
        logging.debug(node)
        print(type(node.test))

        test = ast.NodeTransformer.visit(self, node.test)
        body = [ast.NodeTransformer.visit(self, stmt) for stmt in node.body]
        orelse = [ast.NodeTransformer.visit(
            self, stmt) for stmt in node.orelse]
        logging.debug("IF %s: %s else: %s ", test, body, orelse)
        return {
            "WHERE": test,
            "WITH": body
        }

    def visit_BoolOp(self, node):
        logging.debug(str(type(node)) + " len values = " +
                      str(len(node.values)))
        operator = ast.NodeTransformer.visit(self, node.op)
        left = ast.NodeTransformer.visit(self, node.values[0])
        right = ast.NodeTransformer.visit(self, node.values[1])

        # # Calculate the Return Status
        # res = process(operator, args.softness, args.object_type, r.json()["results"])
        # print(res)

        if len(node.values) > 2:
            logging.exception("Too many values")
        logging.debug("BoolOp: %s %s %s", left, operator, right)
        return {
            "type": operator,
            "operators": [
                left,
                right
            ]
        }
        # ast.NodeTransformer.generic_visit(self, node)

    def visit_UnaryOp(self, node):
        logging.warning("Currently, Unary Op is not supported by Tornado")
        operator = ast.NodeTransformer.visit(self, node.op)
        operand = ast.NodeTransformer.visit(self, node.operand)
        return {
            "type": operator,
            "operator": operand
        }

    def visit_And(self, node):
        return "AND"

    def visit_Or(self, node):
        return "OR"

    def visit_Attribute(self, node):
        logging.debug("Attribute")
        variable = ast.NodeTransformer.visit(self, node.value)
        attribute = node.attr

        # The following if statement is required, because the attributes
        # are visited iteratively. Given the example "event.payload.event_id"
        # The first time vist_attribute is called we receive as input
        # (event, payload) the second time (${event.payload}, event_id)
        if variable[0:2] == "${" and variable[-1] == "}":
            variable = variable[2:-1]
        if ":" in attribute or "." in attribute:
            attribute = f"\"{attribute}\""
        return variable + "." + attribute

    def visit_Compare(self, node):
        # v = ast.NodeTransformer.generic_visit(self, node.left)
        v = ast.NodeTransformer.visit(self, node.left)
        ops = [ast.NodeTransformer.visit(self, op) for op in node.ops]
        comparators = [ast.NodeTransformer.visit(
            self, comparator) for comparator in node.comparators]
        return {
            "type": ops[0],
            "left": v,
            "right": comparators[0]
        }

    def visit_Assign(self, node):
        value = ast.NodeTransformer.visit(self, node.value)
        targets = [ast.NodeTransformer.visit(
            self, target) for target in node.targets]
        if len(targets) > 1:
            logging.warning("Currently, we support only single targets")
        print(value)
        declared_variables.append(targets[0])
        return {
            f"{targets[0]}": value
        }

    def visit_Call(self, node):
        func: str = ast.NodeTransformer.visit(self, node.func)

        if(func not in evaluable_functions):
            raise Exception()

        arguments: List = [ast.NodeTransformer.visit(
            self, a) for a in node.args]
        keywords: List = [ast.NodeTransformer.visit(
            self, k) for k in node.keywords]
        args = []
        keys = []

        for a in arguments:
            if a in declared_variables:
                args.append("'${_variables." + a + "}'")
            else:
                args.append("{}".format(a))

        for k in keywords:
            keys.append("{}={}".format(k.arg, k.value))

        keyargs = ",".join([str(x) for x in (args + keys)])
        logging.debug(f"Going to evaluate {func}({keyargs})")
        return eval(f"{func}({keyargs})")

    #####
    # Not Implemented visit function that should raise errors
    ####
    def visit_FunctionDef(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_AsyncFunctionDef(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_ClassDef(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Return(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_AsyncFor(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_While(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_AsyncWith(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Try(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Assert(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Import(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_ImportFrom(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Global(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_NonLocal(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Break(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Continue(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_BinOp(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Lambda(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_IfExpr(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Set(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Dict(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_ListComp(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_DictComp(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_GeneratorExp(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Await(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Yield(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_YieldFrom(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_FormattedValue(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_JoinedStr(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Bytes(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Ellipsis(self, node): raise NotImplementedError(
        inspect.stack()[0][3] + " not supported yet")

    def visit_Subscript(self, node):
        variable = ast.NodeTransformer.visit(self, node.value)
        thisslice = ast.NodeTransformer.visit(self, node.slice)
        # It is a variable
        if len(variable) > 3 and "${" == variable[0:2] and "}" == variable[-1]:
            return "{}{}{}".format(variable[0:-1], thisslice, "}")
        return "{}{}".format(variable, thisslice)

    def visit_With(self, node):
        items = [ast.NodeTransformer.visit(self, i) for i in node.items]
        body = [ast.NodeTransformer.visit(self, b) for b in node.body]
        print(items)
        print(body)
        return {
            "WITH": items,
            "actions": body
        }

    def visit_withitem(self, node):
        context_expr = ast.NodeTransformer.visit(self, node.context_expr)
        if node.optional_vars is not None:
            vars = ast.NodeTransformer.visit(self, node.optional_vars)
        else:
            raise NotImplementedError(
                "We support only with expressions with variable declarations")
        return {
            f"{vars}": context_expr
        }


def debug_print_tree(expression_list: List[ast.Expr]):
    # Printing the tree
    t = TornadoPrintVisitor()
    for x in expression_list:
        t.visit(x)


def preprocess_tree(expression_list: List[ast.Expr]):
    # Printing the tree
    t = TornadoPreprocessor()
    for x in expression_list:
        t.visit(x)


def parse_args():
    parser = argparse.ArgumentParser(description='Check correlation engine')

    parser.add_argument('--log_level', dest='logging_level', help='Log level: <DEBUG, INFO, WARNING, ERROR> (default WARNING)', type=str,
                        default="WARNING")

    parser.add_argument('-f', '--filter', dest='filter', required=True,
                        type=str, help='Filter to check the state of the business service. Example: filter("--service=ping", "min100")')
    parser.add_argument('-t', '--type', dest='object_type', required=True, default="hosts",
                        choices=["hosts", "services"], help='Whether to use hosts or services')
    parser.add_argument('-k', '--show-ok-states', dest='show_ok_states', default=False,
                        action='store_true', help='Whether to show ok/up states in output or not')
    # parser.add_argument('--degrade' , dest='', required=False, default=True, help='')

    args = parser.parse_args()

    logging.basicConfig(level=logging.getLevelName(args.logging_level.upper()),
                        format='[%(asctime)s][%(levelname)-7s] %(pathname)s at line '
                               '%(lineno)4d (%(funcName)20s): %(message)s')

    logger = logging.getLogger(__name__)

    logger.setLevel(getattr(logging, args.logging_level.upper()))

    return args


def main():
    global args
    args = parse_args()

    logger = logging.getLogger(__name__)

    logger.debug(f"Read config -> {args}")

    sys.num_of_not_ok_aggregations = 0

    sys.checked_objects = {
        IcingaObjectType.HOSTS.value: {
            0.0: list(),
            2.0: list()
        },
        IcingaObjectType.SERVICES.value: {
            0.0: list(),
            1.0: list(),
            2.0: list(),
            3.0: list()
        }
    }

    expression_list: List[Union[ast.Expr, ast.stmt]
                          ] = ast.parse(str(args.filter)).body

    for expr in expression_list:
        if isinstance(expr, ast.Expr):
            logger.info("OK, expression passed")
        else:
            logger.error("Currently, we accept only expressions\n Example: -f 'filter(\"--service=ping\", \"min100%\")'")

    debug_print_tree(expression_list)

    preprocess_tree(expression_list)

    # List of expressions
    t = TornadoWhereClauseVisitor()

    res = t.visit(expression_list[0])

    # Return the overall check result message
    plugin_output = create_plugin_output(res)

    print(plugin_output)

    sys.exit(int(res))


def print_html_state_details(elements: List[str], label: str):
    elements = " \\ ".join(elements)
    return f"<tr><td>{label}</td><td>{elements}</td></tr>"


def create_plugin_output(res):
    # makes the services or hosts of the list distinct for the output
    for key, value in output_objects[args.object_type].items():
        output_objects[args.object_type][key] = list(set(value))

    # create output of plugin, which contains the general information about the business service
    if(args.object_type == IcingaObjectType.HOSTS.value):
        plugin_output = f"Business Process {states_name_map[args.object_type][res].upper()}: RESOLVED {sys.num_of_not_ok_aggregations} {'BPs DOWN' if sys.num_of_not_ok_aggregations > 1 else 'BP DOWN'} |"
        plugin_output += " up_objects=" + \
            str(len(output_objects[args.object_type]["up"])) if len(
                output_objects[args.object_type]["up"]) else ""
        plugin_output += " down_objects=" + \
            str(len(output_objects[args.object_type]["down"])) if len(
                output_objects[args.object_type]["down"]) else ""

    else:
        plugin_output = f"Business Process {states_name_map[args.object_type][res].upper()}: RESOLVED {sys.num_of_not_ok_aggregations} {'BPs CRITICALS' if sys.num_of_not_ok_aggregations > 1 else 'BP CRITICAL'} |"
        plugin_output += " critical_objects=" + \
            str(len(output_objects[args.object_type]["critical"])) if len(
                output_objects[args.object_type]["critical"]) else ""
        plugin_output += " warning_objects=" + \
            str(len(output_objects[args.object_type]["warning"])) if len(
                output_objects[args.object_type]["warning"]) else ""
        plugin_output += " unknown_objects=" + \
            str(len(output_objects[args.object_type]["unknown"])) if len(
                output_objects[args.object_type]["unknown"]) else ""
        plugin_output += " ok_objects=" + \
            str(len(output_objects[args.object_type]["ok"])) if len(
                output_objects[args.object_type]["ok"]) else ""
    plugin_output += "\n"

    # creates the link of the element depending on its type and adds it to the output
    for key, values in copy.deepcopy(output_objects[args.object_type]).items():
        output_objects[args.object_type][key] = []
        for el in values:
            host = el.split(":")[0]
            if args.object_type == IcingaObjectType.HOSTS.value:
                link = f"<a href='{url_show_host}?host={host}'>{host}</a>"
            else:
                service = el.split(":")[1]
                link = f"<a href='{url_show_service}?host={host}&service={service}'>{el}</a>"

            output_objects[args.object_type][key].append(link)

    # creates the html table containing the objects in their right state row
    html_details_table = "<table border='1'><thead><tr><th>Status</th><th>Objects</th></tr></thead><tbody>"
    for key, value in output_objects[args.object_type].items():
        html_details_table += print_html_state_details(value, key.upper()) if (value and (key != "ok" and key != "up")) or (
            value and ((key == "ok" or key == "up") and args.show_ok_states)) else ""
    html_details_table += "</tbody></table>"

    return f"{plugin_output}{html_details_table}"


if __name__ == "__main__":
    main()
