#!/bin/env bash

if (command -v module &> /dev/null)
then
module load boost
fi

declare here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
declare worker=1

export OMP_NUM_THREADS=20
export TasksOn="Socket"

# declare worker=20
# declare nodes=8
# declare ntasksOnNodes=2
# declare ntasks=`expr ${ntasksOnNodes} \* ${nodes}`
# ntasks=`expr ${ntasks} \* ${worker}`
# ntasksOnNodes=`expr ${ntasksOnNodes} \* ${worker}`

set -x;

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