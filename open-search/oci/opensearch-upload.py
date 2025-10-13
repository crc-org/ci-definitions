import json
import argparse
import requests
from datetime import datetime, timezone
import os
import sys
import analyzedata

parser = argparse.ArgumentParser(description="upload performace test data to opensearch")
parser.add_argument("--index", help="opensearch index name", default="crc-test")
parser.add_argument("--category", help="category of the performace data")
parser.add_argument("--path", help="the folder that contains the txt performace data")
parser.add_argument("--crc", help="the folder that contains the txt performace data")
parser.add_argument("--bundle", help="the folder that contains the txt performace data")


args = parser.parse_args()

folder_path = args.path
if not folder_path or not os.path.isdir(folder_path):
    raise SystemExit(f"Invalid --path: {folder_path!r}")
txt_files = [f for f in os.listdir(folder_path) if f.endswith(".txt")]
if len(txt_files) == 0:
    print("No txt file in {}".format(folder_path))
    sys.exit(0)

all={}
count=0
for file_name in txt_files:
    file_path = os.path.join(folder_path, file_name)
    if "time" in file_name:
        start, stop = analyzedata.analyze_time_file(file_path)
        if start is not None and stop is not None:
            all["time-start"] = start
            all["time-stop"] = stop
            count=count+1
    elif "cpu" in file_name:
        start, deployment, stop = analyzedata.analyze_cpu_file(file_path)
        if start is not None:
            all["cpu-start"] = start
            all["cpu-deployment"] = deployment
            all["cpu-stop"] = stop
            count=count+1
    elif "memory" in file_name:
        start, deployment, stop = analyzedata.analyze_memory_file(file_path)
        if start is not None:
            all["memory-start"] = start
            all["memory-deployment"] = deployment
            all["memory-stop"] = stop
            count=count+1
    else:
        print("{} not a performace txt file".format(file_name))

if count == 0:
    print("All performance files do not have enough data")
    sys.exit(0)

custom_timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
all["timestamp"]=custom_timestamp
all["category"] = args.category
all["crc"] = args.crc
all["bundle"] = args.bundle

#print(all)
#json_str = json.dumps(all, indent=2)

OPENSEARCH_URL = os.environ["url"]
USERNAME = os.environ["user"]
PASSWORD = os.environ["password"]
INDEX_NAME = args.index

url = f"{OPENSEARCH_URL}/{INDEX_NAME}/_doc"
response = requests.post(url, json=all, auth=(USERNAME, PASSWORD), verify=False)
print("Status Code:", response.status_code)
print("Response:", json.dumps(response.json(), indent=2))
