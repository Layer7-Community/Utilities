# OTK Postman collections
This repository is for postman collections for OTK.

:point_right: Note: These postman collections makes use of the [PMLIB](https://github.com/joolfe/postman-util-lib) Use self-signed certificates.

## Environment Variables

### Input Variables

Name | Brief Description | Default
----- | ----------------- | ------
*otk.host* | *Gateway hostname or IP address*
*otk.port* | *Gateway port*
*otk.username* | *Gateway user name*
*otk.password* | *Gateway user password*
*otk.jwk* | *Json Web Key - Public and Private Keypair* | { "p": "7dfNXFEvg5k-ztA59CUOPK4WCBRoihFctC2kkc25YNBsty0EUs5UEiQeBP8U_6eyCVqswo2RCbUmHP3TGGxJt_ZrpDznEJzTZcqOfY20o72VJMaqtg4UN99CDojEfuJpvP4IzZgHbCSyX2QRovEgzfGcxm8Kl5EAVGO9ONP2dGk",  "kty": "RSA",  "q": "60U5yX4EuSLFJYIk4J215nS_fERZKY4Exb9ps5mqQx34Gonr-i3MpF98tMsN0wuU8p4BGzdlQVMdXHWs2WJ9nW8xZ12MxhoRlAaAak5Y96N8_GAH6-taEO2kq4K84W1z8Ej1YZkbftG0OzILjZA-idMWGAHtgWdbQMuw7xSxv-k",  "d": "AQPWrMlD9Nk5ELhfHjmChDVr2_Yl94SnhYFgAFoUWau73AnqPiCa9PhFwjERP5U753A8ooV_RxXxnZaG5HHFpXSu-kZkj7Zfnr7O7EDutf-6IbmUXRigbD2EqNdJ_rwHC8NxFON2SPT-7kGgdqf2uZcqlo07il9JNZBzloMV0T6NFGJBmsXhwXdY4VJmTymN11UEgUUBc8CJn4e_jGrDoGWXLunovWDd9V5D_-sjmudoBpQ11oxklWyerQeU5RYZEtNYOiH7YemZLlDawYff2TNInjgv_BUsvKk4o_IHW-_qQNJy67OHTmsdXm-KyO4Cpl8bZgBqxuSn4871eAtFcQ",  "e": "AQAB",  "use": "sig",  "kid": "k78mU12dNx-OUCBt9RhwrfjMtfjqvNRR3giRtLFnNBs",  "qi": "Ulvq1na8z3NG39F5HI9uXz1sMznCSDiBYzGWFr8NmsOAyTEtlBeB_pxf1pl6P_bGM-Q1clT9V7_sKJtAgfyAS6Xv1ReRJVfK574KSBTeEXwdkG3agbpkSYTvTVL0Z7NxtkrbTCcT68LuVlmTYlAkhpi6yx39d_T6bsWB_D_qCLs",  "dp": "TXe2udTvputpG6-S0MSpCHajUmpjSmUxTrZ3Hc5mDPSWFGujNt1hYK9G39W9ny-du5I_Jvc5QHIyQcsi0JekwziOAuabVDvgVw1Mr_RR2-tKArp6q-WWDES5nUZKyhEw44_SijR0ZnLlblCHtgzX5HxH1hIg3xEpjFMYNMRFR9E",  "alg": "PS256",  "dq": "sbMLvqCsOJmGhpoR-IWmSnaL2vRU1AosmJ_G2pyJ-T-9kW3zCndlRhHJQ1TLEEiDK-0jsMbad8irOJa5A0hc0HiXvBbwqQAvnrp6a9DZadHWKVjvIsYUtQyJf_GzcCEXnLm-fQUDu3nww3U9PKNiWP9ShLeQCFlkl0BCV5It32E",  "n": "2pVqXlim5Z9eMsfF21WdwvWhzjHAcrAHGr3hTmQnkUVGj5kgsV5gkAp3iuyxFQutC4FHRR7tDWAZFT2K3dvYDbylkH1xn2K7ZAOvxqz10VIJ0Fk-TsQE73Tf8gQ_l3fHV6-2u0RvRdjJ-9egVuJtZ1kb2nmiHMF88d1WduCUz9tsuNhj7wnmcSx5UOSx16bJqT_p9Gup3XEdNYCfX2ubxlF6gIw0eJE9EO_ZChhT5KXz0Thqtd1CBAS1NoxJ-eo6cZePxn3i0sI0PS8sM7WZKKPlybri2uP-NvMOyZUKW-8FmBmT7wc5ZCxSKgDGEWDpeD53qfyRZ6RgMEtjfMNKkQ"}
*otk.jwk.public* | *Json Web Key - Public Key*| {"kty": "RSA","e": "AQAB","use": "sig","kid": "k78mU12dNx-OUCBt9RhwrfjMtfjqvNRR3giRtLFnNBs","alg": "PS256","x5c": [ "MIIDgTCCAmkCFE9BrFsddQqoMr1JVXEj1YaztNkTMA0GCSqGSIb3DQEBCwUAMH0xCzAJBgNVBAYTAklOMQwwCgYDVQQIDANIWUQxCzAJBgNVBAcMAlRHMREwDwYDVQQKDAhicm9hZGNvbTEMMAoGA1UECwwDSU1HMR0wGwYDVQQDDBRjYjYxcXYyLkJyb2FkY29tLm5ldDETMBEGCSqGSIb3DQEJARYEdGVzdDAeFw0yMzA2MjcxMzM4MDhaFw0yNDA2MjYxMzM4MDhaMH0xCzAJBgNVBAYTAklOMQwwCgYDVQQIDANIWUQxCzAJBgNVBAcMAlRHMREwDwYDVQQKDAhicm9hZGNvbTEMMAoGA1UECwwDSU1HMR0wGwYDVQQDDBRjYjYxcXYyLkJyb2FkY29tLm5ldDETMBEGCSqGSIb3DQEJARYEdGVzdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANqVal5YpuWfXjLHxdtVncL1oc4xwHKwBxq94U5kJ5FFRo+ZILFeYJAKd4rssRULrQuBR0Ue7Q1gGRU9it3b2A28pZB9cZ9iu2QDr8as9dFSCdBZPk7EBO903/IEP5d3x1evtrtEb0XYyfvXoFbibWdZG9p5ohzBfPHdVnbglM/bbLjYY+8J5nEseVDksdemyak/6fRrqd1xHTWAn19rm8ZReoCMNHiRPRDv2QoYU+Sl89E4arXdQgQEtTaMSfnqOnGXj8Z94tLCND0vLDO1mSij5cm64trj/jbzDsmVClvvBZgZk+8HOWQsUioAxhFg6Xg+d6n8kWekYDBLY3zDSpECAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAKr/4sQAKxgsY8ac09lmUAuRUoaPB17zd3eNyJR+SjxV5uoxannb07dpMPraB0drNB8qPl+w/3xWyeKui7tHLi2u8Lc9MtDb7TJDPuC+W7rpm1QdC+2TolfiO1Ul9HDhJfS+WUkOW+imcWaNRiiH6AQT0BkJ+DjAX7jUOZHAgJmI2oTRBjAmJ6PfOO5thg2n5nreYJqmJ13kArAe2kXckZghBwCRMNDbe2XBeONhZYHtxXj1VfyVGm4uDjPukzxR7yEpw/RGUkL4v9MV3gmk6l4VbpZ09MF79KobsWOjDDsoGS9xWUGxC4rYX+H3t67Y7PX6n2wi3swubh1w8Co0Prw==" ],"n": "2pVqXlim5Z9eMsfF21WdwvWhzjHAcrAHGr3hTmQnkUVGj5kgsV5gkAp3iuyxFQutC4FHRR7tDWAZFT2K3dvYDbylkH1xn2K7ZAOvxqz10VIJ0Fk-TsQE73Tf8gQ_l3fHV6-2u0RvRdjJ-9egVuJtZ1kb2nmiHMF88d1WduCUz9tsuNhj7wnmcSx5UOSx16bJqT_p9Gup3XEdNYCfX2ubxlF6gIw0eJE9EO_ZChhT5KXz0Thqtd1CBAS1NoxJ-eo6cZePxn3i0sI0PS8sM7WZKKPlybri2uP-NvMOyZUKW-8FmBmT7wc5ZCxSKgDGEWDpeD53qfyRZ6RgMEtjfMNKkQ"}
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
