#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Clean Coordinates
doc:
  - "Description:
    This script enables to apply several cleaning filters to the observations. The tests equal, zeros, duplicates, same_pixel, capitals, centroids, seas, urban, gbif and institutions are wrappers around CoordinateCleaner functions. Test same_pixel remove points inside the same pixel, based on a provided raster or from a STAC catalogue. Test env allows removing environmental outliers using the the Reverse Jackknife procedure as described by Chapman (2005) and adapted from the package biogeo."
  - "Lifecycle tag: Core."
  - "Authors:
    Sarah Valentin (https://orcid.org/0000-0002-9028-681X)"
  - "External link: https://github.com/ropensci/CoordinateCleaner"
  - "References:
    Chapman, A.D. (2005) Principles and Methods of Data Cleaning - Primary Species and Species- Occurrence Data, version 1.0. Report for the Global Biodiversity Information Facility, Copenhagen. null

    Zizka A, Silvestro D, Andermann T, Azevedo J, Duarte Ritter C, Edler D, Farooq H, Herdean A, Ariza M, Scharn R, Svanteson S, Wengtrom N, Zizka V & Antonelli A (2019) CoordinateCleaner, standardized cleaning of occurrence records from biological collection databases. Methods in Ecology and Evolution, 10(5):744-751 null"


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
                return item.replace(inputs.runFolder.path, runtime.outdir);
              });
            } else {
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
            : []
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
        presence: inputs.presence,
        predictors: inputs.predictors,
        tests: inputs.tests,
        env_threshold: inputs.env_threshold,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "filtering__cleanCoordinates" \
    "channels: [conda-forge, r]
    dependencies: [r-terra, r-rjson, r-raster, r-dplyr, r-CoordinateCleaner, r-gdalcubes]
    name: filtering__cleanCoordinates
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh filtering__cleanCoordinates /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  presence:
    type: File?
    label: presence
    doc: Dataframe, presence data.
    default: /scripts/filtering/cleanCoordinates_presence.tsv

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

  tests:
    type: string[]?
    label: cleaning tests
    doc: Vector of strings, tests to run from all tests available - capitals, centroids, same_pixel, equal, gbif, institutions, duplicates, urban, seas, zeros, env
    default:
    - equal
    - zeros
    - duplicates
    - same_pixel
    - capitals
    - centroids
    - seas
    - urban
    - gbif
    - institutions
    - env

  env_threshold:
    type: float?
    label: env threshold
    doc: Float, proportion of predictors to consider the observation as an outlier.
    default: 0.8



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory?
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.

  envFolderWriteable:
    type: boolean
    doc:
      Whether the envFolder should be writable. If false, the folder will be mounted read-only.
      In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run.
      envFolderWriteable must be false when running in a workflow, but can be true when ran as an individual tool.
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
    default: filtering/cleanCoordinates.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  n_presence:
    type: int
    label: n presence
    doc: Integer, initial number of presences points.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "n_presence");
          if (value === null) return null;
          return parseInt(value);
        }

  n_clean:
    type: int
    label: n clean presence
    doc: Integer, final number of presences points after cleaning.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "n_clean");
          if (value === null) return null;
          return parseInt(value);
        }

  clean_presence:
    type: File
    label: clean presences
    doc: Dataframe, table with clean presence points.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "clean_presence");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
