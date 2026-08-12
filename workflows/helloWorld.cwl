cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Hello World pipeline
doc:
  - "Description:
    This very simple pipeline shows how to connect a single script to a single output.
    The input of the script is left blank, thus becoming a pipeline input."
  - "Lifecycle tag: Example."
  - "Authors:
    Jean-Michel Lord (https://orcid.org/0009-0007-3826-1125)"
  - "External link: https://github.com/GEO-BON/biab-2.0"


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement

inputs:
  #################
  # Script inputs #
  #################
  helloWorld>helloPython.yml@0|some_int:
    type: int?
    label: Some int
    doc: A number that we will increment
    default: 3

  helloWorld>helloPython.yml@0|study_area_bbox:
    label: Bounding box
    doc: Bounding box and CRS of study area
    type:
      type: record
      name: bboxCRS
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
      - name: CRS
        type:
          name: CRSDefinition
          type: record
          fields:
          - name: unit
            type: string?
          - name: code
            type: int?
          - name: authority
            type: string?
          - name: name
            type: string?
          - name: CRSBboxWGS84
            type: float[]?
          - name: proj4Def
            type: string?
          - name: wktDef
            type: string?
      - name: bbox
        type: float[]
      - name: region
        type:
          name: regionDefinition
          type: record
          fields:
          - name: countryEnglishName
            type: string?
          - name: regionID
            type: string?
          - name: regionName
            type: string?
          - name: bboxWGS84
            type: float[]?



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

  helloWorld>helloPython.yml@0:
    run: ../tools/helloWorld/helloPython.cwl
    in:
      some_int: helloWorld>helloPython.yml@0|some_int
      study_area_bbox: helloWorld>helloPython.yml@0|study_area_bbox
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/helloWorld__helloPython/0' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [increment, crs_id]


outputs:
  helloWorld>helloPython.yml@0|increment:
    type: int
    label: A number (input++)
    doc: bla bla
    outputSource: helloWorld>helloPython.yml@0/increment

