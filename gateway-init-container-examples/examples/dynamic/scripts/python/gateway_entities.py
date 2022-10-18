from uuid import uuid4
from xml.sax.saxutils import escape as xml_escape
import gateway_crypto

def new_goid():
    return uuid4().hex

def bool_str(boolean):
    return str(boolean).lower()

def bundle_cert(name, cert, verify_hostname=False):
    goid = new_goid()

    pem = gateway_crypto.cert_bytes_to_b64_der(cert)

    return f'''<?xml version="1.0" encoding="UTF-8"?>
        <l7:Bundle xmlns:l7="http://ns.l7tech.com/2010/04/gateway-management">
        <l7:References>
            <l7:Item>
                <l7:Name>{name}</l7:Name>
                <l7:Id>{goid}</l7:Id>
                <l7:Type>TRUSTED_CERT</l7:Type>
                <l7:Resource>
                    <l7:TrustedCertificate id="{goid}">
                        <l7:Name>{name}</l7:Name>
                        <l7:CertificateData>
                            <l7:Encoded>{pem}</l7:Encoded>
                        </l7:CertificateData>
                        <l7:Properties>
                            <l7:Property key="revocationCheckingEnabled">
                                <l7:BooleanValue>true</l7:BooleanValue>
                            </l7:Property>
                            <l7:Property key="trustAnchor">
                                <l7:BooleanValue>true</l7:BooleanValue>
                            </l7:Property>
                            <l7:Property key="trustedAsSamlAttestingEntity">
                                <l7:BooleanValue>false</l7:BooleanValue>
                            </l7:Property>
                            <l7:Property key="trustedAsSamlIssuer">
                                <l7:BooleanValue>false</l7:BooleanValue>
                            </l7:Property>
                            <l7:Property key="trustedForSigningClientCerts">
                                <l7:BooleanValue>true</l7:BooleanValue>
                            </l7:Property>
                            <l7:Property key="trustedForSigningServerCerts">
                                <l7:BooleanValue>true</l7:BooleanValue>
                            </l7:Property>
                            <l7:Property key="trustedForSsl">
                                <l7:BooleanValue>true</l7:BooleanValue>
                            </l7:Property>
                            <l7:Property key="verifyHostname">
                                <l7:BooleanValue>{bool_str(verify_hostname)}</l7:BooleanValue>
                            </l7:Property>
                        </l7:Properties>
                    </l7:TrustedCertificate>
                </l7:Resource>
            </l7:Item>
        </l7:References>
        <l7:Mappings>
            <l7:Mapping action="NewOrUpdate" srcId="{goid}" type="TRUSTED_CERT" />
        </l7:Mappings>
        </l7:Bundle>'''

def certificate_data(cert):
    encoded_cert = gateway_crypto.cert_obj_to_b64_der(cert)
    return f'''
                            <l7:CertificateData>
                                <l7:IssuerName>{cert.issuer.rfc4514_string()}</l7:IssuerName>
                                <l7:SerialNumber>{cert.serial_number}</l7:SerialNumber>
                                <l7:SubjectName>{cert.subject.rfc4514_string()}</l7:SubjectName>
                                <l7:Encoded>{encoded_cert}</l7:Encoded>
                            </l7:CertificateData>'''

