#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: MaxEnt
doc:
  - |
    Description:
    This script runs MaxEnt algorithm based on ENMeval package.
  - |
    Authors:
    Sarah Valentin (https://orcid.org/0000-0002-9028-681X)
  - "External link: https://github.com/jamiemkass/ENMeval"
  - |
    References:
    ENMeval 2.0 Redesigned for customizable and reproducible modeling of species’ niches and distributions
    https://doi.org/10.1111/2041-210X.13628


requirements:
  InlineJavascriptRequirement:
    expressionLib:
      - |
        function extractOutput(outputFiles, key) {
          if (!outputFiles || outputFiles.length === 0) return null;
          var value = JSON.parse(outputFiles[0].contents)[key]
          if (value === undefined) return null

          if(inputs.runFolder != null) {
            if(Array.isArray(value)) {
              value = value.map(function (item) {
                if(typeof item.replace === "function")
                  return item.replace(inputs.runFolder.path, runtime.outdir);
                else return item
              });
            } else if(typeof value.replace === "function") {
              value = value.replace(inputs.runFolder.path, runtime.outdir);
            }
          }
          return value;
        }
  InplaceUpdateRequirement:
    inplaceUpdate: true
  NetworkAccess:
    networkAccess: true
  InitialWorkDirRequirement:
    listing: |
      ${
        return [
          {
            entry: { "class": "Directory", "basename": "conda-env-yml", "listing": [] },
            entryname: "/conda-env-yml",
            writable: true
          }
        ].concat(
          inputs.envFolder
            ? {
                entry: inputs.envFolder,
                entryname: "/conda-envs",
                writable: inputs.envFolderWritable
              }
            : { // fallback
                entry: { "class": "Directory", "basename": "conda-envs", "listing": [] },
                entryname: "/conda-envs",
                writable: true
              }
        ).concat(
          inputs.environment
            ? [{ entry: inputs.environment, entryname: "/runner.env" }]
            : []
        ).concat(
          inputs.runFolder
            ? [{ entry: inputs.runFolder, writable: true }]
            : []
        ).concat( // For debugging, overrides /scripts
          inputs.scripts_root
            ? [{ entry: inputs.scripts_root, entryname: "/scripts" }]
            : []
        );
      }


  DockerRequirement:
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-eee5c95
    # dockerImageId: conda-cwl-runner-local
    # dockerFile:
    #     $include: ../runners/cwl/conda-cwl.dockerfile

  EnvVarRequirement:
    envDef:
      CONDA_PKGS_DIRS: /conda-env-yml/pkgs
      CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
      SCRIPT_LOCATION: /scripts
      SCRIPT_STUBS_LOCATION: /script-stubs
      USERDATA_LOCATION: /userdata
      OUTPUT_LOCATION: "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)"

baseCommand: ["bash", "-c"]
arguments:
  - |
    log=$OUTPUT_LOCATION/logs.txt
    rm -f $log
    mkdir -p /conda-env-yml/pkgs /conda-env-yml/envs

    cat > "$OUTPUT_LOCATION/input.json" <<'JSON'
    ${
      return JSON.stringify({
        presence_background: inputs.presence_background ? inputs.presence_background.path : null,
        predictors: (inputs.predictors || []).map(function(file) { return file.path; }),
        fc: inputs.fc,
        rm: inputs.rm,
        partition_type: inputs.partition_type,
        orientation_block: inputs.orientation_block,
        crs: inputs.crs,
        n_folds: inputs.n_folds,
        method_select_params: inputs.method_select_params,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "SDM__runMaxent" \
    "channels: [conda-forge, r]
    dependencies: [libgdal, r-abind, r-base, r-curl, r-dismo, r-downloader, r-dplyr, r-enmeval=2.0.3,
      r-ecospat, r-essentials, r-geojsonsf, r-ggsci, r-jpeg, r-landscapemetrics, r-magrittr,
      r-png, r-purrr, r-rcurl, r-rgbif, r-remotes, r-rjava, r-rjson, r-sf, r-stars, r-stringr,
      r-terra, r-this.path, r-tidyselect, r-tidyverse, r-stringr]
    name: SDM__runMaxent
    " /conda-envs $(inputs.condaPackURL) >> "$log" 2>&1

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log
  
    if [[ "$OUTPUT_LOCATION" != "$(runtime.outdir)" ]]; then
      echo "Copying results from run folder to CWL output directory" | tee -a $log
      cp -a "$OUTPUT_LOCATION"/. "$(runtime.outdir)"/
    fi

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SDM__runMaxent /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  presence_background:
    type: File?
    label: presence background
    doc: presence
    default: /scripts/SDM/runModel_presence_background.tsv

  predictors:
    type: File[]?
    label: predictors
    doc: layer names (predictors) as a list, or path to a list
    default:
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio141981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio151981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio181981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio21981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio31981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio81981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio91981-01-01.tif

  fc:
    type: string[]?
    label: feature classes
    doc: Vector of strings, feature classes for MaxEnt algorithm. Accepted values are combinations of L (linear), Q (quadratic), P (product), H (hinge) or T (threshold).
    default:
    - L
    - LQ
    - LQHP

  rm:
    type: float[]?
    label: regularization multiplier
    doc: Vector of numbers, regularization multipliers for MaxEnt algorithm.
    default:
    - 0.5
    - 1
    - 2

  partition_type:
    type:
      type: enum
      symbols:
        - randomkfold
        - jackknife
        - block
        - checkerboard1
        - checkerboard2
    label: partition type
    doc: String, name of partitioning technique.
    default: block

  orientation_block:
    type:
      type: enum
      symbols:
        - lat_lon
        - lon_lat
        - lon_lon
        - lat_lat
    label: orientation block
    doc: String, order of spatial partitioning for block technique..
    default: lat_lon

  crs:
    label: CRS
    doc: Object containing CRS.
    type:
      type: record
      name: CRS
      fields:
      - name: CRS
        type:
          name: CRSDefinition
          type: record
          fields:
          - name: unit
            type: string?
          - name: code
            type: int?
          - name: authority
            type: string?
          - name: name
            type: string?
          - name: CRSBboxWGS84
            type: float[]?
          - name: proj4Def
            type: string?
          - name: wktDef
            type: string?

  n_folds:
    type: int?
    label: number of folds
    doc: Integer, number of random k-folds for randomkfold technique.
    default: 5

  method_select_params:
    type:
      type: enum
      symbols:
        - p10
        - AIC
        - AUC
    label: params selection method
    doc: String, method to select the best combination of MaxEnt parameters.
    default: p10



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory?
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.

  envFolderWritable:
    type: boolean
    doc:
      Whether the envFolder should be writable. If false, the folder will be mounted read-only.
      In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run.
      envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.
    default: true

  runFolder:
    type: Directory?
    doc:
      Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script.
      If left blank, a temporary folder will be used and discarded after the run.

  environment:
    type: File?
    doc:
      Optional. BON in a Box runner.env file, necessary for scripts requiring credentials.
      If not provided, an empty one will be used.

  #################################################################
  # The following inputs should not be changed in a regular setup #
  #################################################################

  condaPackURL:
    type: string
    doc: Base URL to check for conda-pack environments.
    default: https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/

  scriptPath:
    type: string
    doc: Path to the script, relative to scripts root.
    default: SDM/runMaxent.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  sdm_pred:
    type: File
    label: predictions
    doc: model predictions while trained on the whole dataset
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_pred");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  sdm_runs:
    type: File[]
    label: runs predictions
    doc: model predictions among the several runs (if boostrapping or kfolds performed)
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_runs");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
