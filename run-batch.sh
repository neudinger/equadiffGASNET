#!/bin/env bash

if (command -v module &> /dev/null)
then
module load boost
fi

set -x

echo """
SLURM_JOB_NAME, \"${SLURM_JOB_NAME}\", PBS_JOBNAME Name of the job
SLURM_JOB_ID, \"${SLURM_JOB_ID}\", PBS_JOBID The ID of the job allocation
SLURM_JOB_NODELIST, \"${SLURM_JOB_NODELIST}\", PBS_NODEFILE List of nodes allocated to the job
SLURM_TASK_PID, \"${SLURM_TASK_PID}\", The process ID of the task being started
SLURMD_NODENAME, \"${SLURMD_NODENAME}\", Name of the node running the job script
SLURM_JOB_NUM_NODES, \"${SLURM_JOB_NUM_NODES}\", Total number of different nodes in the job's resource allocation
SLURM_SUBMIT_DIR, \"${SLURM_SUBMIT_DIR}\", PBS_O_WORKDIR The directory from which sbatch was invoked
SLURM_SUBMIT_HOST, \"${SLURM_SUBMIT_HOST}\", PBS_O_HOST The hostname of the computer from which sbatch was invoked
SLURM_CPUS_ON_NODE, \"${SLURM_CPUS_ON_NODE}\", Number of CPUS on the allocated node
SLURM_NNODES, \"${SLURM_NNODES}\", Total number of nodes in the job's resource allocation
SLURM_MEM_PER_CPU, \"${SLURM_MEM_PER_CPU}\", Same as --mem-per-cpu
SLURM_NPROCS, \"${SLURM_NPROCS}\", SLURM_NPROCS PBS_NUM_NODES Same as -n, --ntasks
SLURM_JOB_CPUS_PER_NODE, \"${SLURM_JOB_CPUS_PER_NODE}\", PBS_NUM_PPN Count of processors available to the job on this node.
SLURM_CLUSTER_NAME, \"${SLURM_CLUSTER_NAME}\", Name of the cluster on which the job is executing
SLURM_JOB_ACCOUNT, \"${SLURM_JOB_ACCOUNT}\", Account name associated of the job allocation
SLURM_NTASKS_PER_NODE, \"${SLURM_NTASKS_PER_NODE}\", Number of tasks requested per node. Only set if the --ntasks-per-node option is specified.
SLURM_NTASKS_PER_SOCKET, \"${SLURM_NTASKS_PER_SOCKET}\", Number of tasks requested per socket. Only set if the --ntasks-per-socket option is specified.
SLURM_JOB_GPUS, \"${SLURM_JOB_GPUS}\", GPU IDs allocated to the job (if any).
SLURM_CPUS_PER_TASK, \"${SLURM_CPUS_PER_TASK}\", --cpus-per-task=<ntpt>
SLURM_TASKS_PER_NODE, \"${SLURM_TASKS_PER_NODE}\", Number of tasks to be initiated on each node
"""

if [ -z "$MFILE" ];
then
    MFILE="machines_"$SLURM_JOB_ID".txt"
fi

set_machines_file()
{
    local HostNameIndex=0
    # Get all nodes hostnames in list
    local IPS=($(scontrol show hostnames))
    Field_Separator=$IFS
    IFS=,
    # express SLURM_TASKS_PER_NODE as list View
    for CPUS_PER_NODE in ${SLURM_TASKS_PER_NODE};
    do
        Field_Separator_1=$IFS
        IFS='
'
        if [[ "${CPUS_PER_NODE: -1}" == ")" ]];
        then
            CPUS_PER_NODE=($(echo ${CPUS_PER_NODE} | tr -d '(),' | tr 'x' '
'))
            for _ in $(seq ${CPUS_PER_NODE[1]});
            do
                seq ${CPUS_PER_NODE[0]} | sed "c ${IPS[${HostNameIndex}]}" >> ${MFILE}
                ((HostNameIndex++))
            done
        else
            seq ${CPUS_PER_NODE} | sed "c ${IPS[${HostNameIndex}]}" >> ${MFILE}
            ((HostNameIndex++))
        fi
        IFS=$Field_Separator_1
    done
    IFS=$Field_Separator
}

if [ -z "$OMP_NUM_THREADS" ];
then
    # "Tasks" Only
    export OMP_NUM_THREADS=1
    NODES=${SLURM_NPROCS}
    if [ -n "$THROTTLE" ];
    then # THROTTLE ntasks-per-socket
        # Generate machine file
        set_machines_file
    else
        # SLURM_JOB_CPUS_PER_NODE
        # 1 Task == 1 Process == 1 Core
        for hostname in $(scontrol show hostnames); 
        do
            seq ${SLURM_CPUS_ON_NODE} | sed "c ${hostname}" >> ${MFILE}
        done
    fi
else # "Tasks+Threads"
    case "${TasksOn}" in
    "Socket")
        # TODO
        # Create set_machines_file -> set_machines_file_tasks_per_node for {SLURM_TASKS_PER_NODE}
        declare IPS=($(scontrol show hostnames))
        declare NODES=0
        declare TASKS_PER_NODES=($(echo ${SLURM_TASKS_PER_NODE} | tr ',' '
'))
        for TASKS_PER_NODE in ${TASKS_PER_NODES[@]};
        do
            if [[ "${TASKS_PER_NODE: -1}" == ")" ]];
            then
                # Contain [0]: number of tasks per node, [1]: number of nodes
                tuple=($(echo ${TASKS_PER_NODE} | tr -d '(),' | tr 'x' '
'))
                let NODES+=${tuple[0]}*${tuple[1]}
                HostNameIndex=0
                for _ in $(seq ${tuple[1]});
                do
                    seq ${tuple[0]} | sed "c ${IPS[${HostNameIndex}]}" >> ${MFILE}
                    ((HostNameIndex++))
                done
            else
                let NODES+=${TASKS_PER_NODE}
                seq ${TASKS_PER_NODE} | sed "c ${IPS[${HostNameIndex}]}" >> ${MFILE}
                ((HostNameIndex++))
            fi
        done
        if [[ $( expr ${HostNameIndex} % 2 ) == 0 ]];
        then
            NUMA_AWARE="-N"
        fi
    ;;
    "Node")
        NODES=${SLURM_JOB_NUM_NODES}
        scontrol show hostnames > ${MFILE}
    ;;
    *)
        NODES=${SLURM_JOB_NUM_NODES}
        scontrol show hostnames > ${MFILE}
    ;;
    esac
fi

time gaspi_run.slurm ${NUMA_AWARE} \
--nodes ${NODES} \
--machinefile ${MFILE} \
./build/bin/stencil \
--ompthread_nbr ${OMP_NUM_THREADS} \
--nbr_of_column ${1} \
--nbr_of_row ${1} \
--nbr_iters ${2} \
--energy_init 1