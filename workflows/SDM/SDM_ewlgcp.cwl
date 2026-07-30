cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Species distribution modeling with ewlgcpSDM
doc:
  - "Description:
    This pipeline generates predictions from a species distribution model  using a point process approach and the effort-weighted Log-Gaussian  Cox Process (ewlgcp) implemented in the R package [ewlgcpSDM](https://github.com/BiodiversiteQuebec/ewlgcpSDM)."
  - "Authors:
    François Rousseu (Pipeline development, https://orcid.org/0000-0002-2400-2479)
    Guillaume Blanchet (Pipeline development, https://orcid.org/0000-0001-5149-2488)
    Dominique Gravel (Pipeline development, https://orcid.org/0000-0002-4498-7076)"
  - "External link: https://github.com/GEO-BON/biab-2.0/blob/main/scripts/SDM/runewlgcp.R"


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement

inputs:
  #################
  # Script inputs #
  #################
  data>loadFromStac.yml@140|stac_url:
    type: string
    label: STAC URL
    doc: URL of the STAC catalog to pull predictor layers.
    default: https://stac.geobon.org/

  data>loadFromStac.yml@140|collections_items:
    type: string[]
    label: STAC collection items
    doc: Collection name of STAC layers followed by '|' followed by item id
    default:
    - chelsa-clim|bio5
    - earthenv_landcover|class_1
    - earthenv_landcover|class_7
    - earthenv_landcover|class_3

  data>GBIFHeatmapFromSTAC.yml@145|taxa:
    type:
      type: enum
      symbols:
        - reptiles
        - plants
        - mammals
        - birds
        - arthropods
        - amphibians
        - all
    label: Taxa
    doc: taxonomic group for which to retrieve GBIF heatmap
    default: plants

  pipeline@121:
    type: string[]
    label: Taxa list
    doc: Array of taxa values
    default:
    - Acer saccharum

  data>loadFromStac.yml@140|study_area:
    type: File
    label: Study area
    doc: Polygon of study area used to crop output layers

  SDM>selectBackground.yml@40|method_background:
    type:
      type: enum
      symbols:
        - random
        - inclusion_buffer
        - weighted_raster
        - unweighted_raster
    label: Method background
    doc: Method used to sample background points
    default: weighted_raster

  SDM>selectBackground.yml@40|n_background:
    type: int
    label: Number of background points
    doc: Number of background points
    default: 100000

  data>getGBIFObservations>getGBIFObservations.yml@139|min_year:
    type: int
    label: minimum year
    doc: Min year observations wanted
    default: 2010

  pipeline@149:
    label: Bounding and CRS
    doc: Select a bounding box and CRS
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

  data>getGBIFObservations>getGBIFObservations.yml@139|max_year:
    type: int
    label: maximum year
    doc: Max year observations wanted
    default: 2024

  pipeline@46:
    type: int
    label: Number of blocks
    doc: Number of blocks (for crossvalidation method, currently ignored)
    default: 2

  pipeline@128:
    type: float
    label: Spatial resolution
    doc: >
      Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). 
      
      If this is left blank it will use the native resolution of the rasters. 
      
      If the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled with the resampling method chosen below.
    default: 1000



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
              mkdir -p "$unpackedFolder"
              tar -xf "$unpackedFolder.tar.gz" -C "$unpackedFolder" --use-compress-program=pigz
            fi
            echo "Done."
          }
          export -f exportEnv
          
          bash -c 'exportEnv "filtering__cleanCoordinates" "channels: [conda-forge, r]
          dependencies: [r-terra, r-rjson, r-raster, r-dplyr, r-CoordinateCleaner, r-gdalcubes]
          name: filtering__cleanCoordinates
          "'
          
          bash -c 'exportEnv "SDM__selectBackground" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-dplyr, r-raster, r-CoordinateCleaner, r-stars,
            r-rstac, r-gdalcubes]
          name: SDM__selectBackground
          "'
          
          bash -c 'exportEnv "SDM__setupDataSdm" "channels: [conda-forge, r]
          dependencies: [r-gdalcubes, r-terra, r-rjson, r-raster, r-dplyr, r-ENMeval, r-devtools]
          name: SDM__setupDataSdm
          "'
          
          bash -c 'exportEnv "SDM__removeCollinearity" "channels: [conda-forge, r]
          dependencies: [r-terra, r-rjson, r-dplyr, r-gdalcubes]
          name: SDM__removeCollinearity
          "'
          
          bash -c 'exportEnv "rbase" ""'
          
          bash -c 'exportEnv "data__getGBIFObservations__getGBIFObservations" "channels: [conda-forge]
          dependencies: [pygbif, pandas, pyproj]
          name: data__getGBIFObservations__getGBIFObservations
          "'
          
          bash -c 'exportEnv "data__loadFromStac" "channels: [conda-forge, r]
          dependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,
            r-rcurl, r-rjson, r-sf, r-stars, r-terra]
          name: data__loadFromStac
          "'
          
          bash -c 'exportEnv "SDM__runewlgcp" "channels: [conda-forge, r]
          dependencies: [r-terra, r-rjson, r-raster, r-dplyr, r-gdalcubes, r-ENMeval, r-devtools,
            r-sf, r-FNN, r-stars]
          name: SDM__runewlgcp
          "'
          
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

  filtering>cleanCoordinates.yml@34:
    run: ../../tools/cleanCoordinates.cwl
    in:
      presence: data>getGBIFObservations>getGBIFObservations.yml@139/observations_file
      predictors: SDM>removeCollinearity.yml@97/rasters_selected
      tests: { default: [equal, zeros, duplicates, same_pixel, capitals, centroids, gbif, institutions] }
      env_threshold: { default: 0.8 }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/filtering__cleanCoordinates/34' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [n_presence, n_clean, clean_presence]


  SDM>selectBackground.yml@40:
    run: ../../tools/selectBackground.cwl
    in:
      presence: filtering>cleanCoordinates.yml@34/clean_presence
      extent: SDM>studyExtent.yml@104/study_extent
      method_background: SDM>selectBackground.yml@40|method_background
      n_background: SDM>selectBackground.yml@40|n_background
      predictors: SDM>removeCollinearity.yml@97/rasters_selected
      raster: data>GBIFHeatmapFromSTAC.yml@145/rasters
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__selectBackground/40' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [n_background, background]


  SDM>setupDataSdm.yml@44:
    run: ../../tools/setupDataSdm.cwl
    in:
      presence: filtering>cleanCoordinates.yml@34/clean_presence
      background: SDM>selectBackground.yml@40/background
      predictors: SDM>removeCollinearity.yml@97/rasters_selected
      partition_type: { default: bootstrap }
      runs_n: pipeline@46
      boot_proportion: { default: 0.7 }
      cv_partitions: { default: 5 }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__setupDataSdm/44' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [presence_background]


  SDM>removeCollinearity.yml@97:
    run: ../../tools/removeCollinearity.cwl
    in:
      rasters: data>loadFromStac.yml@140/rasters
      method: { default: vif.cor }
      method_cor_vif: { default: pearson }
      nb_sample: { default: 5000 }
      cutoff_cor: { default: 0.75 }
      cutoff_vif: { default: 8 }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__removeCollinearity/97' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_selected]


  SDM>studyExtent.yml@104:
    run: ../../tools/studyExtent.cwl
    in:
      presence: filtering>cleanCoordinates.yml@34/clean_presence
      bbox_crs: pipeline@149
      method: { default: bbox }
      width_buffer: { default: 0 }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__studyExtent/104' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [area_study_extent, study_extent]


  data>getGBIFObservations>getGBIFObservations.yml@139:
    run: ../../tools/getGBIFObservations.cwl
    in:
      taxa: pipeline@121
      bbox_crs: pipeline@149
      min_year: data>getGBIFObservations>getGBIFObservations.yml@139|min_year
      max_year: data>getGBIFObservations>getGBIFObservations.yml@139|max_year
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__getGBIFObservations/139' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [observations_file, total_records, gbif_doi]


  data>loadFromStac.yml@140:
    run: ../../tools/loadFromStac.cwl
    in:
      bbox_crs: pipeline@149
      stac_url: data>loadFromStac.yml@140|stac_url
      collections_items: data>loadFromStac.yml@140|collections_items
      t0: { default: null }
      t1: { default: null }
      temporal_res: { default: null }
      spatial_res: pipeline@128
      resampling: { default: average }
      aggregation: { default: first }
      study_area: data>loadFromStac.yml@140|study_area
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/140' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters]


  data>GBIFHeatmapFromSTAC.yml@145:
    run: ../../tools/GBIFHeatmapFromSTAC.cwl
    in:
      taxa: data>GBIFHeatmapFromSTAC.yml@145|taxa
      bbox_crs: pipeline@149
      spatial_res: pipeline@128
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__GBIFHeatmapFromSTAC/145' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters]


  SDM>runewlgcp.yml@151:
    run: ../../tools/runewlgcp.cwl
    in:
      presence_background: SDM>setupDataSdm.yml@44/presence_background
      predictors: SDM>removeCollinearity.yml@97/rasters_selected
      orientation_block: { default: lat_lon }
      crs: pipeline@149
      n_folds: pipeline@46
      spatial_res: pipeline@128
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__runewlgcp/151' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [sdm_pred, sdm_unc, sdm_ci, sdm_obs, sdm_bg, sdm_dmesh]


