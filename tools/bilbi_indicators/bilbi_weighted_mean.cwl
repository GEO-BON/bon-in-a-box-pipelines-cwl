#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Weighted means for CSIRO layers
doc:
  - "Description:
    This script calculates the weighted arithmetic mean for the CSIRO BILBI layers PARC, BHI, and BERI to calculate summary statistics over an area of interest. It was adapted from the 'BILBI_regional_summary_function_DAP_version.R' script at [https://doi.org/10.25919/edwj-4b67](https://doi.org/10.25919/edwj-4b67)."
  - "Authors:
    Jory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)"
  - "References:
    Harwood, Tom; Ware, Chris; Hoskins, Andrew; Ferrier, Simon; Bush, Alex; Golebiewski, Maciej; Ota, Noboru; Perry, Justin; & Williams, Kristen (2022): PARC: Protected Area Representativeness Index: 30s global time series. v2. CSIRO. Data Collection. null

    Harwood, Tom; Ware, Chris; Hoskins, Andrew; Ferrier, Simon; Bush, Alex; Golebiewski, Maciej; Hill, Samantha; Ota, Noboru; Perry, Justin; Purvis, Andy; & Williams, Kristen (2022): BHI v2: Biodiversity Habitat Index: 30s global time series. v1. CSIRO. Data Collection. null

    Harwood, Tom; Ware, Chris; Hoskins, Andrew; Ferrier, Simon; Bush, Alex; Golebiewski, Maciej; Hill, Samantha; Ota, Noboru; Perry, Justin; Purvis, Andy; & Williams, Kristen (2022): BERI v2: Bioclimatic Ecosystem Resilience Index: 30s global time series. v2. CSIRO. Data Collection. null"


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
        bilbi_indicator: inputs.bilbi_indicator,
        bilbi_denominator: inputs.bilbi_denominator,
        study_area: inputs.study_area,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "bilbi_indicators__bilbi_weighted_mean" \
    "channels: [conda-forge, r]
    dependencies: [r-rjson, r-terra, r-tidyverse]
    name: bilbi_indicators__bilbi_weighted_mean
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh bilbi_indicators__bilbi_weighted_mean /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  bilbi_indicator:
    type: File[]?
    label: BILBI indicator tif file
    doc: >
      Tiff file of the BILBI CSIRO indicator of choice. Can be Protected Area Representativeness and Connectedness (PARC), Bioclimatic
      Ecosystem Resilience Index (BERI), or the Biodiversity Habitat Index (BHI)

  bilbi_denominator:
    type: File[]?
    label: BILBI denominator tif file
    doc: Tiff file to calculate the weighted geometric mean

  study_area:
    type: File?
    label: Study area
    doc: Study area over which to calculate the weighted geometric mean value for the indicator



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
    default: bilbi_indicators/bilbi_weighted_mean.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  summarised_values:
    type: File
    label: Indicator summary
    doc: Weighted geometric mean of the indicator over the time period of interest in the study area
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "summarised_values");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  time_series_plot:
    type: File
    label: Time series plot
    doc: Plot of the geometric mean of the indicator over time in the study area of interest
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "time_series_plot");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
