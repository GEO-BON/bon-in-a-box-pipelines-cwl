cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Species distribution modeling with Boosted Regression Trees (BRTs)
doc:
  - |
    Description:
    This pipeline generates predictions for a species distribution model using the BRTs.
  - "Lifecycle tag: In review."
  - |
    Authors:
    Michael D. Catchen (Pipeline development, https://orcid.org/0000-0002-6506-6487)
  - "External link: https://github.com/GEO-BON/biab-2.0/blob/main/scripts/SDM/BRT"


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
  pipeline@121:
    type: string[]?
    label: Species
    doc: Name of species
    default:
    - Acer saccharum

  pipeline@174:
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

  pipeline@137:
    type: string[]?
    label: Environmental Predictors
    doc: Vector of strings, collection name followed by '|' followed by item id. View GEO BON STAC catalog items [here](https://stac.geobon.org/viewer/). The collection name and item name can be found in the URL (e.g. for "https://stac.geobon.org/viewer/chelsa-clim/bio1" the collection name is chelsa-clim and the item id is bio1). 
    default:
    - chelsa-clim|bio1
    - chelsa-clim|bio3
    - chelsa-clim|bio4
    - chelsa-clim|bio12
    - chelsa-clim|bio15

  data>getGBIFObservations>getGBIFObservations.yml@159|min_year:
    type: int?
    label: minimum year
    doc: Min year observations wanted
    default: 2010

  data>getGBIFObservations>getGBIFObservations.yml@159|max_year:
    type: int?
    label: maximum year
    doc: Max year observations wanted
    default: 2024

  pipeline@128:
    type: float?
    label: Spatial Resolution
    doc: >
      Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). 
      
      If this is left blank it will use the native resolution of the rasters. 
      
      If the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled with the resampling method "near".
    default: 1000

  pipeline@152:
    type: float?
    label: Pseudoabsence Buffer
    doc: The minimum distance a PA is allowed to be from a presence in kilometers
    default: 10

  pipeline@153:
    type: int?
    label: Max Candidate Pseudoabsences
    doc: The maximum number of candidate pseudoabsences to consider. This speeds up PA generation on large rasters.
    default: 100000

  pipeline@154:
    type: float?
    label: Pseudoabsence proportion
    doc: The number of PAs, given by the proportion of the total occurrences to use.
    default: 2.4

  pipeline@167:
    type: File?
    label: Study area
    doc: Polygon of study area used to crop output layers

  data>loadFromStac.yml@161|t0:
    type: string?
    label: Start date
    doc: Start date for time series layers in STAC catalog. Can be in the format YYYY or YYYY-MM-DD. For example, ESA landcover can be extracted by specifying the item name or specifying the whole collection and the start and end date here. Leave blank if extracting items by name.

  data>loadFromStac.yml@161|t1:
    type: string?
    label: End date
    doc: End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. For example, ESA landcover can be extracted by specifying the item name or specifying the whole collection and the start and end date here. Leave blank if extracting items by name.

  data>loadFromStac.yml@161|temporal_res:
    type: string?
    label: Temporal resolution
    doc: Temporal resolution to use when querying STAC items by date, in the format ("P", time interval, and time unit, e.g. "P1Y" is yearly, "P1M" is montly, and "P1D" is daily). Leave blank if not querying by date. If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below.



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

          bash -c 'getPackedEnv "filtering__cleanCoordinates" "channels: [conda-forge, r]
          dependencies: [r-terra, r-rjson, r-raster, r-dplyr, r-CoordinateCleaner, r-gdalcubes]
          name: filtering__cleanCoordinates
          "'
          
          bash -c 'getPackedEnv "data__getGBIFObservations__getGBIFObservations" "channels: [conda-forge]
          dependencies: [pygbif, pandas, pyproj]
          name: data__getGBIFObservations__getGBIFObservations
          "'
          
          bash -c 'getPackedEnv "data__loadFromStac" "channels: [conda-forge, r]
          dependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,
            r-rcurl, r-rjson, r-sf, r-stars, r-terra]
          name: data__loadFromStac
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

  filtering>cleanCoordinates.yml@34:
    run: ../../tools/filtering/cleanCoordinates.cwl
    in:
      presence: data>getGBIFObservations>getGBIFObservations.yml@159/observations_file_out
      predictors: data>loadFromStac.yml@160/rasters_out
      tests: { default: [equal, zeros, duplicates, same_pixel, capitals, centroids, gbif, institutions] }
      env_threshold: { default: 0.8 }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/filtering__cleanCoordinates' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/filtering__cleanCoordinates/34' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [n_presence_out, n_clean_out, clean_presence_out]


  SDM>BRT>fitBRT.yml@132:
    run: ../../tools/SDM/BRT/fitBRT.cwl
    in:
      occurrence: filtering>cleanCoordinates.yml@34/clean_presence_out
      predictors: data>loadFromStac.yml@160/rasters_out
      bbox_crs: pipeline@174
      water_mask: data>loadFromStac.yml@161/rasters_out
      max_candidate_pseudoabsences: pipeline@153
      pseudoabsence_buffer: pipeline@152
      pa_proportion: pipeline@154
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__BRT__fitBRT/132' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [predicted_sdm_out, sdm_uncertainty_out, fit_stats_out, range_out, pseudoabsences_out, env_corners_out, tuning_out]


  data>getGBIFObservations>getGBIFObservations.yml@159:
    run: ../../tools/data/getGBIFObservations/getGBIFObservations.cwl
    in:
      taxa: pipeline@121
      bbox_crs: pipeline@174
      min_year: data>getGBIFObservations>getGBIFObservations.yml@159|min_year
      max_year: data>getGBIFObservations>getGBIFObservations.yml@159|max_year
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__getGBIFObservations' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__getGBIFObservations/159' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [observations_file_out, total_records_out, gbif_doi_out]


  data>loadFromStac.yml@160:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@174
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: pipeline@137
      t0: { default: null }
      t1: { default: null }
      temporal_res: { default: null }
      spatial_res: pipeline@128
      resampling: { default: near }
      aggregation: { default: first }
      study_area: pipeline@167
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/160' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_out]


  data>loadFromStac.yml@161:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@174
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: { default: [esacci-lc|esacci-lc-2020] }
      t0: data>loadFromStac.yml@161|t0
      t1: data>loadFromStac.yml@161|t1
      temporal_res: data>loadFromStac.yml@161|temporal_res
      spatial_res: pipeline@128
      resampling: { default: near }
      aggregation: { default: first }
      study_area: pipeline@167
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/161' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_out]


