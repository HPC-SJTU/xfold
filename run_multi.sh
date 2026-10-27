#!/bin/bash
# This script is used to run AlphaFold on multiple nodes using MPI.
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)" || exit 1
source "$SCRIPT_DIR/scripts/env.sh" || { \
    echo 'Please place your `env.sh` under `scripts` directory.'; \
    echo 'You can refer to `env.sh.example` for the content of `env.sh`.'; \
    exit 1; \
}
cd -- "$SCRIPT_DIR" || exit 1

INPUT_NAME=${1:-37aa_2JO9.json}
HOSTS=${2:-}
source "$SCRIPT_DIR/run_preprocessing.sh" || exit 1
configure_preprocessed_input || exit 1

if [ ${NNODES} -gt 1 ]; then
    MPIRUN_ARGS="-hosts ${HOSTS} -ppn ${PPN} -n ${NNODE_MPI}"
else
    MPIRUN_ARGS="-ppn ${PPN} -n ${NNODE_MPI}"
fi

export USE_DIST=1
export PROFILE_FILENAME="trace-multi"
export OMP_NUM_THREADS=${AVAIL_THREADS}
export KMP_AFFINITY=granularity=fine,compact,1,0
export KMP_BLOCKTIME=1
export LD_PRELOAD=${CONDA_PREFIX}/lib/libiomp5.so:${CONDA_PREFIX}/lib/libtcmalloc.so

echo "Running AlphaFold on multi nodes for ${INPUT_NAME}, PPN=${PPN}, NNODES=${NNODES}, MASTER_PORT=${MASTER_PORT}, MASTER_ADDR=${MASTER_ADDR}, AVAIL_THREADS=${AVAIL_THREADS}"

time mpirun ${MPIRUN_ARGS} python run_alphafold.py \
    --run_data_pipeline=False \
    "${INPUT_ARGS[@]}" \
    --model_dir=${MODEL_DIR} \
    --output_dir=${OUTPUT_DIR} 2>&1 \
    | tee -a ${LOG_DIR}/${INPUT_NAME}.log
