Layer7 does not maintain a Postman collection for its largely auto-generated Restman API. The API does provide a WADL specification that can be downloaded from the APIs documentation exposed by the gateway. This simple Postman collection example was created by converting the WADL to OAS 3.0 to Postman.

To convert the WADL to OAS 3.0, this [api-spec-converter](https://github.com/LucyBot-Inc/api-spec-converter) utility was used with this command line:

```api-spec-converter -f wadl -t openapi_3 restman.wadl > restman.json```

In theory, you should be able to import the OAS 3.0 specification directly to Postman, but in practice we've found that to be unreliable.

To convert OAS 3.0 to a Postman collection, this [openapi-to-postman](https://github.com/postmanlabs/openapi-to-postman) utility was used with this command line:

```openapi2postmanv2 -s restman.json -o postman.json```

Finally, basic authorization was configured (with a default user of **admin** and default password of **changeme**) and a baseURL variable (with a default host of **localhost**) in the collection's settings.