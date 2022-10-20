copyFiles() {
        cp -r config/* /opt/docker/custom/
        # This allows the Gateway to remove files in this directory
        chown 1010:1010 -R /opt/docker/custom
}

copyFiles