def bundle_private_key(name, p12_data, key_pass, cluster_pass):
    key, certs, algorithm = gateway_crypto.load_key_certs(p12_data, key_pass)

    cert_data = ''.join(certificate_data(cert) for cert in certs)
    bundle_key, key_data = gateway_crypto.encrypt_key(cluster_pass, key)

    # TODO: specialPurposes: is it problematic if multiple keys have `Default SSL Key` even if the default key isn't used?

    return f'''<?xml version="1.0" encoding="UTF-8"?>
        <l7:Bundle xmlns:l7="http://ns.l7tech.com/2010/04/gateway-management">
        <l7:References>
            <l7:Item>
                <l7:Name>{name}</l7:Name>
                <l7:Id>00000000000000000000000000000002:{name}</l7:Id>
                <l7:Type>SSG_KEY_ENTRY</l7:Type>
                <l7:Resource>
                    <l7:PrivateKey alias="{name}" keystoreId="00000000000000000000000000000002" id="00000000000000000000000000000002:{name}">
                        <l7:CertificateChain>{cert_data}
                        </l7:CertificateChain>
                        <l7:Properties>
                            <l7:Property key="keyAlgorithm">
                                <l7:StringValue>{algorithm}</l7:StringValue>
                            </l7:Property>
                            <l7:Property key="keyData">
                                <l7:StringValue bundleKey="{bundle_key}" algorithm="{algorithm}">{key_data}</l7:StringValue>
                            </l7:Property>
                            <l7:Property key="specialPurposes">
                                <l7:StringValue>Default SSL Key</l7:StringValue>
                            </l7:Property>
                        </l7:Properties>
                    </l7:PrivateKey>
                </l7:Resource>
            </l7:Item>
        </l7:References>
        <l7:Mappings>
            <l7:Mapping action="NewOrUpdate" srcId="00000000000000000000000000000002:{name}" type="SSG_KEY_ENTRY" />
        </l7:Mappings>
        </l7:Bundle>'''

def bundle_stored_secret(name, value, cluster_pass):
    goid = new_goid()

    bundle_key, key_data = gateway_crypto.encrypt_key(cluster_pass, value)

    return f'''<?xml version="1.0" encoding="UTF-8"?>
        <l7:Bundle xmlns:l7="http://ns.l7tech.com/2010/04/gateway-management">
        <l7:References>
            <l7:Item>
                <l7:Name>{name}</l7:Name>
                <l7:Id>{goid}</l7:Id>
                <l7:Type>SECURE_PASSWORD</l7:Type>
                <l7:Resource>
                    <l7:StoredPassword id="{goid}">
                        <l7:Name>{name}</l7:Name>
                        <l7:Password bundleKey="{bundle_key}">{key_data}</l7:Password>
                        <l7:Properties>
                            <l7:Property key="description">
                                <l7:StringValue />
                            </l7:Property>
                            <l7:Property key="type">
                                <l7:StringValue>Password</l7:StringValue>
                            </l7:Property>
                            <l7:Property key="usageFromVariable">
                                <l7:BooleanValue>true</l7:BooleanValue>
                            </l7:Property>
                        </l7:Properties>
                    </l7:StoredPassword>
                </l7:Resource>
            </l7:Item>
        </l7:References>
        <l7:Mappings>
            <l7:Mapping action="NewOrUpdate" srcId="{goid}" type="SECURE_PASSWORD" />
        </l7:Mappings>
        </l7:Bundle>'''

def bundle_cluster_prop(name, value):
    goid = new_goid()

    return f'''<?xml version="1.0" encoding="UTF-8"?>
        <l7:Bundle xmlns:l7="http://ns.l7tech.com/2010/04/gateway-management">
        <l7:References>
            <l7:Item>
                <l7:Name>{name}</l7:Name>
                <l7:Id>{goid}</l7:Id>
                <l7:Type>CLUSTER_PROPERTY</l7:Type>
                <l7:Resource>
                    <l7:ClusterProperty id="{goid}">
                    <l7:Name>{name}</l7:Name>
                    <l7:Value>{xml_escape(value)}</l7:Value>
                    </l7:ClusterProperty>
                </l7:Resource>
            </l7:Item>
        </l7:References>
        <l7:Mappings>
            <l7:Mapping action="NewOrUpdate" srcId="{goid}" type="CLUSTER_PROPERTY">
                <l7:Properties>
                    <l7:Property key="MapBy">
                        <l7:StringValue>name</l7:StringValue>
                    </l7:Property>
                    <l7:Property key="MapTo">
                        <l7:StringValue>{name}</l7:StringValue>
                    </l7:Property>
                </l7:Properties>
            </l7:Mapping>
        </l7:Mappings>
        </l7:Bundle>'''

