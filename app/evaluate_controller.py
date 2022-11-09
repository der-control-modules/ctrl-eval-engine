"""
Evaluate the controller specified in input file

Input file: input.json
Log file: log.txt
Output file: output.json
"""

import json
import logging
from time import sleep

logging.basicConfig(
    filename="log.txt",
    encoding="utf-8",
    filemode="w",
    style="{",
    format="{asctime} - {levelname:8}: {message}",
    level=logging.INFO,
)


def evaluate():
    """Evaluate the performance of the specified controller"""

    for step in range(10):
        logging.info("Step %d", step)
        sleep(6)

    logging.warning("Sample warning message")
    logging.error("Sample error message")
    output = {"sample key": "sample value"}
    return output


if __name__ == "__main__":
    logging.info("Loading input...")
    with open("input.json", "r", encoding="utf-8") as in_file:
        input_dict = json.load(in_file)

    output_json = evaluate()

    logging.info("Writing output file...")
    with open("output.json", "w", encoding="utf-8") as out_file:
        json.dump(output_json, out_file)
