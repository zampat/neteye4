#!/usr/bin/python3

import argparse
import logging
import requests
import urllib3
import sys

plugin_output_max_length = 3500

icinga2_base_url = "https://xxxxxneteye_urlxxxxx/neteye"

teams_color = {
    "OK": "#32CD32",
    "WARNING": "#FF8C00",
    "CRITICAL": "#FF0000",
    "UNKNOWN": "#6A5ACD",
    "UP": "#32CD32",
    "DOWN": "#FF0000"
}


def readableDuration(seconds):
    seconds = float(seconds)
    if seconds <= 60:
        return f"{seconds} seconds"
    elif seconds <= 3600:
        return f"{round(seconds / 60)} minutes"
    elif seconds <= 86400:
        return f"{round(seconds / 3600)} hours"
    else:
        return f"{round(seconds / 86400)} days"


def parse_args():

    parser = argparse.ArgumentParser(description='Check correlation engine')

    parser.add_argument('--log_level', dest='logging_level', help='Log level: <DEBUG, INFO, WARNING, ERROR> (default WARNING)', type=str,
                        default="WARNING")

    parser.add_argument('-t', '--object_type', dest='object_type', default="host",
                        choices=["host", "service"], help='Whether to use hosts or services')

    parser.add_argument('--teams_webhook_url',
                        dest='teams_webhook_url', type=str, help='')
    parser.add_argument('--notification_type',
                        dest='notification_type', type=str, help='')
    parser.add_argument('--notification_author',
                        dest='notification_author', type=str, help='')
    parser.add_argument('--notification_comment',
                        dest='notification_comment', type=str, help='')
    parser.add_argument('--icinga_long_date_time',
                        dest='icinga_long_date_time', type=str, help='')
    parser.add_argument(
        '--service_name', dest='service_name', type=str, help='')
    parser.add_argument('--service_display_name',
                        dest='service_display_name', type=str, help='')
    parser.add_argument('--service_state',
                        dest='service_state', type=str, help='')
    parser.add_argument('--service_duration_sec',
                        dest='service_duration_sec', type=str, help='')
    parser.add_argument('--service_check_attempt',
                        dest='service_check_attempt', type=str, help='')
    parser.add_argument('--service_last_state',
                        dest='service_last_state', type=str, help='')
    parser.add_argument('--service_output',
                        dest='service_output', type=str, help='')
    parser.add_argument('--host_name', dest='host_name', type=str, help='')
    parser.add_argument('--host_display_name',
                        dest='host_display_name', type=str, help='')
    parser.add_argument('--host_state', dest='host_state', type=str, help='')
    parser.add_argument('--host_duration_sec',
                        dest='host_duration_sec', type=str, help='')
    parser.add_argument('--host_check_attempt',
                        dest='host_check_attempt', type=str, help='')
    parser.add_argument('--host_last_state',
                        dest='host_last_state', type=str, help='')
    parser.add_argument('--host_output', dest='host_output', type=str, help='')

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

    # sys.exit(1)
    
    logger = logging.getLogger(__name__)

    if args.teams_webhook_url is None:
        logger.error("webhook_url not set, aborting...")
        return 1

    notification_type_custom_text = ""
    if args.notification_type == "CUSTOM" or args.notification_type == "ACKNOWLEDGEMENT":
        notification_type_custom_text = "{\"name\":\"Comment\",\"value\":\"" + \
            args.notification_comment + " by " + args.notification_author + "\"},"

    if args.object_type == "host":
        color = teams_color.get(args.host_state)
    else:
        color = teams_color.get(args.service_state)

    logger.debug(f"Sending notification...chose color successfully: {color}")

    logger.debug("Sending notification...generating notification text")

    plugin_output = args.host_output[:plugin_output_max_length]
    host_name_with_link = f"[{args.host_display_name}]({icinga2_base_url}/monitoring/host/show?host={args.host_name})"
    text = "error crafting payload"
    state_duration = ""
    service_details = ""

    if args.object_type == "host":
        # Notification is for a host
        state_text = f"Transitioned from {args.host_last_state} to {args.host_state}"
        fallback_text = args.notification_type + ": " + args.host_name + " is " + args.host_state
        if args.host_last_state == args.host_state:
            state_text = "Is still " + args.host_state
            host_duration_readable = readableDuration(args.host_duration_sec)
            state_duration = "{\"name\":\"Duration\",\"value\":\"" + host_duration_readable + "\"},"
    else:
        # Notification is for a service
        args.service_name = args.service_name.replace(" ", "%20")
        service_name_with_link = f"[{args.service_display_name}]({icinga2_base_url}/monitoring/service/show?host={args.host_name}&service={args.service_name})"
        args.service_name = args.service_name.replace("%20", " ")
        plugin_output = args.service_output[:plugin_output_max_length]
        state_text = f"Transitioned from {args.service_last_state} to {args.service_state}"
        fallback_text = f"{args.notification_type}: {args.service_name} is {args.service_state} on {args.host_name}"
        if args.service_last_state == args.service_state:
            state_text = f"Is still in {args.service_state}"
            service_duration_readable = readableDuration(args.service_duration_sec)
            state_duration = "{\"name\":\"Duration\",\"value\":\"" + service_duration_readable + "\"},"
        
        service_details = "{\"name\":\"Service\",\"value\":\"" + service_name_with_link + "\"},"

    plugin_output_escaped = plugin_output.replace("\"", "\\\"")
    payload_attachments = "{\"@type\":\"MessageCard\",\"themeColor\":\"" + color + "\",\"summary\":\"" + fallback_text + "\",\"sections\":[{\"activityTitle\":\"" + fallback_text + "\",\"facts\":[{\"name\":\"Host\",\"value\":\"" + host_name_with_link + "\"}," + service_details + "{\"name\":\"State\",\"value\":\"" + state_text + "\"}," + state_duration + notification_type_custom_text + "{\"name\":\"Plugin output\",\"value\":\"```" + plugin_output_escaped + "```\"}],\"markdown\":true}]}"

    logger.debug("Sending notification...generated notification text successfully: " + payload_attachments)

    logger.debug("Generating notification command")

    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    # print(payload_attachments)
    response = requests.post(
        args.teams_webhook_url,
        data=payload_attachments
    )

    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError as e:
        logger.info(e)
        print(
            f"Check Critical - Could not send data to the webhook. Error code: {response.status_code}")
        sys.exit(2)


if __name__ == "__main__":
    main()
