#!/bin/bash

run_custom_scripts() {
        scripts=$(find "./scripts" -type f 2>/dev/null)
        for script in $scripts; do
                filename=$(basename "$script")
                ext=${filename##*.}
                if [[ ${ext} == sh ]]; then
                        /bin/bash $script
                elif [[ ${ext} == "py" ]] && [[ "${filename}" == *"preboot_"* ]]; then
                        python $script
                fi
                if [ $? -ne 0 ]; then
                        echo "Failed executing the script: ${i}"
                fi
        done
        unset i
}


copyFiles() {
        cp -r config/* /opt/docker/custom/
        # This allows the Gateway to remove files in this directory
        chown 1010:1010 -R /opt/docker/custom
}

run_custom_scripts
copyFiles