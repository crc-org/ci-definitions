import re
from datetime import datetime, timezone
import numpy as np
import pandas as pd


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
    return start, stop
            
def cpu_array_analyze(cpu_array):
    result={}
    if len(cpu_array) == 0:
        print("No data in the specified time range!")
    else:
        max_v = np.max(cpu_array)
        min_v = np.min(cpu_array)
        avg_v = np.mean(cpu_array)
        median_v = np.median(cpu_array)
        p95_v = np.percentile(cpu_array, 95)
        if avg_v != 0:
            peak_avg_ratio = max_v / avg_v
        else:
            # Define whatever behavior makes sense for your use case; 0.0 is a simple default.
            peak_avg_ratio = 0.0
        range_v = max_v - min_v
        std_v = np.std(cpu_array)
        q1 = np.percentile(cpu_array, 25)
        q3 = np.percentile(cpu_array, 75)
        iqr = q3 - q1

        spike_threshold = avg_v + 2*std_v
        spike_count = np.sum(cpu_array > spike_threshold)

        result["Max"] = round(float(max_v),2)
        result["Min"] = round(float(min_v),2)
        result["Mean"] = round(float(avg_v),2)
        result["Median"] = round(float(median_v),2)
        result["P95"] = round(float(p95_v),2)
        result["Peak/Mean Ratio"] = round(float(peak_avg_ratio),2)
        result["Range"] = round(float(range_v),2)
        result["Std"] = round(float(std_v),2)
        result["IQR"] = round(float(iqr),2)
        result["Spike Count"] = int(spike_count)
    return result

def analyze_cpu_data(cpu_file, time_stamp_file):
    start_time_range, stop_time_range = get_time_stamp(time_stamp_file)
    
    start_cpu = []
    stop_cpu = []
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
                    start_cpu.append(value)
                if stop_time_range[0] <= timestamp <= stop_time_range[1]:
                    stop_cpu.append(value)

    start_cpu_array = np.array(start_cpu)
    stop_cpu_array = np.array(stop_cpu)

    start_result = cpu_array_analyze(start_cpu_array)
    stop_result = cpu_array_analyze(stop_cpu_array)

    return start_result, stop_result

    
