cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Get landcover cover change 1992-2020
doc:
  - "Description:
    Component of the Genes from Space tool. Given an area of interest, the tool creates a raster stack describing habitat presence for landcover classes and for years of interest (allowed time window range: 1992-2020). "
  - "Authors:
    Oliver Selmoni (oliver.selmoni@gmail.com)"
  - "External link: https://teams.issibern.ch/genesfromspace/"
  - "References:
    Schuman et al., EcoEvoRxiv. null

    ESA. Land Cover CCI Product User Guide Version 2. Tech. Rep. (2017) null"


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement

inputs:
  #################
  # Script inputs #
  #################
  GFS_IndicatorsTool>get_LCY.yml@115|population_polygons:
    type: File?
    label: Polygons of populations
    doc: Path to geojson file storing polygons of populations.
    default: /userdata/population_polygons.geojson

  GFS_IndicatorsTool>get_LCY.yml@115|res:
    type: float?
    label: Resolution of the land cover map
    doc: Desired resolution for land cover map, will be obtained via resampling. To be specified in decimal degrees (0.01 ~ 1 km). Minimal value 0.003 (~300m).
    default: 0.01

  GFS_IndicatorsTool>get_LCY.yml@115|lc_classes:
    type: int[]?
    label: Landcover classes
    doc: List of landcover class identifiers to be extract (for identifiers see https://savs.eumetsat.int/html/images/landcover_legend.png)
    default:
    - 130
    - 140

  GFS_IndicatorsTool>get_LCY.yml@115|yoi:
    type: int[]?
    label: Years of interest
    doc: List of years for which landcover should be extracted (maximum range 1992 - 2020).
    default:
    - 1995
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

  GFS_IndicatorsTool>get_LCY.yml@115:
    run: ../../../../tools/GFS_IndicatorsTool/get_LCY.cwl
    in:
      population_polygons: GFS_IndicatorsTool>get_LCY.yml@115|population_polygons
      res: GFS_IndicatorsTool>get_LCY.yml@115|res
      yoi: GFS_IndicatorsTool>get_LCY.yml@115|yoi
      lc_classes: GFS_IndicatorsTool>get_LCY.yml@115|lc_classes
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_LCY/115' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [lcyy, time_points]


outputs:
  GFS_IndicatorsTool>get_LCY.yml@115|time_points:
    type: string[]
    label: Years with land cover information
    doc: List of years for which land cover information is available.
    outputSource: GFS_IndicatorsTool>get_LCY.yml@115/time_points

  GFS_IndicatorsTool>get_LCY.yml@115|lcyy:
    type: File
    label: Land cover year-by-year
    doc: Tif file showing the year-by-year disrtribution of land cover classes of interest.
    outputSource: GFS_IndicatorsTool>get_LCY.yml@115/lcyy

