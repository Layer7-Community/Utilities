import json
import re
import argparse
import os

def find_unused_services(services_json_content, log_content):
    # Parse services.json
    services_data = json.loads(services_json_content)
    all_services = []
    for service in services_data["services"]:
        all_services.append({
            "name": service["name"],
            "resolutionPath": service["resolutionPath"]
        })

    # Extract called resolution paths from logs based on the new pattern
    called_paths = set()
    # Regex to find "message":"Service called: <uri>" and extract <uri>
    # The URI starts with '/' and can contain any characters until the next double quote
    pattern = re.compile(r'"message":"Service called: (/.*?)"')

    for line in log_content.splitlines():
        match = pattern.search(line)
        if match:
            uri = match.group(1)
            called_paths.add(uri)

    # Identify uncalled and used services
    uncalled_services = []
    used_services = []
    for service in all_services:
        service_path = service["resolutionPath"]
        is_called = False

        if service_path.endswith("*"):
            base_path = service_path[:-1]
            for called_path in called_paths:
                if called_path.startswith(base_path):
                    is_called = True
                    break
        else:
            if service_path in called_paths:
                is_called = True
        
        if not is_called:
            uncalled_services.append(service)
        else:
            used_services.append(service)

    return uncalled_services, used_services

def format_services_table(heading, services_list):
    output = f"*** {heading} ***\n"
    if services_list:
        output += "| Service Name | Resolution Path |\n"
        output += "|--------------|-----------------|\n"
        for s in services_list:
            output += f"| {s['name']} | {s['resolutionPath']} |\n"
    else:
        output += f"No {heading.lower()} found.\n"
    return output

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Find unused services by comparing a services JSON file with a log file.")
    parser.add_argument("--services", required=True, help="Path to the services JSON file (e.g., services.json)")
    parser.add_argument("--traces", required=True, help="Path to the service traces log file (e.g., service_traces.logs)")
    
    args = parser.parse_args()

    # Read the services JSON file
    if not os.path.exists(args.services):
        print(f"Error: Services file not found at {args.services}")
        exit(1)
    with open(args.services, 'r') as f:
        services_json_content = f.read()

    # Read the log file
    if not os.path.exists(args.traces):
        print(f"Error: Traces file not found at {args.traces}")
        exit(1)
    with open(args.traces, 'r') as f:
        log_content = f.read()

    uncalled, used = find_unused_services(services_json_content, log_content)
    
    print(format_services_table("Unused services", uncalled))
    print("\n") # Add a newline for separation
    print(format_services_table("Used services", used))
