#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: SInAS Prepare Datasets
doc:
  - |
    Description:
    Run original P3 Steps 1-5 for one country: prepare and roll up mapped First Records regions to the parent country, standardise columns, terminology, locations, GBIF taxonomy and event dates, and report unmatched or excluded records.
  - |
    Authors:
    Manuela Gomez-Suarez
    Hanno Seebens
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
        griis_checklist: inputs.griis_checklist ? inputs.griis_checklist.path : null,
        first_records: inputs.first_records ? inputs.first_records.path : null,
        global_invasive_checklist: inputs.global_invasive_checklist ? inputs.global_invasive_checklist.path : null,
        national_checklist: inputs.national_checklist ? inputs.national_checklist.path : null,
        kingdoms: inputs.kingdoms,
        habitats: inputs.habitats,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" >> "$log"
    echo "Inputs:" >> "$log"
    cat "$OUTPUT_LOCATION/input.json" >> "$log"

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "IAS__prepare_datasets" \
    "channels: [conda-forge, r]
    dependencies: [r-dplyr, r-jsonlite, r-duckdb, r-rjson, r-stringr, r-rgbif, r-tidyr,
      r-stringi, r-openxlsx]
    name: IAS__prepare_datasets
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__prepare_datasets /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  country_name:
    label: Country
    doc: Country represented by this cleaning run.
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

  griis_checklist:
    type: File?
    label: GRIIS checklist
    doc: GRIIS checklist table to include in Step 1 preparation.

  first_records:
    type: File?
    label: First records
    doc: First records table to include in Step 1 preparation.

  global_invasive_checklist:
    type: File?
    label: Global invasive alien species checklist
    doc: Same packaged global checklist used by the download step, rechecked against original and harmonised taxon names while preserving existing positive flags.
    default: /scripts/IAS/species_isInvasiveAnywhere.csv

  national_checklist:
    type: File?
    label: Imported national checklist
    doc: Optional mapped national checklist from the import step.

  kingdoms:
    type:
      type: array
      items:
        type: enum
        symbols:
          - PLANTAE
          - ANIMALIA
    label: Kingdoms
    doc: Kingdoms to retain in both the GRIIS and First Records datasets.
    default:
    - PLANTAE
    - ANIMALIA

  habitats:
    type:
      type: array
      items:
        type: enum
        symbols:
          - TERRESTRIAL
          - FRESHWATER
          - FRESHWATER|BRACKISH
          - TERRESTRIAL|FRESHWATER
          - MARINE|FRESHWATER|BRACKISH
          - TERRESTRIAL|BRACKISH
          - TERRESTRIAL|FRESHWATER|BRACKISH
          - TERRESTRIAL|MARINE|FRESHWATER
          - TERRESTRIAL|MARINE|BRACKISH
          - MARINE|FRESHWATER
          - TERRESTRIAL|MARINE
    label: Habitat types
    doc: Habitat values to retain in both the GRIIS and First Records datasets.
    default:
    - TERRESTRIAL
    - FRESHWATER
    - FRESHWATER|BRACKISH
    - TERRESTRIAL|FRESHWATER
    - MARINE|FRESHWATER|BRACKISH
    - TERRESTRIAL|BRACKISH
    - TERRESTRIAL|FRESHWATER|BRACKISH
    - TERRESTRIAL|MARINE|FRESHWATER
    - TERRESTRIAL|MARINE|BRACKISH
    - MARINE|FRESHWATER
    - TERRESTRIAL|MARINE



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
    default: IAS/prepare_datasets.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  global_invasive_matches_out:
    type: File
    label: Additional global invasive matches
    doc: GRIIS records newly flagged as invasive anywhere after taxonomic harmonisation, with matching name fields and country evidence.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "global_invasive_matches");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  griis_clean_out:
    type: File
    label: cleaned GRIIS dataset
    doc: Cleaned GRIIS dataset with standardised column names and values.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "griis_clean");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  first_records_clean_out:
    type: File
    label: cleaned First Records dataset
    doc: Cleaned First Records dataset with standardised column names and values.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "first_records_clean");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  national_clean_out:
    type: File
    label: Cleaned national checklist
    doc: National checklist after SInAS standardisation. Produced only when a checklist is supplied.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "national_clean");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  file_info_out:
    type: File
    label: File information
    doc: Table containing information about the input datasets columns
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "file_info");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  translated_locations_out:
    type: File
    label: Translated locations
    doc: Original and standardised location-name pairs.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "translated_locations");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  full_taxa_list_out:
    type: File
    label: SInAS taxon matching
    doc: Complete automatic GBIF taxonomic matching results.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "full_taxa_list");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  translated_event_dates_out:
    type: File
    label: Translated event dates
    doc: Original and standardised event-date values.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "translated_event_dates");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  cleaning_summary_out:
    type: File
    label: Cleaning summary
    doc: Input, output, and unresolved-record counts for both datasets.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "cleaning_summary");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  qc_status_out:
    type: File
    label: Quality-control status
    doc: PASS or WARNING summary for terminology, locations, taxonomy, and event dates. Warnings do not block merging.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "qc_status");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  unmatched_values_out:
    type: File
    label: Unmatched values
    doc: Consolidated report of terminology, location, taxon, and event-date values that could not be standardised, including the action taken and whether they can enter the merge.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "unmatched_values");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  excluded_records_out:
    type: File
    label: SInAS excluded records
    doc: Complete records excluded from the merged dataset because their locations could not be standardised to a locationID.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "excluded_records");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
