import re
from datetime import datetime, timezone



def analyze_time_file(file_path):
    start_list = []
    stop_list = []
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            if ":" in line:
                key, value = line.strip().split(":", 1)
                value = value.strip()
                if "start" in key:
                    start_list.append(covert_to_seconds(value))
                else:
                    stop_list.append(covert_to_seconds(value))
    return average(start_list), average(stop_list)


def covert_to_seconds(time_str: str) -> int:

    pattern = r'^\s*(?:(\d+)m)?(?:(\d+(?:\.\d+)?)s)?\s*$'
    match = re.match(pattern, time_str)

    if not match:
        raise ValueError(f"Invalid time format: '{time_str}'")

    minutes = int(match.group(1)) if match.group(1) else 0
    seconds = float(match.group(2)) if match.group(2) else 0.0

    total_seconds = minutes * 60 + seconds
    return int(total_seconds) 


def average(numbers):
    if not numbers:  # avoid division by zero
        return 0
    return sum(numbers) / len(numbers)


def analyze_cpu_file(file_path):
    cpu_list = []
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            if ":" in line:
                temp = line.replace('[', '|').replace(']', '|')
                key, value, other = temp.strip().split("|")
                cpu = float(value)
                cpu_list.append(cpu)
    start = cpu_list[1] - cpu_list[0]
    deployment = cpu_list[2] - cpu_list[0]
    stop = cpu_list[3] - cpu_list[0]
    return start, deployment, stop



def analyze_memory_file(file_path):
    memory_list = []
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            if ":" in line:
                parts = line.strip().split(" ")
                memory = int(parts[5])
                memory_list.append(memory)
    start = memory_list[0] - memory_list[1]
    deployment = memory_list[0] - memory_list[2]
    stop = memory_list[0] - memory_list[3]
    return start, deployment, stop
