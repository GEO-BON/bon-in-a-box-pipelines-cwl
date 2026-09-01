cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Biodiversity Habitat Index (BHI)
doc:
  - |
    Description:
    ## Introduction
    CSIRO Biodiversity Habitat Index (BHI v2) is a global 30 arc-second product for 2000,2005,2010,2015 and 2020. BHI estimates the level of species diversity expected to be retained within any given spatial reporting unit (e.g., a country, a broad ecosystem type, or the entire planet) as a function of the unit’s area, connectivity and integrity of natural ecosystems across it. Results for the indicator can either be expressed as 1) the ‘effective proportion of habitat’ remaining within the unit – adjusting for the effects of the condition and functional connectivity of habitat, and of spatial variation in the species composition of ecological communities (beta diversity); or 2) the effective proportion of habitat that can be translated, through standard species-area analysis, into a prediction of the proportion of species expected to persist (i.e. avoid extinction) over the long term.
    
    This pipeline calculates a weighted geometric mean of the BHI indicator over a region of interest.  The code to calculate the weighted mean was adapted from the "Calculating weighted geometric means of  CSIRO BILBI indicator" script on the  [CSIRO data access portal](https://doi.org/10.25919/tt2t-h452)
    ## Uses 
    The BHI is used to monitor and report past-to-present trends in the expected persistence of species diversity by repeatedly recalculating the indicator using best-available mapping of ecosystem condition or integrity observed at multiple points in time, e.g., for different years. A wide variety of data sources can be used for this purpose, spanning spatial scales from global to subnational, and including data assembled by countries for deriving ecosystem condition accounts under the UN SEEA Ecosystem Accounting framework. The BHI can also serve as a leading indicator for assessing the contribution that proposed or implemented area-based actions are expected to make towards enhancing the present capacity of ecosystems to retain species diversity, thereby providing a foundation for strategic prioritisation of such actions by countries.
    ## Pipeline limitations
    - BHI is a modeled layer, therefore there are greater uncertainties in areas with less data.  Interpret the results with caution.
  - |
    Authors:
    Jory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)
  - |
    References:
    Harwood et al. 2022
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
  data>load_polygons.yml@24|polygon_type:
    type:
      type: enum
      symbols:
        - Country or region
        - Polygon of bounding box
    label: Polygon type
    doc: Type of polygon to load. Country or region polygons, World database of Protected Areas (WDPA), Exclusive Economic Zones (EEZs), or a custom polygon of a bounding box.
    default: Country or region

  pipeline@23:
    label: Bounding box and CRS
    doc: Select a country/region and a CRS to obtain the associated bounding box. You may also draw/input a custom bounding box along with a CRS.
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

  data>loadFromStac.yml@1|t0:
    type: string?
    label: Start date (optional)
    doc: Start date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if using all available dates.

  data>loadFromStac.yml@1|t1:
    type: string?
    label: End date (optional)
    doc: End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if using all available dates.

  data>loadFromStac.yml@1|temporal_res:
    type: string?
    label: Temporal resolution (optional)
    doc: Temporal resolution to use when querying STAC items by date, in the format ("P", time interval, and time unit, e.g. "P1Y" is yearly, "P1M" is monthly, and "P1D" is daily). Leave blank if not querying by date. If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below.

  pipeline@19:
    type: float?
    label: Spatial resolution (optional)
    doc: >
      Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). 
      
      If this is left blank it will use the native resolution of the rasters. 
      
      If the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled with the resampling method chosen below.
    default: 0.008833

  pipeline@18:
    type:
      type: enum
      symbols:
        - near
        - bilinear
        - average
        - mode
        - cubic
        - cubicspline
        - lanczos
        - rms
        - min
        - max
        - sum
        - med
        - q1
        - q3
    label: Resampling method (optional)
    doc: >
      Resampling method used when rescaling and/or reprojecting the raster layers. See [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) for description.
      
      Will be ignored if not resampling.
    default: near

  pipeline@20:
    type:
      type: enum
      symbols:
        - first
        - min
        - max
        - mean
        - median
    label: Aggregation method (optional)
    doc: >
      Method used to aggregate items when layers combining over time.
      
      Will be ignored if not aggregating.
    default: first



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

          bash -c 'getPackedEnv "bilbi_indicators__bilbi_weighted_mean" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-tidyverse]
          name: bilbi_indicators__bilbi_weighted_mean
          "'
          
          bash -c 'getPackedEnv "data__loadFromStac" "channels: [conda-forge, r]
          dependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,
            r-rcurl, r-rjson, r-sf, r-stars, r-terra]
          name: data__loadFromStac
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

  bilbi_indicators>bilbi_weighted_mean.yml@0:
    run: ../../tools/bilbi_indicators/bilbi_weighted_mean.cwl
    in:
      bilbi_indicator: data>loadFromStac.yml@1/rasters_out
      bilbi_denominator: data>loadFromStac.yml@2/rasters_out
      study_area: data>load_polygons.yml@24/polygon_out
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/bilbi_indicators__bilbi_weighted_mean' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/bilbi_indicators__bilbi_weighted_mean/0' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [summarised_values_out, time_series_plot_out]


  data>loadFromStac.yml@1:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@23
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: { default: [csiro_bhi] }
      t0: data>loadFromStac.yml@1|t0
      t1: data>loadFromStac.yml@1|t1
      temporal_res: data>loadFromStac.yml@1|temporal_res
      spatial_res: pipeline@19
      resampling: pipeline@18
      aggregation: pipeline@20
      study_area: data>load_polygons.yml@24/polygon_out
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/1' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_out]


  data>loadFromStac.yml@2:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@23
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: { default: [csiro_denominator] }
      t0: { default: null }
      t1: { default: null }
      temporal_res: { default: null }
      spatial_res: pipeline@19
      resampling: pipeline@18
      aggregation: pipeline@20
      study_area: data>load_polygons.yml@24/polygon_out
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/2' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_out]


  data>load_polygons.yml@24:
    run: ../../tools/data/load_polygons.cwl
    in:
      polygon_type: data>load_polygons.yml@24|polygon_type
      country_region_bbox: pipeline@23
      buffer: { default: 0.0 }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/24' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon_out, bbox_crs_out]


outputs:
  data>loadFromStac.yml@1|rasters_out:
    type: File[]
    label: Raster indicator layers for each year
    doc: Output raster files in geotiff format.
    outputSource: data>loadFromStac.yml@1/rasters_out

  bilbi_indicators>bilbi_weighted_mean.yml@0|summarised_values_out:
    type: File
    label: BHI summary
    doc: >
      Yearly weighted geometric mean of BHI in the study area polygon.
      
      
      A higher value (closer to 1) indicates that a large proportion of the habitat remains in good condition and is well-connected, leading to a high expectation of species persistence. A lower value indicates that a significant proportion of the original habitat has been lost, degraded, or fragmented, which puts biodiversity at risk.
    outputSource: bilbi_indicators>bilbi_weighted_mean.yml@0/summarised_values_out

  bilbi_indicators>bilbi_weighted_mean.yml@0|time_series_plot_out:
    type: File
    label: Time series plot
    doc: Plot of the geometric mean of the indicator over time in the study area of interest
    outputSource: bilbi_indicators>bilbi_weighted_mean.yml@0/time_series_plot_out

  data>load_polygons.yml@24|polygon_out:
    type: File
    label: Polygon
    doc: Polygons of the country, WDPA, EEZs for the country or region of interest
    outputSource: data>load_polygons.yml@24/polygon_out

