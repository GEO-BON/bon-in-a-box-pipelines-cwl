#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Setup SDM Data
doc:
  - |
    Description:
    This script creates a dataset ready to feed any SDM model.
  - |
    Authors:
    Sarah Valentin (https://orcid.org/0000-0002-9028-681X)


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
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:cwl-poc
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
        presence: inputs.presence ? inputs.presence.path : null,
        background: inputs.background ? inputs.background.path : null,
        predictors: (inputs.predictors || []).map(function(file) { return file.path; }),
        partition_type: inputs.partition_type,
        runs_n: inputs.runs_n,
        boot_proportion: inputs.boot_proportion,
        cv_partitions: inputs.cv_partitions,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "SDM__setupDataSdm" \
    "channels: [conda-forge, r]
    dependencies: [r-gdalcubes, r-terra, r-rjson, r-raster, r-dplyr, r-ENMeval, r-devtools]
    name: SDM__setupDataSdm
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SDM__setupDataSdm /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  presence:
    type: File?
    label: presence
    doc: Dataframe, presence data.
    default: /scripts/SDM/selectBackground_presence.tsv

  background:
    type: File?
    label: background
    doc: Dataframe, background data.
    default: /scripts/SDM/setupDataSdm_background.tsv

  predictors:
    type: File[]?
    label: predictors
    doc: Raster, predictors.
    default:
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio141981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio151981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio181981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio21981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio31981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio81981-01-01.tif
    - /output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio91981-01-01.tif

  partition_type:
    type:
      type: enum
      symbols:
        - bootstrap
        - crossvalidation
        - none
    label: partition type
    doc: method to partition into test and training sets to perform model fitting and validation.
    default: none

  runs_n:
    type: int?
    label: number of runs
    doc: number of runs (in bootstrap or crossvalidation method)
    default: 2

  boot_proportion:
    type: float?
    label: bootstrap proportion
    doc: proportion of presences and absences in the dataset that will be used as training data with bootstrap method.
    default: 0.7

  cv_partitions:
    type: int?
    label: number of crossvalidation partitions
    doc: number of partitions for each run with crossvalidation method.
    default: 5



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
    default: SDM/setupDataSdm.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  presence_background:
    type: File
    label: background presence
    doc: Presence-background points with covariates values
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "presence_background");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
