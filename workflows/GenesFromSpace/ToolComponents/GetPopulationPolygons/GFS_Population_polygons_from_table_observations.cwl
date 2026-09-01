cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Get population polygons from species observation
doc:
  - |
    Description:
    Component of the Genes from Space tool. Given a table of species occurrences, the tool calculates population polygons based on geographical proximity. 
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
  GFS_IndicatorsTool>get_pop_poly.yml@5|species_obs:
    type: File?
    label: Coordinates of species occurrence
    doc: Path to the table storing the species observation coordinates. The table must incude header with "decimal_longitude" and "decimal_latitude" columns, indicating the coordinates of every observation.
    default: /userdata/obs_data.tsv

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

  GFS_IndicatorsTool>get_pop_poly.yml@5:
    run: ../../../../tools/GFS_IndicatorsTool/get_pop_poly.cwl
    in:
      species_obs: GFS_IndicatorsTool>get_pop_poly.yml@5|species_obs
      buffer_size: GFS_IndicatorsTool>get_pop_poly.yml@5|buffer_size
      pop_distance: GFS_IndicatorsTool>get_pop_poly.yml@5|pop_distance
      countries: { default: [] }
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_pop_poly/5' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [population_polygons_out]


outputs:
  GFS_IndicatorsTool>get_pop_poly.yml@5|population_polygons_out:
    type: File
    label: Polygons of populations
    doc: Path to geojson file storing polygons of populations.
    outputSource: GFS_IndicatorsTool>get_pop_poly.yml@5/population_polygons_out

