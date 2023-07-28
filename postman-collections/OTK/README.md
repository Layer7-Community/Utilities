# OTK Postman collections
This repository is for postman collections for OTK.

:point_right: Note: These postman collections makes use of the [PMLIB](https://github.com/joolfe/postman-util-lib) Use self-signed certificates as instructed below.

## Environment Variables

### Input Variables

Name | Brief Description
----- | -----------------
*otk.host* | *Gateway hostname or IP address*
*otk.port* | *Gateway port*
*otk.username* | *Gateway user name*
*otk.password* | *Gateway user password*
*otk.jwk* | *Json Web Key - Public and Private Keypair*
*otk.jwk.public* | *Json Web Key - Public Key*
*otk.redirectUri* | *Redirect URI*

### Temporary Variables used by collection (cleaned when deleting otk client)

Name | Brief Description
----- | -----------------
*otk.temp.client_id* | *OTK client id*
*otk.temp.client_secret* | *OTK client secret*
*otk.temp.registration_access_token* | *OAuth client registration access token*
*otk.temp.session_d* | *OTK session id*
*otk.temp.session_data* | *OTK session data*
*otk.temp.nonce* | *Nonce*
*otk.temp.state* | *State*
*otk.temp.client_assertion* | *OTK client assertion*
*otk.temp.request_object* | *OTK request object*
*otk.temp.code_verifier* | *Code Verifier - FAPI Baseline*
*otk.temp.code_challenge* | *Cdde Challenge - FAPI Baseline*
*otk.temp.request_uri* | *PAR Request URI*
*otk.temp.auth_req_id* | *CIBA Auth request ID*
*otk.temp.expires_in* | *CIBA Auth request expires in*
*otk.temp.interval* | *CIBA Auth poll interval*
*otk.temp.counter* | *CIBA Auth poll counter*
*otk.temp.id_token* | *OAuth Id Token*
*otk.temp.access_token* | *OAuth Access token*
