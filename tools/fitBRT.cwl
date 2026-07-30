#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: BRT
doc:
  - "Description:
    This script creates a Species Distribution Model (SDM) and uncertainty map based on using Boosted Regression Trees (BRTs) using the package SpeciesDistributionToolkit.jl and EvoTrees.jl"
  - "Lifecycle tag: In review."
  - "Authors:
    Michael D. Catchen (https://orcid.org/0000-0002-6506-6487)"


requirements:
  InlineJavascriptRequirement:
    expressionLib:
      - |
        function extractOutput(outputFiles, key) {
          if (!outputFiles || outputFiles.length === 0) return null;
          var value = JSON.parse(outputFiles[0].contents)[key]
          if (value === undefined) return null
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
            entry: inputs.envFolder,
            entryname: "/conda-envs",
            writable: inputs.envFolderWritable
          },
          {
            entry: { "class": "Directory", "basename": "conda-env-yml", "listing": [] },
            entryname: "/conda-env-yml",
            writable: true
          }
        ].concat(
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
    #     $include: ../runners/cwl/conda-cwl-dockerfile

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
        occurrence: inputs.occurrence,
        predictors: inputs.predictors,
        bbox_crs: inputs.bbox_crs,
        water_mask: inputs.water_mask,
        max_candidate_pseudoabsences: inputs.max_candidate_pseudoabsences,
        pseudoabsence_buffer: inputs.pseudoabsence_buffer,
        pa_proportion: inputs.pa_proportion,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "" \
      "" /conda-envs $(inputs.condaPackURL) >> "$log" 2>&1

    julia \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.jl \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh  /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  occurrence:
    type: File
    label: occurrence coordinate dataframe
    doc: Dataframe, presence data.
    default: /output/data/getObservations/9f7d1cc148464cd0517e01c67af0ab5b/obs_data.tsv

  predictors:
    type: File[]
    label: geotiff predictor paths
    doc: paths to geotiff
    default: /output/foo/bar

  bbox_crs:
    label: Bounding box and CRS
    doc: Object containing the chosen bounding box and CRS.
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

  water_mask:
    type: File[]
    label: water mask
    doc: landcover layer containing open water pixels
    default: /output/foo/bar

  max_candidate_pseudoabsences:
    type: int
    label: max candidate pseudoabsences
    doc: helps w large rasters
    default: 100000

  pseudoabsence_buffer:
    type: float
    label: pseudoabsence buffer
    doc: minimum distance to a presence in kilometers
    default: 10.0

  pa_proportion:
    type: float
    label: Pseudoabsence proportion
    doc: The number of PAs, given by the proportion of the total occurrences to use.
    default: 2.4



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.
    default:
      class: Directory
      path: ./envs

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
    default: SDM/BRT/fitBRT.jl

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  predicted_sdm:
    type: File
    label: predicted sdm
    doc: map of predicted occurrence probability
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "predicted_sdm");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  sdm_uncertainty:
    type: File
    label: sdm uncertainty
    doc: map of relative uncertainty
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_uncertainty");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  fit_stats:
    type: File
    label: fit statistics
    doc: JSON of model fit stats and threshold
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "fit_stats");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  range:
    type: File
    label: range
    doc: range map thresholded at todo
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "range");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  pseudoabsences:
    type: File
    label: pseudoabsences
    doc: pseudoabsence coordinates
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "pseudoabsences");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  env_corners:
    type: File
    label: env_corners
    doc: location of presences and pseudoabsences in environment space
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "env_corners");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  tuning:
    type: File
    label: tuning curve
    doc: tuning curve
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "tuning");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'logs.txt')"
