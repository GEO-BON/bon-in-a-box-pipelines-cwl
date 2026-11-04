#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: SInAS Merge Standardised Datasets
doc:
  - |
    Description:
    Merge one country's standardised sources. An optional national checklist defines membership and supplies preferred first-record years; without it, use the existing GRIIS and First Records merging rules.
  - |
    Authors:
    Manuela Gomez-Suarez
    Hanno Seebens
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
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335
    # dockerImageId: conda-cwl-runner-local
    # dockerFile:
    #     $include: ../runners/cwl/conda-cwl.dockerfile

  EnvVarRequirement:
    envDef:
      CONDA_PKGS_DIRS: /conda-env-yml/pkgs
      CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
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

    mkdir -p /conda-env-yml/pkgs /conda-env-yml/envs

    cat > "$OUTPUT_LOCATION/input.json" <<'JSON'
    ${
      return JSON.stringify({
        country_name: inputs.country_name,
        griis_clean: inputs.griis_clean ? inputs.griis_clean.path : null,
        first_records_clean: inputs.first_records_clean ? inputs.first_records_clean.path : null,
        national_clean: inputs.national_clean ? inputs.national_clean.path : null,
        full_taxa_list: inputs.full_taxa_list ? inputs.full_taxa_list.path : null,
        cleaning_summary: inputs.cleaning_summary ? inputs.cleaning_summary.path : null,
        qc_status: inputs.qc_status ? inputs.qc_status.path : null,
        unmatched_values: inputs.unmatched_values ? inputs.unmatched_values.path : null,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" >> "$log"
    echo "Inputs:" >> "$log"
    cat "$OUTPUT_LOCATION/input.json" >> "$log"

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "IAS__merge_datasets" \
    "channels: [conda-forge, r]
    dependencies: [r-base, r-rjson]
    name: IAS__merge_datasets
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__merge_datasets /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  country_name:
    label: Country
    doc: Country represented by this run.
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

  griis_clean:
    type: File?
    label: Cleaned GRIIS dataset
    doc: GRIIS dataset after SInAS terminology, location, taxonomy, and event-date standardisation.

  first_records_clean:
    type: File?
    label: Cleaned First Records dataset
    doc: First Records dataset after SInAS terminology, location, taxonomy, and event-date standardisation.

  national_clean:
    type: File?
    label: Cleaned national checklist
    doc: Optional SInAS-cleaned national checklist. When supplied, only its taxa and locations are retained; valid national first-record years take precedence over external years. Checklist membership does not imply invasive status.

  full_taxa_list:
    type: File?
    label: Reviewed full taxonomic list
    doc: GBIF taxonomic hierarchy and taxon IDs produced by the SInAS preparation step.

  cleaning_summary:
    type: File?
    label: Preparation summary
    doc: Record counts and unresolved-value counts produced while preparing the supplied source datasets.

  qc_status:
    type: File?
    label: Quality-control status
    doc: Quality-control status produced while preparing the supplied source datasets.

  unmatched_values:
    type: File?
    label: Unmatched values
    doc: Values that could not be standardised during preparation and the action taken for each value.



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
    default: IAS/merge_datasets.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  merged_dataset_out:
    type: File
    label: Merged SInAS dataset
    doc: One record per standardised taxon-location-establishment combination in the default workflow, or per national taxon-location identity when a national checklist is supplied. National outputs retain membership, date sources, competing date evidence and uploaded values.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "merged_dataset");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  data_quality_report_out:
    type: File
    label: SInAS data-quality report
    doc: Combined quality-control status, unmatched-value report, and merge-conflict report.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "data_quality_report");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  run_summary_out:
    type: File
    label: SInAS run summary
    doc: Preparation and merge record counts, warning counts, exclusions, and overall quality-control status.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "run_summary");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  merge_summary_out:
    type: File
    label: Merge summary
    doc: Input and output record counts for the selected country.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "merge_summary");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  merge_conflicts_out:
    type: File
    label: Merge conflicts
    doc: Fields with multiple values during final SInAS record consolidation.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "merge_conflicts");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