outputs:
  pipeline@121|default_output_out:
    type: string[]
    label: Species
    doc: Name of species
    outputSource: pipeline@121

  filtering>cleanCoordinates.yml@34|clean_presence_out:
    type: File
    label: Presences
    doc: Occurrences from GBIF after cleaning
    outputSource: filtering>cleanCoordinates.yml@34/clean_presence_out

  SDM>BRT>fitBRT.yml@132|pseudoabsences_out:
    type: File
    label: Pseudoabsences
    doc: pseudoabsence coordinates
    outputSource: SDM>BRT>fitBRT.yml@132/pseudoabsences_out

  SDM>BRT>fitBRT.yml@132|env_corners_out:
    type: File
    label: Environment Space
    doc: Diagnostic plot of the location of presences (blue) and pseudoabsences (red) in environment space for up to the first 5 predictors.
    outputSource: SDM>BRT>fitBRT.yml@132/env_corners_out

  SDM>BRT>fitBRT.yml@132|tuning_out:
    type: File
    label: Tuning Curve
    doc: Describes how the Matthew's Correlation Coefficient (MCC) changes as the threshold value changes from 0 to 1.
    outputSource: SDM>BRT>fitBRT.yml@132/tuning_out

  SDM>BRT>fitBRT.yml@132|fit_stats_out:
    type: File
    label: Fit Statistics
    doc: JSON of BRT fit statistics and optimal threshold value.
    outputSource: SDM>BRT>fitBRT.yml@132/fit_stats_out

  SDM>BRT>fitBRT.yml@132|predicted_sdm_out:
    type: File
    label: Predicted SDM
    doc: Map of occurrence score between 0 and 1.
    outputSource: SDM>BRT>fitBRT.yml@132/predicted_sdm_out

  SDM>BRT>fitBRT.yml@132|range_out:
    type: File
    label: Range
    doc: Range map thresholded at the optimal value.
    outputSource: SDM>BRT>fitBRT.yml@132/range_out

  SDM>BRT>fitBRT.yml@132|sdm_uncertainty_out:
    type: File
    label: SDM Uncertainty
    doc: Map of the BRT's relative uncertainty for each location.
    outputSource: SDM>BRT>fitBRT.yml@132/sdm_uncertainty_out

  data>getGBIFObservations>getGBIFObservations.yml@159|gbif_doi_out:
    type: string
    label: DOI of GBIF download
    doc: DOI of GBIF download. Used for citing downloaded data.
    outputSource: data>getGBIFObservations>getGBIFObservations.yml@159/gbif_doi_out

  data>loadFromStac.yml@160|rasters_out:
    type: File[]
    label: Rasters
    doc: array of output raster paths
    outputSource: data>loadFromStac.yml@160/rasters_out

  data>loadFromStac.yml@161|rasters_out:
    type: File[]
    label: Rasters
    doc: Output raster files in geotiff format.
    outputSource: data>loadFromStac.yml@161/rasters_out

