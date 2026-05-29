
# Purpose #
The purpose of this script is to cross correlate information coming from the gateway (Graphman) with run time traces obtained over a perior of time, in order to find which services exposed by the gateway have not been used during that period of time.

# How to #
1/ The list of APIs/services defined on the gateway is obtained from graphman as follow:

    graphman export --gateway <gateway> --using services:summary --output services.json
    
The result of the output is in a file "service.json"

2/ This example assumes a global message received policy such as the "tracing_MessageReceived_policy.json" (Graphman bundle), which writes a message like "Service called: ${request.http.uri}" in the gateway audit/logs, is defined in the gateway. The result of the output is in a file "service_traces.logs". Whenever a service is called, a trace is generated. This trace includes the service URI.

3/ To find the list of used and unused services based on these two files, the python script "find_unused_services.py" is used as follows: 

    python3 find_unused_services.py --services services.json --traces service_traces.logs

The output looks is something like:

 #### Unused services ####
| Service Name | Resolution Path |
|--------------|-----------------|
| ACME | /ACMEWarehouse* |
| AI Basic | /ai/basic |
| Analyse a Certificate | /analyse/cert |
| Authenticate User | /auth/user |
| Bank Service | /bank |
...

#### Used services ####
| Service Name | Resolution Path |
|--------------|-----------------|
| echo | /echotest |
| test1 | /test1 |

# Modifications #
In case you use a different trace, you need to modify the Python script line 20 in order to adjust the regex:
    
    pattern = re.compile(r'"message":"Service called: (/.*?)"')