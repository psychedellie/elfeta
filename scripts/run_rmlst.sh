#!/usr/bin/env bash

# --- NEO ---
# Αυτή η γραμμή βρίσκει τον απόλυτο φάκελο όπου βρίσκεται ΑΥΤΟ το script (.sh)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

consensus=$1
rmlst=$2
organism_file=$3
species_file=$4
    
# --- NEO ---
# Τώρα καλούμε το rmlst.py χρησιμοποιώντας την πλήρη, απόλυτη διαδρομή
# $SCRIPT_DIR == /home/psychedellie/Git/elftech/scripts
micromamba run -n rmlst python "$SCRIPT_DIR/rmlst.py" --file $consensus --output $rmlst --organism_file $organism_file --species_file $species_file