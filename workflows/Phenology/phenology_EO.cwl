cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Plant phenology index pipeline (Europe only)
doc:
  - |
    Description:
    ## Introduction
    Phenology is one of the species trait EBVs. It describes presence, absence, abundance or duration of seasonal activities of organisms. This pipeline uses the openEO python package to pull phenology layers from the copernicus data space ecosystem phenology layer. The raster has values for the Plant Phenology Index (PPI), which is a vegetation index that helps estimate vegetation health and photosyntehtic activity throughout the growing season. It is more directly related to plant phenology compared to other vegetation indices like NDVI, and does not saturate in high biomass conditions. It is computed with near infrared reflectance, which is strongly reflected by healthy vegetation. 
    You can read more about the phenology layers [here](https://land.copernicus.eu/en/dataset-catalog). The script pulls the yearly phenology layers using openEO and resamples them to the spatial resolution of choice, calculates summary statistics over a country or region of interest, and subtracts the rasters to look at change over time.
    ## Context
    This pipeline can be used to look at the Phenology EBV. It can also serve as inputs for subsequent pipelines,  such as species distribution models.
    ## Pipeline limitations 
    * Phenology layers are only available for countries in Europe.
    * The pipeline uses a very fine resolution, so it takes a long time to run on for large areas.
    ## Before you start
    The pipeline requires an API key for the Copernicus Data Space Ecosystem. To acquire an API key, visit the CDSE [website](https://dataspace.copernicus.eu/analyse/openeo).
  - "Lifecycle tag: In development."
  - |
    Authors:
    Jory Griffith (Pipeline Development, jory.griffith@gmail.com, https://orcid.org/0000-0001-6020-6690)
    Laetitia Tremblay (Pipeline testing, debugging, and documentation, laetitia.tremblay@mcgill.ca, https://www.linkedin.com/in/laetitia-tremblay-b0619b273/)
  - "External link: https://land.copernicus.eu/en/products/vegetation"


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
  data>load_polygons.yml@69|polygon_type:
    type:
      type: enum
      symbols:
        - Country or region
        - Polygon of bounding box
    label: Polygon type
    doc: Type of polygon to load. Country or region polygons, World database of Protected Areas (WDPA), Exclusive Economic Zones (EEZs), or a custom polygon of a bounding box.
    default: Country or region

  pipeline@45:
    type: string?
    label: End year
    doc: End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if using all available dates.
    default: '2024'

  phenology>summarise_phenology.yml@37|spatial_resolution:
    type: float?
    label: Spatial resolution
    doc: >
      Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long).
      Leave blank to use the original spatial resolution of the layers. If left blank, CRS must be EPSG:4326.
    default: 0

  pipeline@44:
    type: string?
    label: Start year
    doc: Start date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if using all available dates.
    default: '2017'

  phenology>summarise_phenology.yml@37|bands:
    type:
      type: enum[]
      symbols:
        - SOSD
        - EOSD
        - SOSV
        - EOSV
        - MAXD
        - MAXV
        - MINV
        - AMPL
        - LENGTH
        - LSLOPE
        - RSLOPE
        - SPROD
        - TPROD
        - QFLAG
    label: Bands
    doc: >
      Bands of interest for the calculations. 
      - SOSD (Start of season date) - date when the vegetation growing season starts, when the PPI value reaches 25% of the season amplitude during the green-up period.
      - EOSD (End of season date) - the date when the vegetation growing season ends in the time profile of the PPI. Occurs when the PPI value reaches 15% of the season amplitude during the green-down period.
      - SOSV (Start of season value) - the value of the PPI at the start of the vegetation growing season
      - EOSV (End of season value) - the value of the PPI at the end of the vegetation growing season
      - MAXV (Season maximum value) - the maximum (peak) value that the PPI reaches during the vegetation growing season
      - MAXD (Season maximum date) - date in the vegetation growing season where the maximum PPI is reached
      - MINV (Season minimum value) - average PPI of minima of left and right sides of each season
      - AMPL (Season amplitude) - difference between the maximum and minimum PPI values reached during the season
      - LENGTH (Season length) - number of days between the start and end dates of the vegetation growing season
      - LSLOPE (Slope of the green-up period) - the rate of change in the values of PPI at the day when the vegetation growing season starts
      - RSLOPE (Slope of the green-down period) - the rate of change in the values of PPO at the date when the vegetation growing season ends
      - SPROD (Seasonal productivity) - growing season integral computed as sum of all daily PPI values between the dates of the season start and end, minus their base level.
      - TPROD (Total productivity) - the growing season integral computed as sum of all daily PPI values between the dates of the season start and end
      - QFLAG (Quality flag) - quality indicator assisting users with the screening of clouds, shadows from clouds and topography, other dark areas, snow and water surfaces in their analysis of the PPI dataset
    default:
    - LENGTH
    - AMPL

  phenology>summarise_phenology.yml@37|aggregate_function:
    type:
      type: enum
      symbols:
        - mean
        - min
        - max
    label: Aggregate function
    doc: >
      Method used to aggregate items when layers combining over time.
      Will be ignored if not aggregating.
    default: mean

  phenology>summarise_phenology.yml@37|season:
    type:
      type: enum
      symbols:
        - SEASON1
        - SEASON2
    label: Season of interest
    doc: >
      Season for which to run phenology analyses. Season 1 is the first growing season (spring and early summer) and season 2 is the second growing season (late summer and fall).
    default: SEASON1

  pipeline@68:
    label: Bounding box and CRS
    doc: Select a country/region and a CRS to obtain the associated bounding box.
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
          
          bash -c 'getPackedEnv "phenology__summarise_phenology" "channels: [conda-forge]
          dependencies: [openeo, pandas, geopandas, shapely]
          name: phenology__summarise_phenology
          "'
          
          bash -c 'getPackedEnv "data__load_polygons" "channels: [conda-forge]
          dependencies: [r-rjson, r-dbplyr=2.5.2, r-dplyr=1.2.1, r-duckdb=1.4.4, r-fs=2.1.0,
            r-arrow=24.0.0, r-nanoarrow=0.8.0, r-geoarrow=0.4.2, r-sf=1.1-0, r-stringi=1.8.7,
            r-stringr=1.6.0, r-tidyr=1.3.2, r-uuid=1.2_2, r-remotes=2.5.0]
          name: data__load_polygons
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

  phenology>summarise_phenology.yml@37:
    run: ../../tools/phenology/summarise_phenology.cwl
    in:
      bbox_crs: pipeline@68
      study_area_polygon: data>load_polygons.yml@69/polygon
      start_year: pipeline@44
      end_year: pipeline@45
      season: phenology>summarise_phenology.yml@37|season
      bands: phenology>summarise_phenology.yml@37|bands
      aggregate_function: phenology>summarise_phenology.yml@37|aggregate_function
      spatial_resolution: phenology>summarise_phenology.yml@37|spatial_resolution
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/phenology__summarise_phenology' } : null)"
      envFolderWritable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/phenology__summarise_phenology/37' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters, timeseries]


  phenology>phenology_difference.yml@48:
    run: ../../tools/phenology/phenology_difference.cwl
    in:
      rasters: phenology>summarise_phenology.yml@37/rasters
      start_year: pipeline@44
      end_year: pipeline@45
      timeseries: phenology>summarise_phenology.yml@37/timeseries
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/phenology__phenology_difference/48' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [phenology_change, phenology_change_plot]


  data>load_polygons.yml@69:
    run: ../../tools/data/load_polygons.cwl
    in:
      polygon_type: data>load_polygons.yml@69|polygon_type
      country_region_bbox: pipeline@68
      buffer: { default: 0.0 }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)"
      envFolderWritable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/69' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon, bbox_crs]


outputs:
  data>load_polygons.yml@69|polygon:
    type: File
    label: Polygon
    doc: Polygons of the country, WDPA, EEZs for the country or region of interest
    outputSource: data>load_polygons.yml@69/polygon

  phenology>phenology_difference.yml@48|phenology_change_plot:
    type: File
    label: Plot of phenology change
    doc: Plot of the summarised phenology values over time for the bands of interest
    outputSource: phenology>phenology_difference.yml@48/phenology_change_plot

  phenology>summarise_phenology.yml@37|rasters:
    type: File[]
    label: Phenology rasters
    doc: >
      Rasters of phenology layers, with one raster per year in the input time range. Will either be the raw raster layers or resampled to the spatial resolution and CRS input by the user.
    outputSource: phenology>summarise_phenology.yml@37/rasters

  phenology>phenology_difference.yml@48|phenology_change:
    type: File[]
    label: Change in phenology metrics
    doc: >
      Raster plot of change in phenology from the start year to the end year. The end year is subtracted from the start year, so larger values indicate a greater decrease in the given value over time.
    outputSource: phenology>phenology_difference.yml@48/phenology_change

  phenology>summarise_phenology.yml@37|timeseries:
    type: File
    label: Zonal statistics
    doc: Summarised values over the polygon of interest (mean, minimum, or maximum) for each year for each band of interest
    outputSource: phenology>summarise_phenology.yml@37/timeseries

