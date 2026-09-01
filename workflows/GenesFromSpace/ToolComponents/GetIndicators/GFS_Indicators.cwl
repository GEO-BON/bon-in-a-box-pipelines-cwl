cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Calculate genetic diversity indicators
doc:
  - |
    Description:
    Component of the Genes from Space tool. Given poylgons of population distribution (geojson format) and a raster stack describing habitat availability over time (geotiff format), the pipeline returns genetic diversity loss indicators (Ne500 and Populations Maintained indicator), displayed through an interactive interface. 
  - |
    Authors:
    Oliver Selmoni (oliver.selmoni@gmail.com)
  - "External link: https://teams.issibern.ch/genesfromspace/"
  - |
    References:
    Schuman et al., EcoEvoRxiv.
    null


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement
  MultipleInputFeatureRequirement:
    class: MultipleInputFeatureRequirement

inputs:
  #################
  # Script inputs #
  #################
  pipeline@100:
    type: File?
    label: Polygons of populations
    doc: Path to geojson file storing polygons of populations.
    default: /userdata/population_polygons.geojson

  pipeline@101:
    type: File?
    label: Binary map of habitat presence/absence
    doc: Tif file describing presence (1) or absence (0) of suitable habitat. Multiple layers can be used to describe habitat availability at different time points.
    default: /userdata/tcyy.tif

  pipeline@102:
    type: string[]?
    label: Time points of habitat map
    doc: List of time points corresponding to habitat map layers.
    default:
    - y2000
    - y2001
    - y2002
    - y2003
    - y2004
    - y2005
    - y2006
    - y2007
    - y2008
    - y2009
    - y2010
    - y2011
    - y2012
    - y2013
    - y2014
    - y2015
    - y2016
    - y2017
    - y2018
    - y2019
    - y2020
    - y2021
    - y2022
    - y2023

  GFS_IndicatorsTool>get_Indicators.yml@127|ne_nc:
    type: float[]?
    label: Ne:Nc ratio estimate
    doc: Estimated Ne:Nc ratio for the studied species. Multiple values can be provided, separated by a comma.
    default:
    - 0.1
    - 0.2

  GFS_IndicatorsTool>get_Indicators.yml@127|pop_density:
    type: float[]?
    label: Population density
    doc: Estimated density of the population [number of individuals per km2]. Multiple values can be provided, separated by a comma.
    default:
    - 50
    - 100
    - 1000

  GFS_IndicatorsTool>get_Indicators.yml@127|runtitle:
    type: string?
    label: Title of the run
    doc: Set a name for the pipeline run.
    default: Quercus sartorii, Mexico, Habitat decline by tree cover loss, 2000-2023



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory?
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.

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
    when: $(inputs.envFolderWrite != null)
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
          dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-eee5c95
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
          
          function getPackedEnv {
            condaEnvName=$1
            condaEnvYml=$2
            # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context
            dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName
            mkdir -p "$dedicatedEnvFolder"
            
            echo "Exporting $condaEnvName..."
            source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh "$OUTPUT_LOCATION" "$condaEnvName" \
              "$condaEnvYml" "$dedicatedEnvFolder" "$(inputs.condaPackURL)" --noActivate
            source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh "$condaEnvName" "$dedicatedEnvFolder"
            echo "Done."
          }
          export -f getPackedEnv

          bash -c 'getPackedEnv "GFS_IndicatorsTool__get_Indicators" "channels: [conda-forge, r]
          dependencies: [r-devtools, r-rjson, r-terra, r-sf, r-rnaturalearth, r-teachingdemos,
            r-dplyr, r-plotly, r-geojsonsf, r-colorspace, r-lwgeom]
          name: GFS_IndicatorsTool__get_Indicators
          "'
          
      inputs:
        envFolderWrite:
          type: Directory?
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

  GFS_IndicatorsTool>pop_area_by_habitat.yml@99:
    run: ../../../../tools/GFS_IndicatorsTool/pop_area_by_habitat.cwl
    in:
      population_polygons: pipeline@100
      habitat_map: pipeline@101
      time_points: pipeline@102
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__pop_area_by_habitat/99' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [pop_area_out]


  GFS_IndicatorsTool>get_Indicators.yml@127:
    run: ../../../../tools/GFS_IndicatorsTool/get_Indicators.cwl
    in:
      population_polygons: pipeline@100
      habitat_map: pipeline@101
      pop_area: GFS_IndicatorsTool>pop_area_by_habitat.yml@99/pop_area_out
      ne_nc: GFS_IndicatorsTool>get_Indicators.yml@127|ne_nc
      pop_density: GFS_IndicatorsTool>get_Indicators.yml@127|pop_density
      runtitle: GFS_IndicatorsTool>get_Indicators.yml@127|runtitle
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_Indicators' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_Indicators/127' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [ne_table_out, pm_out, interactive_plot_out, ne500_out]


outputs:
  GFS_IndicatorsTool>get_Indicators.yml@127|ne_table_out:
    type: File
    label: Effective population size
    doc: Estimated effective size of every population, based on the latest time point of the habitat cover map.
    outputSource: GFS_IndicatorsTool>get_Indicators.yml@127/ne_table_out

  GFS_IndicatorsTool>get_Indicators.yml@127|pm_out:
    type: float
    label: Population maintained indicator
    doc: Estimated proportion of mantained populations, comparing earliest and latest time point.
    outputSource: GFS_IndicatorsTool>get_Indicators.yml@127/pm_out

  GFS_IndicatorsTool>get_Indicators.yml@127|interactive_plot_out:
    type: File
    label: Interactive plot
    doc: An interactive interface to explore indicators trends across geographical space and time.
    outputSource: GFS_IndicatorsTool>get_Indicators.yml@127/interactive_plot_out

  GFS_IndicatorsTool>get_Indicators.yml@127|ne500_out:
    type: float
    label: Ne>500 indicator
    doc: Estimated proportion of populations with Ne>500 at latest time point.
    outputSource: GFS_IndicatorsTool>get_Indicators.yml@127/ne500_out

