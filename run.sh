#!/bin/bash
# This script is used to run AlphaFold on a single node.
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)" || exit 1
source "$SCRIPT_DIR/scripts/env.sh" || { \
    echo 'Please place your `env.sh` under `scripts` directory.'; \
    echo 'You can refer to `env.sh.example` for the content of `env.sh`.'; \
    exit 1; \
}
cd -- "$SCRIPT_DIR" || exit 1

INPUT_NAME=${1:-37aa_2JO9.json}
source "$SCRIPT_DIR/run_preprocessing.sh" || exit 1
configure_preprocessed_input || exit 1
export USE_DIST=0
echo "Running AlphaFold on single node for ${INPUT_NAME}, NCORES=${NCORES}, RANK=${RANK}"
time python -m torch.backends.xeon.run_cpu --ninstances 1 --ncores-per-instance ${NCORES} --rank ${RANK} run_alphafold.py \
    --run_data_pipeline=False \
    "${INPUT_ARGS[@]}" \
    --model_dir=${MODEL_DIR} \
    --output_dir=${OUTPUT_DIR} 2>&1 \
    | tee -a ${LOG_DIR}/${INPUT_NAME}.log
