#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: IUCN Red List history assesment
doc:
  - |
    Description:
    Gets the entire history IUCN Red List assessments for a given species list using the ICUN Red List API.
  - |
    Authors:
    Maria Camila diaz (maria.camila.diaz.corzo@usherbrooke.ca)
    Victor Julio Rincon (rincon-v@javeriana.edu.co)
    Laetitia Tremblay (Maintenance, laetitia.tremblay@mcgill.ca, http://www.linkedin.com/in/laetitia-tremblay-b0619b273)


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
        species_data: inputs.species_data ? inputs.species_data.path : null,
        sp_col: inputs.sp_col,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "IUCNRedlistIndex__IUCN_redlist_historyAssesment" \
    "channels: [conda-forge, r]
    dependencies: [r-magrittr, r-data.table, r-dplyr, r-plyr, r-ggplot2, r-tibble, r-pbapply,
      r-rredlist, r-plyr, r-reshape2, r-rjson]
    name: IUCNRedlistIndex__IUCN_redlist_historyAssesment
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IUCNRedlistIndex__IUCN_redlist_historyAssesment /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  species_data:
    type: File?
    label: Species data
    doc: Dataset that includes the list of species for which historical assessments from the IUCN Red List are to be obtained.
    default: /scripts/IUCN_redlist_historyAssesment/input/data_sp.csv

  sp_col:
    type: string?
    label: Species name column
    doc: Name of the column in the species_data dataset that contains the scientific names of the species to be detailed.
    default: scientific_name



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
    default: IUCNRedlistIndex/IUCN_redlist_historyAssesment.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  iucn_history_assessment_data_out:
    type: File
    label: History assessment data
    doc: Dataset that contains the historical IUCN threat category assessments, organized by year, for the listed species.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "iucn_history_assessment_data");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  api_citation_out:
    type: string
    label: IUCN API citation
    doc: Citation for the data acquired using the IUCN Red List API
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "api_citation");
          return value;
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