# requires a pre-specified GOID because it is referenced by policy via GOID
def bundle_graphql_entity(name, goid, sdl, description='', default_complexity=1, directive_complexity=False):
    value = f'''<?xml version="1.0" encoding="UTF-8"?>
        <java version="11.0.11" class="java.beans.XMLDecoder">
            <object class="com.arcot.assertion.module.graphql.schema.model.GraphqlSchemaEntity">
                <void property="defaultComplexity">
                    <int>{default_complexity}</int>
                </void>
                <void property="description">
                    <string>{description}</string>
                </void>
                <void property="directiveComplexity">
                    <boolean>{bool_str(directive_complexity)}</boolean>
                </void>
                <void property="name">
                    <string>{name}</string>
                </void>
                <void property="sdl">
                    <string>{xml_escape(sdl)}</string>
                </void>
                <void property="valueXml">
                    <string></string>
                </void>
            </object>
        </java>'''

    return f'''<?xml version="1.0" encoding="UTF-8"?>
        <l7:Bundle xmlns:l7="http://ns.l7tech.com/2010/04/gateway-management">
        <l7:References>
            <l7:Item>
                <l7:Name>{name}</l7:Name>
                <l7:Id>{goid}</l7:Id>
                <l7:Type>GENERIC</l7:Type>
                <l7:Resource>
                    <l7:GenericEntity id="{goid}">
                        <l7:Name>{name}</l7:Name>
                        <l7:Description>{description}</l7:Description>
                        <l7:EntityClassName>com.arcot.assertion.module.graphql.schema.model.GraphqlSchemaEntity</l7:EntityClassName>
                        <l7:Enabled>true</l7:Enabled>
                        <l7:ValueXml>{xml_escape(value)}</l7:ValueXml>
                    </l7:GenericEntity>
                </l7:Resource>
            </l7:Item>
        </l7:References>
        <l7:Mappings>
            <l7:Mapping action="NewOrUpdate" srcId="{goid}" type="GENERIC" />
        </l7:Mappings>
        </l7:Bundle>'''

def property_put_xml(key, value):
    return f'''
                    <void method="put">
                        <string>{xml_escape(key)}</string>
                        <string>{xml_escape(value)}</string>
                    </void>'''

def bundle_cache_entity(name, goid, kind='redis', timeout=5000, properties={}):
    props = ''.join(property_put_xml(key, value) for key, value in properties.items())

    value = f'''<?xml version="1.0" encoding="UTF-8"?>
        <java version="11.0.11" class="java.beans.XMLDecoder">
            <object class="com.l7tech.external.assertions.remotecacheassertion.RemoteCacheEntity" id="RemoteCacheEntity0">
                <void property="id">
                    <string>{goid}</string>
                </void>
                <void property="name">
                    <string>{name}</string>
                </void>
                <void property="properties">{props}
                </void>
                <void property="timeout">
                    <int>{timeout}</int>
                </void>
                <void property="type">
                    <string>{kind}</string>
                </void>
                <void property="valueXml">
                    <string></string>
                </void>
            </object>
        </java>'''

    return f'''<?xml version="1.0" encoding="UTF-8"?>
        <l7:Bundle xmlns:l7="http://ns.l7tech.com/2010/04/gateway-management">
        <l7:References>
            <l7:Item>
                <l7:Name>{name}</l7:Name>
                <l7:Id>{goid}</l7:Id>
                <l7:Type>GENERIC</l7:Type>
                <l7:Resource>
                    <l7:GenericEntity id="{goid}">
                        <l7:Name>{name}</l7:Name>
                        <l7:EntityClassName>com.l7tech.external.assertions.remotecacheassertion.RemoteCacheEntity</l7:EntityClassName>
                        <l7:Enabled>true</l7:Enabled>
                        <l7:ValueXml>{xml_escape(value)}</l7:ValueXml>
                    </l7:GenericEntity>
                </l7:Resource>
            </l7:Item>
        </l7:References>
        <l7:Mappings>
            <l7:Mapping action="NewOrUpdate" srcId="{goid}" type="GENERIC" />
        </l7:Mappings>
        </l7:Bundle>'''
