#!/bin/bash

##################################################################################
# Example Docker InitContainer
##################################################################################
##################################################################################
# This simple utility runs any bash/python scripts located in the /custom/scripts
# folder and copys the output to a shared location that will be picked up by
# bootstrap.script.enabled in the Gateway Helm Chart 

##################################################################################
# There are three options you can make use of
##################################################################################
# 1. Copy files to the /config folder - files are simply moved to the correct location.
# 2. Copy scripts to the /scripts folder - scripts are run to pull files dynamically
# from external locations.
# 3. Combination of existing files in /config and scripts in /scripts.
##################################################################################

##################################################################################
# Usage
##################################################################################
# 1. Clone the base repository
# 2. Configure your scripts, config or both directories
# 3. Build and push your image to your private image repository
# 4. Configure the Gateway Helm Chart to use your image as an InitContainer
##################################################################################

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
}

run_custom_scripts
copyFiles
