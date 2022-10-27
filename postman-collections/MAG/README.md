# MAG API
This repository is for postman collections to perform a variety of operations with the MAG API.

## Environment Variables

### Input Variables

Name | Brief Description
----- | -----------------
*hostname* | *Gateway hostname or IP address*
*port* | *Gateway port*
*CWP_api_key* | *The apikey set in the cluster wide property mag.api.key to authenticate the API.*
*client_id* | *client id*
*adminUserName* | *admin user name*
*adminUserPassword* | *admin user password*
*adminUserSub* | *The sub(ject) that refers to the authenticated user.*
*nonAdminUserName* | *non admin user name*
*nonAdminUserPassword* | *non admin user password*
*deviceName* | *device name*
*deviceIdP* | *Password flow: device id*
*csrP* | *Password flow: CSR*
*deviceIdCC* | *Client credentials flow: device id*
*csrCC* | *CSR for client credentials flow*
*encodedAuthorization* | *Base64 encoded username and password*
*magIdentifierP* | *Password flow: mag identifier*
*magIdentifierCC* | *Client credentials flow: mag identifier*

### Temporary Variables used by collection

Name | Brief Description
----- | -----------------
*generatedClientIdP* | *Password flow: cliend id generated on initialization*
*generatedClientSecretP* | *Password flow: client secret generated on initialization*
*encodedClientAuthorizationP* | *Password flow: Base64 encoded generated client id and secret*
*accessTokenP* | *Password flow: access token*
*sessionDataP* | *Password flow: session data*
*generatedClientIdCC* | *Client credentials flow: client id generated on initialization*
*generatedClientSecretCC* | *Client credentials flow: client secret generated on initialization*
*encodedClientAuthorizationCC* | *Client credentials flow: Base64 encoded generated client id and secret*
*accessTokenCC* | *Client credentials flow: access token*
*sessionDataCC* | *Clent credentials flow: sessions data*
