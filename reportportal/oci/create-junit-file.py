#!/usr/bin/env python3
import sys
import json
import json
from junitparser import TestCase, TestSuite, JUnitXml, Failure

if len(sys.argv) < 4: 
    print('should be 3 arguments')
    sys.exit(1)

suite_name = "pipelinerun-taskruns"

json_file = sys.argv[1]
xml_file = sys.argv[2]
fail_flag = sys.argv[3].lower() == 'true'


with open(json_file, mode="r", encoding="utf-8") as f:
    testcases_map = json.load(f)

# Create a new JunitXml file
xml = JUnitXml()
suite = TestSuite(suite_name)
xml.add_testsuite(suite)

# Create a single test case if the failFlag false, to have logs on the rp
if not fail_flag:
    # Accumulate all logs under a single testcase
    combined_logs = []
    testcase = TestCase("pipeline-logs")

    for taskrun_name, testcase_data in testcases_map.items():
        taskrun_status = testcase_data.get("status", "")
        taskrun_logs = testcase_data.get("logs", "")

        sanitized_logs = ''.join(
            c for c in taskrun_logs if ord(c) >= 32 or c in '\n\r\t'
        )

        combined_logs.append(f"\n===== {taskrun_name} =====\n{sanitized_logs}")

    testcase.system_out = "\n".join(combined_logs)
    suite.add_testcase(testcase)


else: 
    first_testcase = None
# Process all test cases
    for taskrun_name, testcase_data in testcases_map.items():
        taskrun_status = testcase_data.get('status')
        taskrun_logs = testcase_data.get('logs')
        
        testcase = TestCase(taskrun_name)
        sanitized_logs = ''.join(char for char in taskrun_logs if ord(char) >= 32 or char in '\n\r\t')
        testcase.system_out = sanitized_logs
        
        if taskrun_status.lower() != 'true':
            testcase.result = [Failure(f"Task {taskrun_name} failed")]
        
        suite.add_testcase(testcase)
        
        if first_testcase is None:
            first_testcase = testcase

    # If all test cases pass, add fallback failure to first test case
    if suite.failures == 0:
        if first_testcase:
            has_failure = first_testcase.result and any(isinstance(r, Failure) for r in first_testcase.result)
            if not has_failure:
                first_testcase.result = [Failure()]

suite.update_statistics()
xml.write(xml_file)