outputs:
  SDM>runewlgcp.yml@151|sdm_dmesh:
    type: File
    label: dmesh
    doc: dual mesh used by the sdm model
    outputSource: SDM>runewlgcp.yml@151/sdm_dmesh

  SDM>runewlgcp.yml@151|sdm_unc:
    type: File
    label: uncertainty
    doc: model uncertainty metrics
    outputSource: SDM>runewlgcp.yml@151/sdm_unc

  SDM>runewlgcp.yml@151|sdm_ci:
    type: File[]
    label: CI range
    doc: difference between the upper and the lower CI bound
    outputSource: SDM>runewlgcp.yml@151/sdm_ci

  SDM>runewlgcp.yml@151|sdm_bg:
    type: File
    label: background
    doc: background points used for the sdm model
    outputSource: SDM>runewlgcp.yml@151/sdm_bg

  data>getGBIFObservations>getGBIFObservations.yml@139|gbif_doi:
    type: string
    label: DOI of GBIF download
    doc: DOI of GBIF download. Used for citing downloaded data.
    outputSource: data>getGBIFObservations>getGBIFObservations.yml@139/gbif_doi

  SDM>runewlgcp.yml@151|sdm_obs:
    type: File
    label: observations
    doc: GBIF observations used for the sdm model
    outputSource: SDM>runewlgcp.yml@151/sdm_obs

  SDM>removeCollinearity.yml@97|rasters_selected:
    type: File[]
    label: Environmental predictors
    doc: Environmental layers used as predictors in species distribution modeling
    outputSource: SDM>removeCollinearity.yml@97/rasters_selected

  SDM>runewlgcp.yml@151|sdm_pred:
    type: File
    label: predictions
    doc: model predictions while trained on the whole dataset
    outputSource: SDM>runewlgcp.yml@151/sdm_pred

  pipeline@121|default_output:
    type: string[]
    label: Species name
    doc: Species for which distribution is being modeled
    outputSource: pipeline@121

  data>loadFromStac.yml@140|rasters:
    type: File[]
    label: Rasters
    doc: array of output raster paths
    outputSource: data>loadFromStac.yml@140/rasters

