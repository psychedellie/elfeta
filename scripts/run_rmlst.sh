#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

consensus=$1
rmlst=$2
organism_file=$3
species_file=$4
    
python "$SCRIPT_DIR/rmlst.py" --file $consensus --output $rmlst --organism_file $organism_file --species_file $species_file