cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Get population polygons from bounding box
doc:
  - "Description:
    Component of the Genes from Space tool. Given a geographical bounding box, a species of interest, and a time window, the tool retrives the occurrences of the species from GBIF, and then calculates population polygons based on geographical proximity. "
  - "Authors:
    Oliver Selmoni (oliver.selmoni@gmail.com)"
  - "External link: https://teams.issibern.ch/genesfromspace/"
  - "References:
    Schuman et al., EcoEvoRxiv. null"


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement

inputs:
  #################
  # Script inputs #
  #################
  pipeline@12:
    type: string?
    label: Species names
    doc: Scientific name of the species, used to look for occurrences in GBIF. 
    default: Quercus sartorii

  pipeline@21:
    type: float[]?
    label: Bounding box 
    doc: Vector of float, bbox coordinates of the bbox in the order xmin, ymin, xmax, ymax
    default:
    - '-99'
    - '22'
    - '-92'
    - '29'

  GFS_IndicatorsTool>get_pop_poly.yml@5|buffer_size:
    type: float?
    label: Size of buffer
    doc: Radius size [in km] to determine population presence around the coordinates of species observations.
    default: 10

  GFS_IndicatorsTool>get_pop_poly.yml@5|pop_distance:
    type: float?
    label: Distance between populations
    doc: Distance [in km] to separate species observations in different populations.
    default: 50

  pipeline@15:
    type: int?
    label: End year
    doc: Integer, 4 digit year, end date to retrieve occurrences
    default: 2000

  pipeline@14:
    type: int?
    label: Start year
    doc: Integer, 4 digit year, start date to retrieve occurrences
    default: 1980



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

  GFS_IndicatorsTool>get_pop_poly.yml@5:
    run: ../../../../tools/GFS_IndicatorsTool/get_pop_poly.cwl
    in:
      species_obs: data>getObservations.yml@10/presence
      buffer_size: GFS_IndicatorsTool>get_pop_poly.yml@5|buffer_size
      pop_distance: GFS_IndicatorsTool>get_pop_poly.yml@5|pop_distance
      countries: { default: [] }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_pop_poly/5' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [population_polygons]


  data>getObservations.yml@10:
    run: ../../../../tools/data/getObservations.cwl
    in:
      species: pipeline@12
      country: { default: null }
      year_start: pipeline@14
      year_end: pipeline@15
      bbox: pipeline@21
      proj: { default: EPSG:4326 }
      occurrence_status: { default: present }
      limit: { default: 2000 }
      bbox_buffer: { default: 0 }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getObservations/10' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [n_presence, presence, bbox]


outputs:
  GFS_IndicatorsTool>get_pop_poly.yml@5|population_polygons:
    type: File
    label: Polygons of populations
    doc: Path to geojson file storing polygons of populations.
    outputSource: GFS_IndicatorsTool>get_pop_poly.yml@5/population_polygons

