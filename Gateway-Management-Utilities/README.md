# Gateway Management Utilities
A suite of encapsulated assertions useful for calling RestMan directly from policy with a service to test the assertions (Utility Assertions Tester), plus the Gateway Dependency Analyzer utility that uses the assertions to query the Gateway and determine internal dependencies.

## Installation
Deploy using the GMU (assumes connection details are in &lt;gateway&gt;.properties):

`./GatewayMigrationUtility.sh migrateIn -z <gateway>.properties -b Gateway-Management-Utilities.xml -r results.xml`

## Accessing the Utility Assertions Tester service
Point your browser to https://&lt;gateway&gt;:8443/apigw/utilityTester and provide Policy Manager admin credentials. 

## Accessing the Dependency Analyzer service
Point your browser to https://&lt;gateway&gt;:8443/apigw/dependencyAnalyzer and provide Policy Manager admin credentials. 

*Note that restman requires an authenticated user who is a member of the administrator role to execute many of the calls to work, hence why admin credentials are required to use these services.*
