#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Calculate SHI
doc:
  - "Description:
    This script produces 1) the Species Habitat Index time series, by averaging the Species Habitat Scores; 2) the Steward’s Species Habitat Index, by averaging the Species Habitat Scores weighted by the proportion between the area of habitat for the study area and the total range map of the species."
  - "Authors:
    Maria Isabel Arce-Plata (https://orcid.org/0000-0003-4024-9268)
    Guillaume Larocque (https://orcid.org/0000-0002-5967-9156)"
  - "External link: https://github.com/GEO-BON/biab-2.0/tree/main/scripts/SHI"
  - "References:
    Jetz et al., Species Habitat Index, accessed on 24/8/2022. null

    World Conservation Monitoring Centre (WCMC) & Convention on Biological Diversity (CBD). 2022. Indicator metadata sheet, accessed on 10/9/2023. null

    Jetz, W., McGowan, J., Rinnan, D. S., Possingham, H. P., Visconti, P., O’Donnell, B., & Londoño-Murcia, M. C. (2022). Include biodiversity representation indicators in area-based conservation targets. Nature Ecology & Evolution, 6(2), 123–126. null"


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
        df_shs_tidy: inputs.df_shs_tidy,
        df_aoh_areas: inputs.df_aoh_areas,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "SHI__calculateSHI" \
    "channels: [conda-forge, r]
    dependencies: [r-dplyr, r-purrr, r-readr, r-ggplot2, r-rjson]
    name: SHI__calculateSHI
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SHI__calculateSHI /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  df_shs_tidy:
    type: File[]?
    label: SHS table (long format)
    doc: A TSV (Tab Separated Values) file containing Habitat Score, Connectivity Score, and SHI by time step. Percentage of change, 100% being equal to the reference year.
    default:
    - /scripts/SHI/Myrmecophaga tridactyla_SHS_table_tidy.tsv
    - /scripts/SHI/Ateles fusciceps_SHS_table_tidy.tsv

  df_aoh_areas:
    type: File?
    label: table with size of areas of reference.
    doc: A TSV (Tab Separated Values) file containing the area of the range map loaded (area_range_map), the size of the study area (area_study_a), the area of the bounding box for the analysis (area_bbox_analysis), size of the buffer used to create the bounding box for the analysis, the size of the area of habitat(area_aoh).
    default: /scripts/SHI/df_aoh_areas.tsv



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
    default: SHI/calculateSHI.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  df_shi:
    type: File
    label: SHI table
    doc: Table with SHI and Steward’s SHI values for the complete area of study.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "df_shi");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  img_shi_timeseries:
    type: File
    label: SHI time series
    doc: Figure showing a time series of SHI values for each time step, 100% being equal to the reference year.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "img_shi_timeseries");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  img_w_shi_timeseries:
    type: File
    label: Steward’s SHI time series
    doc: Figure showing a time series of Steward’s SHI values for each time step. This is weighted by the proportion between the area of habitat for the study area and the total range map of the species. The reference year will start at the proportion of area of habitat in the study area. For example, if half of the species habitat is covered by the study area, the reference year’s value will be 50%.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "img_w_shi_timeseries");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
