#!/bin/env bash

# -DGPI2_HOME:STR="" \
# cmake -B build \
# -DPRINT_PERF:BOOL=TRUE \
# -DCMAKE_BUILD_TYPE=Release \
# -DOPENMP:BOOL=TRUE \
# -S . && \
# cmake --build build && \
time gaspi_run -m machines.txt -n 4 build/bin/stencil \
--nbr_of_column 20000 \
--nbr_of_row 20000 \
--nbr_iters 40 \
--ompthread_nbr 0 \
--energy_init 1