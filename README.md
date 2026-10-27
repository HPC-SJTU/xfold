# xfold: Democratize AlphaFold3

xfold is an open-source, PyTorch-based reimplementation of AlphaFold3, designed to accelerate protein structure prediction research and make cutting-edge AI technology more accessible to the scientific community.

Future developments for xfold will focus on integrating cutting-edge performance optimization techniques and advanced parallelization strategies. Our ultimate goal is to democratize AlphaFold3, empowering a broader researcher to contribute to and benefit from this transformative technology.

<div align="center">
    <img src="./assets/comparison.gif" width="400">
    <p><em>Visualization result comparison of 2pv7</em></p>
</div>

## Recent Developments 🚀

* **December 2024**: Successful migration to PyTorch, with validation confirming alignment with the original implementation

## Getting Started

### Step 1: Prepare the Environment

Follow the setup instructions provided in the [AlphaFold3 README](https://github.com/google-deepmind/alphafold3) to ensure dependencies are correctly installed and the AlphaFold 3 model parameters are downloaded.

### Step 2: Install xfold

Install xfold using pip:

```bash
pip install xfold
```

### Step 3: Running Predictions

Execute protein structure predictions with the following command:

```bash
python run_alphafold.py \
    --db_dir=$PATH_TO_AF3_DATASET \
    --json_path=./fold_input.json \
    --model_dir=$$PATH_TO_AF3_MODEL \
    --output_dir=./output
```

### Faster preprocessing with an isolated AlphaFold 3.0.4 environment

For the normal launchers, configure `scripts/env.sh` using `scripts/env.sh.example`,
including `AF3_PREPROCESS_PYTHON` and `AF3_DB_DIR`. Both `bash run.sh INPUT.json`
and `bash run_multi.sh INPUT.json [HOSTS]` now run accelerated preprocessing
automatically before starting inference. Multi-node runs preprocess only once,
before `mpirun`, not once per rank. Missing configuration or a preprocessing
failure stops the launcher; there is no fallback to the old preprocessing path.
HMMER binaries must be available to the preprocessing process (via `PATH`).

Each invocation saves features under a new `preprocessing.XXXXXX/jobs` directory
inside `OUTPUT_DIR` and passes its absolute path to inference. For MPI, this
directory must reside on a shared filesystem at the same path on every node.
The outputs are retained for inspection/reuse. Database shards are cached
separately and reused across invocations.

To run preprocessing separately using the new environment's Python:

```bash
export AF3_PREPROCESS_PYTHON=/path/to/af3-3.0.4/bin/python
export AF3_DB_DIR=/path/to/public_databases
bash run_preprocessing.sh ./fold_input.json ./preprocessed
```

Then run the original inference environment:

```bash
python run_alphafold.py \
    --run_data_pipeline=False \
    --preprocessed_dir=./preprocessed \
    --model_dir="$PATH_TO_AF3_MODEL" \
    --output_dir=./output
```

Do not pass `--json_path` or `--input_dir` together with `--preprocessed_dir`.
Alternatively, export `XFOLD_PREPROCESSED_DIR` before using `run.sh` or
`run_multi.sh` to explicitly reuse an already completed preprocessing output.
The launchers require its completion manifest and do not rerun preprocessing in
this mode; every MPI rank reads the same features. The original JSON-only
inference workflow is still available by invoking `run_alphafold.py` directly.

The migrated optimization includes:

* Reusable round-robin shards for all seven protein/RNA FASTA databases, with
  bounded parallel shard searches. Defaults: two shards and up to eight HMMER
  workers per subprocess. The concurrency budget uses physical cores within
  the launcher's CPU affinity, not the machine-wide logical CPU count.
* Correct full-database Z-values: sequence counts for protein, megabases for RNA.
  Sharded searches can return different lower-ranked hits from an unsharded
  search because HMMER deduplicates within shards, not across them.
* Source/shard size and source-mtime validation, a preparation lock and atomic
  shard publication. Originals are retained. The first run requires an extra
  full copy of the seven FASTA files; subsequent runs reuse it. Stale or damaged
  caches fail explicitly. Stop active searches before moving an obsolete cache.
* Restored launch-time CPU affinity for search tools, deferred model loading,
  unpadded featurisation and saved per-seed features, so inference does not
  repeat search or featurisation.

The shell wrapper accepts `AF3_SHARD_DIR`, `AF3_DB_SHARDS`,
`AF3_SEARCH_CPU_BUDGET`, `AF3_JACKHMMER_N_CPU`, `AF3_NHMMER_N_CPU`,
`AF3_JACKHMMER_MAX_PARALLEL_SHARDS` and `AF3_NHMMER_MAX_PARALLEL_SHARDS`.
For example, a 72-core allocation defaults to four protein databases x two
shards x (eight workers + one coordinator). Very small CPU allocations can be
exceeded by the minimum concurrent database searches; a warning is printed.
The template defaults are `mmcif_files` and `pdb_seqres_2022_09_28.fasta` under
the database directory. Override them using `--pdb_database_path` and
`--seqres_database_path` after the wrapper's output argument.

For directory inputs, invoke the new Python entrypoint directly:

```bash
"$AF3_PREPROCESS_PYTHON" run_preprocessing.py \
    --input_dir=./inputs --db_dir="$AF3_DB_DIR" --output_dir=./preprocessed
```

Use a fresh preprocessing output directory for each invocation. A root manifest
is written only after every job succeeds. Each job includes an embedded,
v1-compatible processed input JSON and `intermediates/seed-<seed>_<index>.npy`
plus shape/dtype summaries, matching the source project's feature format.
Only generated exchange JSON is marked version 1; arbitrary newer input JSON
is not reinterpreted in the old environment. **Only load trusted local features**:
NumPy object arrays contain pickled AF3 output-layout objects. Keep those
artifacts intact for inference and use AF3 3.0.4 for producing them.

To featurise input that already contains all MSAs/templates, use
`run_preprocessing.py --no-run_data_pipeline` with the same required paths;
no databases or search binaries are accessed in this mode.

## Acknowledgments

We extend our gratitude to AlphaFold3 for open-sourcing their inference code and model weights, which has significantly advanced scientific research. xfold is provided exclusively for educational and research purposes. Users are kindly requested to review and comply with the AlphaFold3 license, available at https://github.com/google-deepmind/alphafold3?tab=readme-ov-file#licence-and-disclaimer.

## Contributing

We welcome contributions from the research community! Open an [issue](https://github.com/shenggan/xfold/issues) or send a [pull request](https://github.com/shenggan/xfold/pulls).
