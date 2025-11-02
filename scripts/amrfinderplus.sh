#!/bin/bash

consensus=$1
output=$2
species_name=$3 
threads=$4

if [ -n "$species_name" ]; then
  echo "Running AMRFinder with species: $species_name"
  micromamba run -n amrfinderplus amrfinder -n $consensus -o $output -O "$species_name" --threads $threads --plus
else
  # Το string είναι κενό, οπότε τρέχουμε την default εντολή.
  echo "Running AMRFinder without species."
  micromamba run -n amrfinderplus amrfinder -n $consensus -o $output --threads $threads --plus
fi