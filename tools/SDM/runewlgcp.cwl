#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: SDM with ewlgcpSDM
doc:
  - |
    Description:
    This script runs an effort-weighted Log Gaussian Cox Process based on the ewlgcpSDM R package.
  - |
    Authors:
    François Rousseu (https://orcid.org/0000-0002-2400-2479)
  - "External link: https://github.com/BiodiversiteQuebec/ewlgcpSDM"
  - |
    References:
    in prep
    null


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
        presence_background: inputs.presence_background ? inputs.presence_background.path : null,
        predictors: (inputs.predictors || []).map(function(file) { return file.path; }),
        orientation_block: inputs.orientation_block,
        crs: inputs.crs,
        n_folds: inputs.n_folds,
        spatial_res: inputs.spatial_res,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "SDM__runewlgcp" \
    "channels: [conda-forge, r]
    dependencies: [r-terra, r-rjson, r-raster, r-dplyr, r-gdalcubes, r-ENMeval, r-devtools,
      r-sf, r-FNN, r-stars]
    name: SDM__runewlgcp
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SDM__runewlgcp /conda-envs >> "$log" 2>&1

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
      name: bboxCRS
      fields:
      - name: country
        type:
          name: countryDefinition
          type: record
          fields:
          - name: englishName
            type: string?
          - name: ISO3
            type: string?
          - name: bboxWGS84
            type: float[]?
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
      - name: bbox
        type: float[]
      - name: region
        type:
          name: regionDefinition
          type: record
          fields:
          - name: countryEnglishName
            type: string?
          - name: regionID
            type: string?
          - name: regionName
            type: string?
          - name: bboxWGS84
            type: float[]?

  n_folds:
    type: int?
    label: number of folds
    doc: Integer, number of random k-folds for randomkfold technique.
    default: 5

  spatial_res:
    type: float?
    label: Spatial resolution
    doc: Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long).
    default: 1000.0



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
    default: SDM/runewlgcp.R

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

  sdm_unc:
    type: File
    label: uncertainty
    doc: model uncertainty metrics
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_unc");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  sdm_ci:
    type: File[]
    label: CI range
    doc: difference between the upper and the lower CI bound
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_ci");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  sdm_obs:
    type: File
    label: observations
    doc: GBIF observations used for the sdm model
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_obs");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  sdm_bg:
    type: File
    label: background
    doc: background points used for the sdm model
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_bg");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  sdm_dmesh:
    type: File
    label: dmesh
    doc: dual mesh used by the sdm model
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_dmesh");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
