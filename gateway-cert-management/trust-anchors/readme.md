## Managing Trust Anchors
By default the Gateway ships with an empty trust store. The following Java Argument can be set to use the default JRE cacerts list. AI assistance has been used to generate some or all contents of this file. That includes, but is not limited to, new code, modifying existing code, stylistic edits.

- -Dcom.l7tech.server.pkix.useDefaultTrustAnchors=true

This means you don't need to maintain the same list in the Gateway Trusted Certificate Store. It is tied to the JDK version

#### Override the default (cacerts) list
- The default path is `/usr/lib/jvm/default-jvm/lib/security/cacerts`

#### What if you have your own list?
- Replace the default list with your own
  - see the [gateway example](../gateways/) where a custom list is mounted.
- Combine them
  - `python3 curate-cacerts.py --combine cacerts.der other.der combined.der`
- Use Gateway Trusted Certificate Store
  - we recommend using roots and intermediates as trust anchors
    - they have longer expiries (less management overhead)
    - leaf certificates will reduce to a 47 day expiry time in 2029


### Example
cacerts list taken from container gateway v11.1.3

#### List
python3 curate-cacerts.py list
python3 curate-cacerts.py list --check-revocation

#### Remove by country
python3 curate-cacerts.py --remove GB

#### Combine
python3 curate-cacerts.py --combine cacerts.der other.der combined.der

#### Compare
python3 curate-cacerts.py --compare cacerts.der cacerts.no-gb.der