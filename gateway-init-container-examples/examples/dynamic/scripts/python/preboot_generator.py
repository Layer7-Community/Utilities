#!/usr/bin/env python3

import json
import logging
import os
import gateway_entities

LOG_FORMAT = '[%(levelname)s] %(module)s: %(message)s'
BOOTSTRAP_DIR = os.environ["BOOTSTRAP_DIR"]
KEY_DIR = os.environ["KEY_DIR"]

PREBOOT_DIR = './'

logging.basicConfig(format=LOG_FORMAT, level=logging.INFO)

def write_bundle(filename, contents):
    with open(f'{BOOTSTRAP_DIR}/{filename}.req.bundle', 'w', encoding='utf-8') as file:
        file.write(contents)
        file.close()

def scan_source_dir(subdir):
    path = f'{PREBOOT_DIR}/{subdir}'
    if os.path.isdir(path):
        with os.scandir(path) as it:
            return list(((*os.path.splitext(file.name), file.path) for file in it if file.is_file()))
    return []

def read_file(path):
    with open(path, 'r', encoding='utf-8') as file:
        return file.read()

def read_json_file(path):
    with open(path, 'r', encoding='utf-8') as file:
        return json.load(file)

def read_binary_file(path):
    with open(path, 'rb') as file:
        return file.read()

# split name and goid in filename (extension should not be included)
def split_name_goid(name):
    name, goid = name.rsplit('-', 1)
    return name, goid

def main():
    SSG_CLUSTER_PASSWORD = os.getenv('SSG_CLUSTER_PASSWORD')
    PRIVATEKEY_DEFAULT_PASSWORD = os.getenv('PRIVATEKEY.DEFAULT.PASSWORD')

    for key, value in os.environ.items():
        if key.startswith('STOREDSECRET.'):
            key = key.split('.')[1]
            logging.info(f'Generating bundle for stored secret (from env): {key}')

            bundle_content = gateway_entities.bundle_stored_secret(name=key, value=value.encode('utf-8'), cluster_pass=SSG_CLUSTER_PASSWORD)

            write_bundle(f'SECURE_PASSWORD_{key}', bundle_content)
        elif key.startswith('CLUSTERPROP.'):
            _, key = key.split('.', 1)
            logging.info(f'Generating bundle for cluster prop (from env): {key}')

            bundle_content = gateway_entities.bundle_cluster_prop(name=key, value=value)
            write_bundle(f'CLUSTER_PROP_{key}', bundle_content)
    for name, ext, path in scan_source_dir(KEY_DIR):
        if ext == '.p12':
            logging.info(f'Generating bundle for key: {name}')

            key_password = os.getenv(f'PRIVATEKEY.{name}.PASSWORD', PRIVATEKEY_DEFAULT_PASSWORD)
            bundle_content = gateway_entities.bundle_private_key(name=name, p12_data=read_binary_file(path), key_pass=key_password, cluster_pass=SSG_CLUSTER_PASSWORD)

            write_bundle(f'SSG_KEY_ENTRY_{name}', bundle_content)
        elif ext == '.cer':
            logging.info(f'Generating bundle for cert: {name}')

            bundle_content = gateway_entities.bundle_cert(name=name, cert=read_binary_file(path))
            write_bundle(f'TRUSTED_CERT_{name}', bundle_content)
       
        elif ext == '.cache':
            logging.info(f'Generating bundle for remote cache entity: {name}')

            # format is 'name-goid.cache'
            name, goid = split_name_goid(name)

            settings = read_json_file(path)
            settings['properties'] = settings.get('properties', {})
            set_props_from_env(settings['properties'], f'CACHE.{name}.')

            bundle_content = gateway_entities.bundle_cache_entity(name=name, goid=goid, **settings)

            write_bundle(f'CACHE_{name}', bundle_content)

    for name, _, path in scan_source_dir('cwp'):
        logging.info(f'Generating bundle for cluster prop: {name}')

        bundle_content = gateway_entities.bundle_cluster_prop(name=name, value=read_file(path))

        write_bundle(f'CLUSTER_PROP_{name}', bundle_content)

    for name, _, path in scan_source_dir('secret'):
        logging.info(f'Generating bundle for stored secret: {name}')

        bundle_content = gateway_entities.bundle_stored_secret(name=name, value=read_binary_file(path), cluster_pass=SSG_CLUSTER_PASSWORD)

        write_bundle(f'SECURE_PASSWORD_{name}', bundle_content)

# add envvars to a dictionary when they start with the given prefix
def set_props_from_env(dictionary, prefix):
    for key, value in os.environ.items():
        if key.startswith(prefix):
            dictionary[key[len(prefix):]] = value

if __name__ == '__main__':
    main()