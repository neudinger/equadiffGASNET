# Distributed diffusion equation C/C++ OpenMP one-sided communication GASPI (GPI2/PGAS)

![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black) ![C++](https://img.shields.io/badge/c++-%2300599C.svg?style=for-the-badge&logo=c%2B%2B&logoColor=white) ![C](https://img.shields.io/badge/c-%2300599C.svg?style=for-the-badge&logo=c&logoColor=white)

![GPI2](https://img.shields.io/badge/GPI2-%23f01742.svg?style=for-the-badge&logoColor=white) ![HWLOC](https://img.shields.io/badge/HWLOC-%23f01742.svg?style=for-the-badge&logoColor=white) ![OMP](https://img.shields.io/badge/OpenMp-%23316192.svg?style=for-the-badge)


> - Horizontal split

Hybrid computation with multiple parallel computation level :

(Cluster level) -> (Machine level) -> (CPU Level) -> (Core Level)

- Distributed parallel operations layer with GASPI domain splitting.
- Multithreaded parallel operations layer with OpenMP.
- Vectorized parallel operations layer with cached blocked loops.

Usage of [HWLOC](https://www.open-mpi.org/projects/hwloc/) to gather hierarchical topology and specified thread core process binding.

Boost was used for program_options.
Compatible with infiniband.
The cmake will download and build program_options only if boost is not found.
If GPI2 is not found cmake will download and build it for this project.
Only this library will be linked to reduce the library loading overhead.

## Horizontal split

Build :

```bash
cmake -B build \
-DPRINT_PERF:BOOL=TRUE \
-DCMAKE_BUILD_TYPE=Release \
-DOPENMP:BOOL=TRUE \
-S . && \
cmake --build build 
```

Run :

On slurm :

```bash
sbatch \
--account "" \
--mem-per-cpu=100000 \
--nodes=1 \
--ntasks=${worker} \
--ntasks-per-node=1 \
--cpus-per-task=20 \
--partition=cpu_dist \
--time=24:00:00 \
${here}/run-batch.sh 80000 1000
```

On any preallocated resource cluter :

```bash
gaspi_run.slurm ${NUMA_AWARE} \
--nodes ${NODES} \
--machinefile ${MFILE} \
./build/bin/stencil \
--ompthread_nbr ${OMP_NUM_THREADS} \
--nbr_of_column ${1} \
--nbr_of_row ${1} \
--nbr_iters ${2} \
--energy_init 1
```

On one machine (localhost) :

```bash
gaspi_run -m machines.txt -n 4 build/bin/stencil \
--nbr_of_column 20000 \
--nbr_of_row 20000 \
--nbr_iters 40 \
--ompthread_nbr 0 \
--energy_init 1
```


---

C++ 17 was used due to usage of string_view and initializer_list.\
GPI2 (PGAS) for distributed layer.\
OpenMP for multithreading purpose.

This project was built with slurm as cluster node resource scheduler.
