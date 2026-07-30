cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Zonal statistics for STAC items in a region
doc:
  - "Description:
    This pipeline extracts zonal statistics for STAC catalog items in a country or subnational region of interest."
  - "Authors:
    Jory Griffith (Pipeline development, jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)"
  - "References:
    Daniel Baston (2023) null"


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement

inputs:
  #################
  # Script inputs #
  #################
  data>loadFromStac.yml@25|t0:
    type: string
    label: Start date (optional)
    doc: Start date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if extracting items by name.

  data>loadFromStac.yml@25|t1:
    type: string
    label: End date (optional)
    doc: End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if extracting items by name.

  data>loadFromStac.yml@25|aggregation:
    type:
      type: enum
      symbols:
        - first
        - min
        - max
        - mean
        - median
    label: Aggregation method
    doc: >
      Method used to aggregate items when layers combining over time.
      
      Will be ignored if not combining over time.
    default: first

  zonal_statistics>zonal_stats.yml@4|summary_statistic:
    type:
      type: enum[]
      symbols:
        - mean
        - median
        - sum
        - min
        - max
        - stdev
        - variance
        - mode
    label: Summary statistic
    doc: Summary statistic for layers
    default:
    - mean
    - variance

  data>loadFromStac.yml@25|stac_url:
    type: string
    label: STAC URL
    doc: URL of the STAC catalog.
    default: https://stac.geobon.org/

  data>loadFromStac.yml@25|collections_items:
    type: string[]
    label: STAC collection items
    doc: Vector of strings. To pull specific collection items, input the collection name followed by '|' followed by item id (e.g. "chelsa-clim|bio1"). To extract a whole collection, type the collection name only (e.g. "chelsa-clim"). To pull collection items by date, write the collection name and provide a start date, end date, and temporal resolution.
    default:
    - chelsa-clim|bio1
    - chelsa-clim|bio2

  data>loadFromStac.yml@25|temporal_res:
    type: string
    label: Temporal resolution (optional)
    doc: Temporal resolution to use when querying STAC items by date, in the format ("P", time interval, and time unit, e.g. "P1Y" is yearly, "P1M" is montly, and "P1D" is daily). Leave blank if not querying by date. If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below.

  data>load_polygons.yml@28|polygon_type:
    type:
      type: enum
      symbols:
        - Country or region
        - WDPA
        - EEZ
    label: Polygon type
    doc: Type of polygon to load. Country or region polygons, World database of Protected Areas (WDPA), Exclusive Economic Zones (EEZs), or a custom polygon of a bounding box.
    default: Country or region

  data>loadFromStac.yml@25|resampling:
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
    label: Resampling method
    doc: >
      Resampling method used when rescaling and/or reprojecting the raster layers. See [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) for description.
      
      Will be ignored if not resampling.
    default: near

  pipeline@27:
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

  data>loadFromStac.yml@25|spatial_res:
    type: float
    label: Spatial resolution (optional)
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
          
          bash -c 'exportEnv "zonal_statistics__zonal_stats" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-dplyr, r-sf, r-exactextractr, r-tidyr]
          name: zonal_statistics__zonal_stats
          "'
          
          bash -c 'exportEnv "data__loadFromStac" "channels: [conda-forge, r]
          dependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,
            r-rcurl, r-rjson, r-sf, r-stars, r-terra]
          name: data__loadFromStac
          "'
          
          bash -c 'exportEnv "data__load_polygons" "channels: [conda-forge]
          dependencies: [r-rjson, r-dbplyr=2.5.2, r-dplyr=1.2.1, r-duckdb=1.4.4, r-fs=2.1.0,
            r-arrow=24.0.0, r-nanoarrow=0.8.0, r-geoarrow=0.4.2, r-sf=1.1-0, r-stringi=1.8.7,
            r-stringr=1.6.0, r-tidyr=1.3.2, r-uuid=1.2_2, r-remotes=2.5.0]
          name: data__load_polygons
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

  zonal_statistics>zonal_stats.yml@4:
    run: ../tools/zonal_stats.cwl
    in:
      rasters: data>loadFromStac.yml@25/rasters
      bbox_crs: pipeline@27
      study_area_polygon: data>load_polygons.yml@28/polygon
      summary_statistic: zonal_statistics>zonal_stats.yml@4|summary_statistic
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/zonal_statistics__zonal_stats/4' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [zonal_stats]


  data>loadFromStac.yml@25:
    run: ../tools/loadFromStac.cwl
    in:
      bbox_crs: pipeline@27
      stac_url: data>loadFromStac.yml@25|stac_url
      collections_items: data>loadFromStac.yml@25|collections_items
      t0: data>loadFromStac.yml@25|t0
      t1: data>loadFromStac.yml@25|t1
      temporal_res: data>loadFromStac.yml@25|temporal_res
      spatial_res: data>loadFromStac.yml@25|spatial_res
      resampling: data>loadFromStac.yml@25|resampling
      aggregation: data>loadFromStac.yml@25|aggregation
      study_area: data>load_polygons.yml@28/polygon
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/25' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters]


  data>load_polygons.yml@28:
    run: ../tools/load_polygons.cwl
    in:
      polygon_type: data>load_polygons.yml@28|polygon_type
      country_region_bbox: pipeline@27
      buffer: { default: 0.0 }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/28' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon, bbox_crs]


outputs:
  zonal_statistics>zonal_stats.yml@4|zonal_stats:
    type: File
    label: Summary statistic
    doc: Summary statistic over the polygon
    outputSource: zonal_statistics>zonal_stats.yml@4/zonal_stats

  data>loadFromStac.yml@25|rasters:
    type: File[]
    label: Rasters
    doc: Output raster files in geotiff format.
    outputSource: data>loadFromStac.yml@25/rasters

