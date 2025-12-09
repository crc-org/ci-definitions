import re
from datetime import datetime, timezone
import numpy as np
import pandas as pd
import sys

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
    if len(start_list) > 0:
        start = average(start_list)
    else:
        start = None
    if len(stop_list) > 0:
        stop = average(stop_list)
    else:
        stop = None
    return start, stop


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


def analyze_memory_file(file_path):
    memory_list = []
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            if ":" in line:
                parts = line.strip().split(" ")
                memory = int(parts[5])
                memory_list.append(memory)
    if len(memory_list) < 4:
        print(f"Expected >=4 memory samples in {file_path}, got {len(memory_list)}")
        return None, None, None
    start = memory_list[0] - memory_list[1]
    deployment = memory_list[0] - memory_list[2]
    stop = memory_list[0] - memory_list[3]
    return start, deployment, stop

def get_time_stamp(time_stamp_path):
    start=[]
    stop=[]
    with open(time_stamp_path, "r") as f:
        for line in f:
            line = line.strip()
            match = re.match(r"\[(.*?)\], (.*)", line)
            if match:
                timestamp_str = match.group(1)
                event = match.group(2).lower()
                if "start" == event:
                    start.append(timestamp_str)
                elif "deployment" == event:
                    start.append(timestamp_str)
                elif "stop" == event:
                    stop.append(timestamp_str)
                elif "start again" == event:
                    stop.append(timestamp_str)
    if len(start) != 2 or len(stop) != 2:
        print("The timestamp is not enough")
        sys.exit(0)
    return start, stop
            
def cpu_array_analyze(cpu_array):
    result=[]
    if len(cpu_array) == 0:
        print("No data in the specified time range!")
    else:
        CPUArray = np.array(cpu_array)
        gt_80 = len(CPUArray[CPUArray > 80])
        lt_20 = len(CPUArray[CPUArray < 20])
        lt_10 = len(CPUArray[CPUArray < 10])

        max_v = np.max(CPUArray)
        min_v = np.min(CPUArray)
        avg_v = np.mean(CPUArray)
        p95_v = np.percentile(CPUArray, 95)
        std_v = np.std(CPUArray)
        spike_threshold = avg_v + 2*std_v
        spike_count = np.sum(CPUArray > spike_threshold)

        result.append({
            "max": round(float(max_v),2),
            "Min": round(float(min_v),2),
            "Mean": round(float(avg_v),2),
            "P95": round(float(p95_v),2),
            "Std": round(float(std_v),2),
            "Spike Count": int(spike_count),
            "gt_80": int(gt_80),
            "lt_20": int(lt_20),
            "lt_10": int(lt_10)
        })
    return result

def analyze_cpu_data(cpu_file, time_stamp_file):
    start_time_range, stop_time_range = get_time_stamp(time_stamp_file)

    start_cpu = []
    start_array = []
    stop_cpu = []
    stop_array = []
    with open(cpu_file, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            match = re.match(r"\[(.*?)\], cpu percent: ([\d.]+)%", line)
            if match:
                timestamp = match.group(1)
                value = float(match.group(2))
                if start_time_range[0] <= timestamp <= start_time_range[1]:
                    start_cpu.append({
                        "time": timestamp,
                        "cpu": value
                    })
                    start_array.append(value)
                if stop_time_range[0] <= timestamp <= stop_time_range[1]:
                    stop_cpu.append({
                        "time": timestamp,
                        "cpu": value
                    })
                    stop_array.append(value)
    
    start_result = {}
    stop_result = {}
    start_result["cpu_data"] = start_cpu
    start_result["derived"] = cpu_array_analyze(start_array)
    stop_result["cpu_data"] = stop_cpu
    stop_result["derived"] = cpu_array_analyze(stop_array)
    
    return start_result, stop_result

    
