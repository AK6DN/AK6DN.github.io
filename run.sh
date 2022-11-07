#!/bin/bash

for file in \
    PDP-11 \
    PDP-11/2.11BSD \
    PDP-11/DIAGNOSTICS \
    PDP-11/M9312 \
    PDP-11/RX02 \
    PDP-11/TU58 \
    PDP-11/TU58/tu58em \
    PDP-8 \
    PDP-8/MAINDEC \
    PDP-8/MAINDEC/Binary_Loaders \
    PDP-8/MAINDEC/KE8-E_extended_arithmetic_element \
    PDP-8/MAINDEC/KK8-E_pdp8e_cpu \
    PDP-8/MAINDEC/KM8-E_memory_extension \
    PDP-8/MAINDEC/MM8-EJ_memory \
    ; \
    do

    echo '--------------------------------------------------'
    ./create_index_files_from_htaccess.pl $* $file

done

# the end
