import re
import xml.etree.ElementTree as ET
from xml.dom import minidom
import sys

def log_to_xml_with_steps(log_file, xml_file, fail_flag):
    # Create the root element for XML
    root = ET.Element("testsuites", name="pipeline-logs")
    suit_element = ET.SubElement(root, "testsuite", name='piplinerun')
    case_element = ET.SubElement(suit_element, "testcase",name='logs')
    root.set("tests", "1")
    if fail_flag:
        suit_element.set("failures", "1")
        suit_element.set("status", "failed")
        ET.SubElement(
            case_element,
            "failure",
            message="Pipeline failed",
            type="PipelineFailure"
        )
    else:
        suit_element.set("failures", "0")
        suit_element.set("status", "passed")

    step_element = None
    task_element = None
    # Open the log file and process each line
    with open(log_file, "r") as file:
        task=''
        step=''
        log=''
        for line in file:

            # Check if the line indicates a new step
            step_match = re.match(r"^\[", line)
            if step_match:
                # If a new step is detected, create a new <step> element
                line_contents=line.split("]")
                task_info=line_contents[0].split(":")
                task_name=task_info[0].removeprefix('[')
                step_name=task_info[1].removeprefix(' ')
                content=line_contents[1]
                if (task_name != task) | (step_name != step):
                    if step_element != None:
                        infos = "["+ task + ":" + step +"]"+"\n"
                        log=infos+log
                        ET.SubElement(step_element, "system-out").text = log.strip()
                        log=""
                    if task_name != task:
                        task_element = ET.SubElement(case_element, "task", name=task_name)
                    step_element = ET.SubElement(task_element, "step", name=step_name)
                log=log+content
                task=task_name
                step=step_name
            elif log != '':
                log=log+line
        ET.SubElement(step_element, "system-out").text = log.strip()    

    # Write the XML tree to a file
    xml_str = ET.tostring(root, encoding="utf-8").decode("utf-8")
    xml_str = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', xml_str)
    pretty_xml = minidom.parseString(xml_str).toprettyxml(indent="  ")
    with open(xml_file, "w") as f:
        f.write(pretty_xml)

    print(f"Log file with steps converted to XML report: {xml_file}")


if len(sys.argv) < 4:
    print("Usage: python example.py <param1> <param2> <param3>")
    sys.exit(1)

log_file = sys.argv[1]  # First parameter
xml_file = sys.argv[2]
fail_flag = sys.argv[3].lower() == "true"
log_to_xml_with_steps(log_file, xml_file, fail_flag)
