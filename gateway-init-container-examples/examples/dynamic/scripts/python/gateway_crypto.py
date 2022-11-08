from base64 import standard_b64encode, standard_b64decode
import logging
import re
import ssl
from Cryptodome.Hash import HMAC, SHA256, SHA1
from Cryptodome.Protocol.KDF import PBKDF2
from Cryptodome.Cipher import AES
from Cryptodome import Random
from Cryptodome.Util.py3compat import tobytes
from Cryptodome.Util.Padding import pad, unpad
from cryptography.hazmat.primitives.serialization.pkcs12 import load_pkcs12
from cryptography.hazmat.primitives import serialization

def get_random_bytes(size):
    return Random.get_random_bytes(size)

def sha256_hmac(key, salt, ciphertext):
    h = HMAC.new(key, digestmod=SHA256)
    h.update(salt)
    h.update(ciphertext)
    return h.digest()

def normalize_password(password):
    return tobytes(password).decode('iso-8859-1').encode('utf8')

def encrypt(password, iterations, plaintext):
    key_salt = get_random_bytes(16)
    key = PBKDF2(normalize_password(password), key_salt, dkLen=32, count=iterations, hmac_hash_module=SHA1)

    cipher_salt = get_random_bytes(AES.block_size)
    cipher = AES.new(key, AES.MODE_CBC, cipher_salt)
    ciphertext = cipher.encrypt(pad(plaintext, AES.block_size))

    mac = sha256_hmac(key, cipher_salt, ciphertext)
    payload = cipher_salt + ciphertext + mac

    return '$L7C2$' + hex(iterations)[2:] + ',' + standard_b64encode(key_salt).decode('iso-8859-1') + '$' + standard_b64encode(payload).decode('iso-8859-1')

def decrypt(password, data):
    match = re.fullmatch(r'\$L7C2\$([\w+]+),([\w+=/]+)\$([\w+=/]+)', data)
    if not match:
        return None
    iterations, key_salt, payload = match.groups()

    iterations = int(iterations, 16)
    key_salt = standard_b64decode(key_salt)
    payload = standard_b64decode(payload)

    key = PBKDF2(normalize_password(password), key_salt, dkLen=32, count=iterations, hmac_hash_module=SHA1)

    cipher_salt = payload[0:AES.block_size]
    ciphertext = payload[AES.block_size:len(payload)-SHA256.digest_size]
    hmac = payload[len(payload)-SHA256.digest_size:]

    mac = sha256_hmac(key, cipher_salt, ciphertext)
    if mac != hmac:
        raise ValueError('unable to decrypt: bad mac value')

    cipher = AES.new(key, AES.MODE_CBC, cipher_salt)
    plaintext = cipher.decrypt(ciphertext)
    return unpad(plaintext, AES.block_size)

def encrypt_key(cluster_password, key):
    bundle_encryption_key = get_random_bytes(32)
    bundle_key = encrypt(cluster_password, 114349, bundle_encryption_key)
    key_data = encrypt(bundle_encryption_key, 1, key)
    return (bundle_key, key_data)

def decrypt_key(cluster_password, bundle_key, key_data):
    data_key = decrypt(cluster_password, bundle_key)
    return decrypt(data_key, key_data)

def cert_bytes_to_b64_der(cert):
    try:
        pem = cert.decode('ascii')
        # it's ascii encoded, but we still want to verify it's pem encoded

        der = ssl.PEM_cert_to_DER_cert(pem)
    except UnicodeDecodeError:
        # it's der encoded
        der = cert

    return str(standard_b64encode(der), 'ascii', 'strict')

class UnknownPrivateKeyType(Exception):
    pass

# determine gateway's algorithm from key type
def key_algorithm(key):
    key_type = key.__class__.__name__
    if 'RSA' in key_type:
        return 'RSA'
    if 'EllipticCurve' in key_type:
        return 'EC'
    raise UnknownPrivateKeyType(f'Unknown private key type: {key_type}')

# sort certificates in order from leaf to root
def sorted_certs(leaf_cert, additional_certs):
    certs_dict = {cert.certificate.subject.rfc4514_string(): cert.certificate for cert in additional_certs}

    next_cert = leaf_cert
    while next_cert is not None:
        yield next_cert
        if next_cert.issuer == next_cert.subject:
            return
        prev_cert = next_cert
        next_cert = certs_dict.get(prev_cert.issuer.rfc4514_string())

    logging.warning(f'cert chain for {leaf_cert.subject.rfc4514_string()} is broken at {prev_cert.issuer.rfc4514_string()}')

def cert_obj_to_b64_der(cert):
    return str(standard_b64encode(cert.public_bytes(encoding=serialization.Encoding.DER)), 'ascii', 'strict')

# load components from a PKCS12 file
def load_key_certs(p12data, key_pass):
    p12 = load_pkcs12(p12data, str.encode(key_pass))

    key = p12.key.private_bytes(encoding=serialization.Encoding.DER, format=serialization.PrivateFormat.TraditionalOpenSSL, encryption_algorithm=serialization.NoEncryption())
    certs = sorted_certs(p12.cert.certificate, p12.additional_certs)
    algorithm = key_algorithm(p12.key)

    return (key, certs, algorithm)
