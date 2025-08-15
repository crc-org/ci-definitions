import json
import argparse
import requests
from datetime import datetime, timezone
import os

parser = argparse.ArgumentParser(description="upload performace test data to opensearch")
parser.add_argument("--index", help="opensearch index name", default="crc-test")
parser.add_argument("--attributes", help="test attributes")
parser.add_argument("--category", help="category of the performace data")
parser.add_argument("--path", help="the folder that contains the txt performace data")

args = parser.parse_args()

folder_path = args.path
if not folder_path or not os.path.isdir(folder_path):
    raise SystemExit(f"Invalid --path: {folder_path!r}")
txt_files = [f for f in os.listdir(folder_path) if f.endswith(".txt")]
if len(txt_files) == 0:
    raise SystemExit(f"No txt file in: {folder_path!r}")

all={}
for file_name in txt_files:
    file_path = os.path.join(folder_path, file_name)
    result = {}
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            if ":" in line:
                key, value = line.strip().split(":", 1)
                value = value.strip()
                result[key] = value
    title=file_name.strip().split(".", 1)[0]
    all[title]=result

custom_timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
all["timestamp"]=custom_timestamp
all["category"] = args.category
all["attributes"] = args.attributes

json_str = json.dumps(all, indent=2)
#print(json_str)

OPENSEARCH_URL = os.environ["url"]
USERNAME = os.environ["user"]
PASSWORD = os.environ["password"]
INDEX_NAME = args.index

url = f"{OPENSEARCH_URL}/{INDEX_NAME}/_doc"
response = requests.post(url, json=all, auth=(USERNAME, PASSWORD), verify=False)
print("Status Code:", response.status_code)
print("Response:", json.dumps(response.json(), indent=2))