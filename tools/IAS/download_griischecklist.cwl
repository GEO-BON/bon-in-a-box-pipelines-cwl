#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Download GRIIS Checklist
doc:
  - |
    Description:
    Download the latest national GRIIS checklist for a specified country and its affiliated regions, retain each checklist's ISO3 metadata, and combine the records. Protected-area checklists are excluded.
  - |
    Authors:
    Saxbee Affleck
    Samara Manzin (samara.manzin@mcgill.ca)


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
        return (
          inputs.envFolder
            ? [{
                entry: inputs.envFolder,
                entryname: "/conda-envs",
                writable: inputs.envFolderWritable
              }]
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
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-5f300f2
    # dockerImageId: conda-cwl-runner-local
    # dockerFile:
    #     $include: ../runners/cwl/conda-cwl.dockerfile

  EnvVarRequirement:
    envDef:
      CONDA_PKGS_DIRS: /tmp/conda-env-yml/pkgs
      CONDA_ENVS_PATH: /opt/conda/envs:/tmp/conda-env-yml/envs
      CONDA_PACK_URL: $(inputs.condaPackURL)
      SCRIPT_LOCATION: /scripts
      SCRIPT_PATH: $(inputs.scriptPath)
      SCRIPT_STUBS_LOCATION: /script-stubs
      USERDATA_LOCATION: /userdata
      OUTPUT_LOCATION: "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)"
      PYTHONUNBUFFERED: "1"

  ResourceRequirement:
    ramMin: 5120

baseCommand: ["bash", "-c"]
arguments:
  - |
    log=$OUTPUT_LOCATION/logs.txt
    rm -f $log
    touch "$log"
    tail -f "$log" &
    tailPid=$!
    cleanupTail() {
      kill "$tailPid" 2>/dev/null
      wait "$tailPid" 2>/dev/null
    }
    trap cleanupTail EXIT

    mkdir -p /tmp/conda-env-yml/pkgs /tmp/conda-env-yml/envs

    cat > "$OUTPUT_LOCATION/input.json" <<'JSON'
    ${
      return JSON.stringify({
        country_name: inputs.country_name,
        compendium_countries: inputs.compendium_countries ? inputs.compendium_countries.path : null,
        global_invasive_checklist: inputs.global_invasive_checklist ? inputs.global_invasive_checklist.path : null,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" >> "$log"
    echo "Inputs:" >> "$log"
    cat "$OUTPUT_LOCATION/input.json" >> "$log"

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "IAS__download_griischecklist" \
    "channels: [conda-forge, r]
    dependencies: [r-xml, r-dplyr, r-stringr, r-readr, r-tidyrss, r-tidyr, r-rvest, r-rjson,
      r-readxl, r-countrycode]
    name: IAS__download_griischecklist
    " /conda-envs "$CONDA_PACK_URL" >> "$log" 2>&1

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $OUTPUT_LOCATION \
      "$SCRIPT_LOCATION/$SCRIPT_PATH" \
      >> "$log" 2>&1
    scriptExitCode=$?
    echo "Script exited with code $scriptExitCode" >> "$log"

    if [[ "$OUTPUT_LOCATION" != "$(runtime.outdir)" ]]; then
      echo "Copying results from run folder to CWL output directory" >> "$log"
      cp -a "$OUTPUT_LOCATION"/. "$(runtime.outdir)"/
    fi

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__download_griischecklist /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  country_name:
    label: Country name
    doc: Name of the country for which to download the GRIIS checklist.
    type:
      type: record
      name: country
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

  compendium_countries:
    type: File?
    label: Compendium countries
    doc: List of countries included in the compendium.
    default: /scripts/IAS/compendiumCountries.xlsx

  global_invasive_checklist:
    type: File?
    label: Global invasive alien species checklist
    doc: Global checklist used to identify species that are invasive anywhere.
    default: /scripts/IAS/species_isInvasiveAnywhere.csv



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
    default: IAS/download_griischecklist.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  griis_checklist_out:
    type: File
    label: GRIIS checklist
    doc: GRIIS checklist for the specified country.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "griis_checklist");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  griis_summary_out:
    type: File
    label: GRIIS summary
    doc: Summary of the GRIIS checklist for the specified country.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "griis_summary");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  griis_directory_out:
    type: File
    label: GRIIS directory
    doc: Directory where the GRIIS checklist is saved.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "griis_directory");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  all_data_summary_out:
    type: File
    label: GRIIS checklist summary (all data)
    doc: GRIIS checklist summary for all data.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "all_data_summary");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  per_list_summary_out:
    type: File
    label: GRIIS checklist summary (per list)
    doc: GRIIS checklist summary for each list.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "per_list_summary");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
