"""
Main module for control evaluation engine
"""

from datetime import datetime, MINYEAR, timezone
import os
import subprocess
import sys
from time import sleep

import boto3
from botocore.exceptions import ClientError

if len(sys.argv) != 2:
    print(sys.argv)
    raise Exception("Command line arg INPUT_PATH is required")

JOB_ID, filename = sys.argv[1].split("/")

# Abort if file uploaded is not input
if filename != "input.json":
    exit(0)

BUCKET_NAME = os.environ.get("BUCKET_NAME", "long-running-jobs-test")
LOG_FILENAME = "log.txt"


def update_job_status():
    """Update the status of the job in database"""


s3 = boto3.resource("s3")
bucket = s3.Bucket(BUCKET_NAME)

# Try getting input data and its last modified time
input_obj = s3.Object(BUCKET_NAME, f"{JOB_ID}/input.json")
try:
    input_last_modified = input_obj.last_modified
    # Download input data to file
    input_obj.download_file("input.json")
except ClientError as exc:
    raise Exception("Unable to retrieve input data") from exc


# Check the last modified time of output data if exist
output_obj = s3.Object(BUCKET_NAME, f"{JOB_ID}/output.json")
try:
    output_last_modified = output_obj.last_modified
except ClientError:
    output_last_modified = datetime(MINYEAR, 1, 1, tzinfo=timezone.utc)

# Abort if output data is newer than input
if output_last_modified > input_last_modified:
    sys.exit(0)

# Remove outdated output file if it exists
if os.path.isfile("output.json"):
    os.remove("output.json")

with subprocess.Popen(["python", "evaluate_controller.py"]) as process:
    log_last_uploaded = 0.0  # pylint: disable=C0103
    while process.poll() is None:
        if os.path.isfile(LOG_FILENAME):
            log_last_modified = os.path.getmtime(LOG_FILENAME)
            if log_last_modified > log_last_uploaded:
                update_job_status()
                s3.Object(BUCKET_NAME, f"{JOB_ID}/log.txt").upload_file("log.txt")
                log_last_uploaded = log_last_modified
        sleep(5)

# Upload output file to bucket if it exists
if os.path.isfile("output.json"):
    output_obj.upload_file("output.json")
