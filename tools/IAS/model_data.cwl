#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: SInAS model IAS introduction rates
doc:
  - |
    Description:
    Select and run the IAS introduction-rate modelling approach supported by one country's data. Outputs explain model assumptions, detection and survey-effort limitations, and how far each result can be interpreted.
  - |
    Authors:
    Rachel Mason
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
        integrated_data: inputs.integrated_data ? inputs.integrated_data.path : null,
        covariate_data: inputs.covariate_data ? inputs.covariate_data.path : null,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" >> "$log"
    echo "Inputs:" >> "$log"
    cat "$OUTPUT_LOCATION/input.json" >> "$log"

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "IAS__model_data" \
    "channels: [conda-forge, r]
    dependencies: [r-base, r-cli, r-dharma, r-dplyr, r-ggeffects, r-ggplot2, r-mass, r-metrics,
      r-purrr, r-remotes, r-rjson, r-scales, r-tibble, r-tidyr]
    name: IAS__model_data
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__model_data /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  country_name:
    label: Country
    doc: Country for which IAS rate models will be produced.
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

  integrated_data:
    type: File?
    label: Integrated IAS data
    doc: Integrated IAS data produced by the SInAS merge-datasets step.

  covariate_data:
    type: File?
    label: GBIF survey-effort covariate
    doc: GBIF data containing a year column; may contain individual occurrence rows or annual counts.



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
    default: IAS/model_data.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  model_outputs_out:
    type: File
    label: Model outputs
    doc: Model assumptions, parameters, fit statistics, convergence status, estimated trend direction, interpretation, and caveats for every model option. First-record trends are not automatically equivalent to introduction trends.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "model_outputs");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  model_decision_out:
    type: File
    label: Modelling decision
    doc: Selected data scenario, adequacy criteria, supported level of inference, interpretation guidance, shared scope, and references.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "model_decision");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  data_summary_out:
    type: File
    label: Modelling data summary
    doc: Data-adequacy statistics for the selected country. First-record completeness is the percentage of GRIIS taxa flagged invasive anywhere that have a first-record year; it is not overall checklist completeness.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "data_summary");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  model_input_out:
    type: File
    label: Annual model input
    doc: Annual 1970–2020 IAS first-detection counts and GBIF observation counts used as an indirect survey-effort proxy. A zero means no input records for that year, not proof that no introductions occurred.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "model_input");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  qualitative_plot_out:
    type: File
    label: Qualitative model plot
    doc: Descriptive comparison of annual IAS first records with the GBIF observation proxy. The corresponding slope-based interpretation is provided in the Qualitative model interpretation output.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "qualitative_plot");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  qualitative_interpretation_out:
    type: string
    label: Qualitative model interpretation
    doc: Interpretation selected from the fitted IAS-observation and survey-effort trend combination. A trend is classified as stable when its fitted time slope is not significant at alpha = 0.05.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "qualitative_interpretation");
          return value;
        }

  quantitative_plot_out:
    type: File
    label: Quantitative model comparison
    doc: Fitted annual discovery records from models with alternative detection assumptions. Compare fit statistics only among converged models fitted to the same country and time series.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "quantitative_plot");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
