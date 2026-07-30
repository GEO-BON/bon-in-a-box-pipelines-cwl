#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Get genetic diversity indicators
doc:
  - "Description:
    This script takes the population habitat size information, and use it to compute genetic diversity indicators."
  - "Authors:
    Simon Pahls
    Oliver Selmoni"


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
        population_polygons: inputs.population_polygons,
        habitat_map: inputs.habitat_map,
        pop_area: inputs.pop_area,
        ne_nc: inputs.ne_nc,
        pop_density: inputs.pop_density,
        runtitle: inputs.runtitle,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "GFS_IndicatorsTool__get_Indicators" \
      "
        channels: [conda-forge, r]
        dependencies: [r-devtools, r-rjson, r-terra, r-sf, r-rnaturalearth, r-teachingdemos,
          r-dplyr, r-plotly, r-geojsonsf, r-colorspace, r-lwgeom]
        name: GFS_IndicatorsTool__get_Indicators
      " /conda-envs $(inputs.condaPackURL) >> "$log" 2>&1

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh GFS_IndicatorsTool__get_Indicators /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  population_polygons:
    type: File
    label: Polygons of populations
    doc: Path to geojson file storing polygons of populations.
    default: /userdata/population_polygons.geojson

  habitat_map:
    type: File
    label: Binary map of habitat presence/absence
    doc: Tif file of maps of presence (1) or absence (0) of suitable habitat. Multiple layers can stacked and used to describe habitat availability at different time points.
    default: /userdata/tcyy.tif

  pop_area:
    type: File
    label: Table of habitat area by population
    doc: Table of estimated habitat area by population (rows). If provided, time points are displayed as columns.
    default: /userdata/pop_habitat_area.tsv

  ne_nc:
    type: float[]
    label: Ne:Nc ratio estimate
    doc: Estimated Ne:Nc ratio for the studied species. Multiple values can be provided, separated by a comma.
    default:
    - 0.1
    - 0.2

  pop_density:
    type: float[]
    label: Population density
    doc: Estimated density of the population [number of individuals per km2]. Multiple values can be provided, separated by a comma.
    default:
    - 50
    - 100
    - 1000

  runtitle:
    type: string
    label: Title of the run
    doc: Set a name for the pipeline run.
    default: Quercus sartorii, Mexico, Habitat decline by tree cover loss, 2000-2023



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
    default: GFS_IndicatorsTool/get_Indicators.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  ne_table:
    type: File
    label: Effective population size
    doc: Estimated effective size of every population, based on the latest time point of the habitat cover map.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "ne_table");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  pm:
    type: float
    label: Population maintained indicator
    doc: Estimated proportion of mantained populations, comparing earliest and latest time point. A value of 1 means that no populations went extinct over the time frame.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "pm");
          if (value === null) return null;
          return parseFloat(value);
        }

  interactive_plot:
    type: File
    label: Interactive plot
    doc: An interactive interface to explore indicators trends across geographical space and time.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "interactive_plot");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  ne500:
    type: float
    label: Ne>500 indicator
    doc: Estimated proportion of populations with Ne>500 at latest time point.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "ne500");
          if (value === null) return null;
          return parseFloat(value);
        }


  logs:
    type: File
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'logs.txt')"
