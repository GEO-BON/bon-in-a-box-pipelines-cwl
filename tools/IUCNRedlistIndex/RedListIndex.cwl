#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Red List Index
doc:
  - "Description:
    Estimates the Red List Index (RLI) for a group of species, reflecting trends in the overall extinction risk for that group."
  - "Authors:
    Maria Camila diaz (maria.camila.diaz.corzo@usherbrooke.ca)
    Victor Julio Rincon (rincon-v@javeriana.edu.co)
    Laetitia Tremblay (Maintenance, laetitia.tremblay@mcgill.ca, http://www.linkedin.com/in/laetitia-tremblay-b0619b273)"
  - "External link: https://nrl.iucnredlist.org/assessment/red-list-index"


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
        history_assessment_data: inputs.history_assessment_data,
        country: inputs.country,
        taxonomic_group: inputs.taxonomic_group,
        species_use: inputs.species_use,
        threat: inputs.threat,
        sp_col: inputs.sp_col,
        time_col: inputs.time_col,
        threat_category_code_column: inputs.threat_category_code_column,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "IUCNRedlistIndex__RedListIndex" \
      "
        channels: [conda-forge, r]
        dependencies: [r-magrittr, r-data.table, r-reshape2, r-dplyr, r-plyr, r-ggplot2, r-tibble,
          r-pbapply, r-rredlist, r-plyr, r-gdistance, r-BAT, r-ape, r-geometry, r-magic, r-hypervolume,
          r-ks, r-mclust, r-mvtnorm, r-pracma, r-fastcluster, r-pdist, r-palmerpenguins, r-caret,
          r-recipes, r-timeDate, r-gower, r-hardhat, r-ipred, r-prodlim, r-lava, r-future.apply,
          r-future, r-globals, r-listenv, r-parallelly, r-ModelMetrics, r-pROC, r-nls2, r-proto,
          r-vegan, r-permute, r-phytools, r-combinat, r-clusterGeneration, r-DEoptim, r-expm,
          r-optimParallel, r-phangorn, r-fastmatch, r-scatterplot3d, r-predicts, r-coda, r-mnormt,
          r-numDeriv, r-quadprog, r-dismo, r-geosphere, r-rjson]
        name: IUCNRedlistIndex__RedListIndex
      " /conda-envs $(inputs.condaPackURL) >> "$log" 2>&1

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IUCNRedlistIndex__RedListIndex /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  history_assessment_data:
    type: File
    label: History assessment data
    doc: Dataset that contains the list of species and their historical threat category assessments.
    default: scripts/RedListIndex/input/iucn_history_assessment_data.csv

  country:
    label: Country
    doc: Country of interest.
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

  taxonomic_group:
    type: string[]
    label: Taxonomic group
    doc: Name of taxonomic group of interest

  species_use:
    type: string[]
    label: Species use(s) or trade(s)
    doc: The species use or trade selected

  threat:
    type: string[]
    label: Species threat(s)
    doc: The threat category selected

  sp_col:
    type: string
    label: Species name column
    doc: Name of the column in 'history_assessment_data' that contains the scientific names of the species.
    default: scientific_name

  time_col:
    type: string
    label: Time column
    doc: Name of the column in 'history_assessment_data' that contains the periods (years) when the assessments were conducted for each species.
    default: assess_year

  threat_category_code_column:
    type: string
    label: Threat category column
    doc: Name of the column in 'history_assessment_data' that contains the threat category code. The codes should correspond to the IUCN threat category codes (EX, EW, RE, CR, EN, VU, NT, DD, LC).
    default: code



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
    default: IUCNRedlistIndex/RedListIndex.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  redlist_trend_plot:
    type: File
    label: Red List trend
    doc: The Red List Index of species for the chosen taxonomy group over time. An RLI of 1.0 indicates that all species have a status of Least Concerned, while 0.0 indicates Extinct. If the RLI value is constant over time, the overall extinction risk remains unchanged. An upward trend shows a reduction in the rate of biodiversity loss.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "redlist_trend_plot");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  redlist_data:
    type: File
    label: Red List data
    doc: Dataset containing the results of the Red List Index (RLI) calculation.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "redlist_data");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  redlist_matrix:
    type: File
    label: Red List matrix
    doc: Matrix showing the distribution of threat categories over time for the group of species.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "redlist_matrix");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'logs.txt')"
