1/ The list of services defined on the gateway is obtained from graphman:
    graphman export --gateway <gateway> --using services:summary
    
The result of the output is in a file "service.json"

2/ Whenever a service is called, a trace is generated. This example assumes a global message received policy such as "tracing_MessageReceived_policy.json", which writes a message like "Service called: ${request.http.uri}" in the gateway logs. The result of the output is in a file "service_traces.logs"

3/ To find the list of used and unused services based on these two files, you can use the python script "find_unused_services.py" as follows: python3 find_unused_services.py --services services.json --traces service_traces.logs
