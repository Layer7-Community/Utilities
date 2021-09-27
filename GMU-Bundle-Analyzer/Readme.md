# GMU Bundle Analyzer Script
This script analyzes a single file bundle produced using the migrateOut command of the Gateway Migration Utility (GMU).

## Installation
The script uses the xpath command, which is a CLI front end to the XML::XPath perl library written by fabien@tzone.org. Otherwise is should "just work".

## Command line parameters:
```
  -b <file>     : Bundle file name
  -F            : Full analysis (include SOLUTION_KIT, RBAC_ROLES, etc)
  -D            : Analyze dependencies
  -d            : Debug mode (print extra information)
  -q            : Quiet output - only display analysis section
  -l            : Log details to SSG-AnalyzeBundle.log
  -h            : Print this list and exit

Exit status 0 if success, 1 if not
```

## Sample Output:
```
$ ./SSG-AnalyzeBundle.sh -b ~/Downloads/ssgdev-ssp.xml
./SSG-AnalyzeBundle.sh - Analyse a GMU bundle exported from a Layer 7 API Gateway

=> Configuration summary:
=> Determining how to call xpath command: 'xpath -q -e'
=> Loading items from /home/jay/Downloads/ssgdev-ssp.xml....................................................
=> Determining cluster hostname: ssgdev.demo-01.trial-ssp.com
=> Processing folders..
b8fe7c6eceae265b743df094aa103aa4 b8fe7c6eceae265b743df094aa103aa5
=> Determining root folder ID: b8fe7c6eceae265b743df094aa103aa4
=> Determining folder paths..
=> Processing services..........................
=> Processing policies........
=> Processing encapsulated assertions......
=> Processing cluster properties.....
=> Processing SSG keys..
=> Processing scheduled tasks
=> Processing identity providers..
=> Processing users
=> Processing groups

Analysis of /home/jay/Downloads/ssgdev-ssp.xml:

Statistics:
  Folders: 2
  Services: 26
  Policies: 8
  Encapsulated Assertions: 6
  Cluster Properties: 5
  Private Keys: 2
  Scheduled Tasks: 0
  Identity Providers: 2
  Users: 0
  Groups: 0

Items by Type:
  CLUSTER_PROPERTY:
    0000000000000000fffffffffff5519f : cluster.hostname
    4c09d0a225909164e8b37ca6c740b5fe : ssp-webapp.clientid
    828e2392c800b1ecc669b4747e6157a1 : ssp.host
    b8fe7c6eceae265b743df094aa103aa9 : ssp.tenent
    cd0aef8090861dc6be587192c324d267 : custom.risk.provider.apikey
  POLICY:
    4c09d0a225909164e8b37ca6c740b32f : SSP - JWT Validate
    b8fe7c6eceae265b743df094aa103a80 : SSP - Factor Selection
    b8fe7c6eceae265b743df094aa103a81 : SSP - Token Validation using Signature
    b8fe7c6eceae265b743df094aa103a95 : SSP - Authenticate
    b8fe7c6eceae265b743df094aa103a96 : SSP - OTP Process Flow
    b8fe7c6eceae265b743df094aa103a97 : SSP - Route
    b8fe7c6eceae265b743df094aa103a98 : SSP - Request Token
    cd0aef8090861dc6be587192c324d283 : SSP - Custom Risk Provider API Key Validate
  SSG_KEY_ENTRY:
    00000000000000000000000000000002:ssl : ssl
    00000000000000000000000000000002:demosigningcert : demosigningcert
  SERVICE:
    3d2380a4dfb34b611fca62906fe45408 : SSP - Client Request LDAP AuthN
    3d2380a4dfb34b611fca62906fe45ba7 : SSP - Client Request Initiate
    3d2380a4dfb34b611fca62906fe638b0 : SSP - Evaluate RISK
    3d2380a4dfb34b611fca62906fe6fe5f : SSP - Client Request Re-Authenticate
    4c09d0a225909164e8b37ca6c7406505 : SSP - SSD Registration
    4c09d0a225909164e8b37ca6c74069f8 : SSP - SSD Generate JWT
    679fe67e8d29e1e810fc8a54b267d303 : SSP Admin-IARISK
    679fe67e8d29e1e810fc8a54b267e099 : SSP Admin-LDAPUSER
    b8fe7c6eceae265b743df094aa103a88 : Authorize - Redirect URL
    b8fe7c6eceae265b743df094aa103a89 : SSP - Bearer Token Call Introspect
    b8fe7c6eceae265b743df094aa103a8a : SSP - Client Factor Selection
    b8fe7c6eceae265b743df094aa103a8b : SSP - Client Request Access Token
    b8fe7c6eceae265b743df094aa103a8c : SSP - Client OTP Flow
    b8fe7c6eceae265b743df094aa103a8d : ssp - default-WellKnown Config
    b8fe7c6eceae265b743df094aa103a8e : SSP - OAuth2 - Operations
    b8fe7c6eceae265b743df094aa103a8f : SSP - Client Request Authenticate
    b8fe7c6eceae265b743df094aa103a90 : SSP - Bearer Token Call Signature
    b8fe7c6eceae265b743df094aa103a91 : SSP - UI - Operations
    b8fe7c6eceae265b743df094aa103a93 : SSP - Admin-Operation
    b8fe7c6eceae265b743df094aa103a94 : SSP - IPAddress -Operation
    cd0aef8090861dc6be587192c31e0482 : SSP - SSD LDAP USER INFO
    cd0aef8090861dc6be587192c31ea4bf : SSP - SSD LDAP USER ZFP Request
    cd0aef8090861dc6be587192c31ef39d : SSP - SSD LDAP USER PASSWORD CHANGE
    cd0aef8090861dc6be587192c31f3ec6 : SSP - SSD USER UNLOCK
    cd0aef8090861dc6be587192c3249fde : SSP - SPI Custome Risk Provider
    cd0aef8090861dc6be587192c324dd97 : SSP - SPI Custome Risk Provider
  SECURE_PASSWORD:
    935d50b8764bd96ba041f8ab2b45e762 : SSD
  ENCAPSULATED_ASSERTION:
    b8fe7c6eceae265b743df094aa103a86 : SSP - Route
    4c09d0a225909164e8b37ca6c740b6b8 : SSP - Validate JWT
    b8fe7c6eceae265b743df094aa103a83 : SSP - Request Token
    b8fe7c6eceae265b743df094aa103a85 : SSP - OTP Process Flow
    b8fe7c6eceae265b743df094aa103a87 : SSP - Token Validation using Signature
    cd0aef8090861dc6be587192c3252698 : SSP - SPI APIKey Validation
  FOLDER:
    b8fe7c6eceae265b743df094aa103aa4 : ssp
    b8fe7c6eceae265b743df094aa103aa5 : Security
  ID_PROVIDER_CONFIG:
    4c09d0a225909164e8b37ca6c74065b9 : VIP Auth-Hub - Demo-01 SSD Env
    0000000000000000fffffffffffffffe : Internal Identity Provider

Tree:
ssp/
\_ Security/
|   \_ SSP - JWT Validate (POLICY)
|   \_ SSP - Factor Selection (POLICY)
|   \_ SSP - Token Validation using Signature (POLICY)
|   \_ SSP - Authenticate (POLICY)
|   \_ SSP - OTP Process Flow (POLICY)
|   \_ SSP - Route (POLICY)
|   \_ SSP - Request Token (POLICY)
|   \_ SSP - Custom Risk Provider API Key Validate (POLICY)
\_ SSP - Client Request LDAP AuthN (SERVICE)
\_ SSP - Client Request Initiate (SERVICE)
\_ SSP - Evaluate RISK (SERVICE)
\_ SSP - Client Request Re-Authenticate (SERVICE)
\_ SSP - SSD Registration (SERVICE)
\_ SSP - SSD Generate JWT (SERVICE)
\_ SSP Admin-IARISK (SERVICE)
\_ SSP Admin-LDAPUSER (SERVICE)
\_ Authorize - Redirect URL (SERVICE)
\_ SSP - Bearer Token Call Introspect (SERVICE)
\_ SSP - Client Factor Selection (SERVICE)
\_ SSP - Client Request Access Token (SERVICE)
\_ SSP - Client OTP Flow (SERVICE)
\_ ssp - default-WellKnown Config (SERVICE)
\_ SSP - OAuth2 - Operations (SERVICE)
\_ SSP - Client Request Authenticate (SERVICE)
\_ SSP - Bearer Token Call Signature (SERVICE)
\_ SSP - UI - Operations (SERVICE)
\_ SSP - Admin-Operation (SERVICE)
\_ SSP - IPAddress -Operation (SERVICE)
\_ SSP - SSD LDAP USER INFO (SERVICE)
\_ SSP - SSD LDAP USER ZFP Request (SERVICE)
\_ SSP - SSD LDAP USER PASSWORD CHANGE (SERVICE)
\_ SSP - SSD USER UNLOCK (SERVICE)
\_ SSP - SPI Custome Risk Provider (SERVICE)
$
```
