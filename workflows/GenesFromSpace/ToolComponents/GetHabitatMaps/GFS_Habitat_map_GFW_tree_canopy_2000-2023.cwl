cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Get GFW forest cover change 2000-2023
doc:
  - "Description:
    Component of the Genes from Space tool. Given an area of interest, the tool creates a raster stack describing forest habitat presence for the years of interest (maximum range: from 2000 to 2023). Forest habitat presence made available by the Global Forest Watch (https://www.globalforestwatch.org/)"
  - "Authors:
    Oliver Selmoni (oliver.selmoni@gmail.com)"
  - "External link: https://teams.issibern.ch/genesfromspace/"
  - "References:
    Schuman et al., EcoEvoRxiv. null

    Hansen et al., Science (2013) null"


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement

inputs:
  #################
  # Script inputs #
  #################
  GFS_IndicatorsTool>get_TCY.yml@23|res:
    type: float?
    label: Resolution of tree cover map
    doc: Desired resolution for tree cover map, will be obtained via resampling. To be specified in decimal degrees (0.01 ~ 1 km). Minimal value 0.001 (~100m).
    default: 0.01

  GFS_IndicatorsTool>get_TCY.yml@23|population_polygons:
    type: File?
    label: Polygons of populations
    doc: Path to geojson file storing polygons of populations.
    default: /userdata/populations.geojson

  GFS_IndicatorsTool>get_TCY.yml@23|yoi:
    type: int[]?
    label: Years of interest
    doc: List of years for which tree cover should be extracted (maximum range 2000 - 2023).
    default:
    - 2000
    - 2005
    - 2010
    - 2015
    - 2020



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.
    default:
      class: Directory
      path: ./envs

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

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.



steps:
  # This step prepares the environments for all the following steps
  prepareEnvironments:
    run:
      class: CommandLineTool
      requirements:
        InplaceUpdateRequirement:
          inplaceUpdate: true
        NetworkAccess:
          networkAccess: true
        InlineJavascriptRequirement: {}
        InitialWorkDirRequirement:
          listing: |
            ${
              return [
                { entry: inputs.envFolderWrite, writable: true },
                {
                  entry: { "class": "Directory", "basename": "conda-env-yml", "listing": [] },
                  entryname: "/conda-env-yml",
                  writable: true
                }
              ].concat(
                inputs.runFolderWrite
                  ? [{ entry: inputs.runFolder, writable: true }]
                  : []
              );
            }
        DockerRequirement:
          dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:cwl-poc
        EnvVarRequirement:
          envDef:
            CONDA_PKGS_DIRS: /conda-env-yml/pkgs
            CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
            SCRIPT_STUBS_LOCATION: /script-stubs
            OUTPUT_LOCATION: "$(inputs.runFolderWrite ? inputs.runFolderWrite.path : runtime.outdir)"
      baseCommand: [bash, -c]
      arguments:
        - |
          echo "Exporting all environments"
          mkdir -p "$OUTPUT_LOCATION" "$CONDA_PKGS_DIRS" /conda-env-yml/envs
          
          function exportEnv {
            condaEnvName=$1
            condaEnvYml=$2
            unpackedFolder=$(inputs.envFolderWrite.path)/$condaEnvName
            
            echo "Exporting $condaEnvName..."
            source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "$condaEnvName" \
              "$condaEnvYml" $(inputs.envFolderWrite.path) $(inputs.condaPackURL)
            source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh $condaEnvName $(inputs.envFolderWrite.path)
            if [[ ! -d "$unpackedFolder" ]]; then
              # remove the env to force using the conda-pack
              mamba env remove -y -n "$condaEnvName"
              source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "$condaEnvName" \
                "$condaEnvYml" $(inputs.envFolderWrite.path) $(inputs.condaPackURL)
            fi
            echo "Done."
          }
          export -f exportEnv
          

          
      inputs:
        envFolderWrite:
          type: Directory
        runFolderWrite:
          type: Directory?
        condaPackURL:
          type: string
      outputs:
        envFolder:
          type: Directory
          outputBinding:
            glob: .
            outputEval: $(inputs.envFolderWrite)
    in:
      envFolderWrite: envFolder
      runFolder:
        source: runFolder
        valueFrom: "$({ class: 'Directory', location: (self ? self.location : '/tmp/cwl' ) + '/prepareEnvironments' })"
      condaPackURL: condaPackURL
    out: [envFolder]

  GFS_IndicatorsTool>get_TCY.yml@23:
    run: ../../../../tools/GFS_IndicatorsTool/get_TCY.cwl
    in:
      population_polygons: GFS_IndicatorsTool>get_TCY.yml@23|population_polygons
      res: GFS_IndicatorsTool>get_TCY.yml@23|res
      yoi: GFS_IndicatorsTool>get_TCY.yml@23|yoi
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_TCY/23' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [tcyy, time_points]


outputs:
  GFS_IndicatorsTool>get_TCY.yml@23|tcyy:
    type: File
    label: Tree cover year-by-year
    doc: Tif file of year-by-year tree cover, cropped to bbox extent
    outputSource: GFS_IndicatorsTool>get_TCY.yml@23/tcyy

  GFS_IndicatorsTool>get_TCY.yml@23|time_points:
    type: string[]
    label: Years with tree cover information
    doc: List of years for which tree cover information is available.
    outputSource: GFS_IndicatorsTool>get_TCY.yml@23/time_points

