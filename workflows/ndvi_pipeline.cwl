cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Normalized Difference Vegetation Index
doc:
  - |
    Description:
    ## Introduction
    This pipeline calculates the Normalized Difference Vegetation Index (NDVI) using OpenEO  Copernicus Data Space Ecosystem. NDVI measures the "greenness" of vegetation, with higher  values indicating dense vegatation and low values indicating barren areas with rock, snow, sand, or exposed soils.
    
    The red and infrared bands from Sentinel 2 L2A are used to calcuate NDVI. The pipeline  summarises these values over the time period of interest with the specified summary statistic. The NDVi layers are masked with the SCL dilation mask avoid erroneous values by taking out pixels covered by clouds.
    - Learn more about Sentinel 2 [here](https://dataspace.copernicus.eu/data-collections/copernicus-sentinel-data/sentinel-2)
    - Learn more about calculating NDVI with openEO [here](https://openeo.org/documentation/1.0/cookbook/#example-1-ndvi)
    ## Before you start
    The pipeline requires an API key for the Copernicus Data Space Ecosystem. To acquire an API key, visit the CDSE [website](https://dataspace.copernicus.eu/analyse/openeo).
    
    The pipeline may take significant time to pull and summarise data,  especially at fine spatial resolutions for large areas.
  - "Lifecycle tag: subpipeline."
  - |
    Authors:
    Guillaume Larocque (Pipeline development, guillaume.larocque@mcgill.ca, https://orcid.org/0000-0002-5967-9156)
    Jory Griffith (Pipeline development, jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)


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
  pipeline@210:
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

  data>load_polygons.yml@211|polygon_type:
    type:
      type: enum
      symbols:
        - Country or region
        - Polygon of bounding box
    label: Polygon type
    doc: >
      Type of polygon to load. 
      
      - `Country or region` loads a polygon of the selected country or region.
      - `Polygon of bounding box` loads a polygon of the bounding box associated with the selected country or region, or the drawn bounding box.
    default: Country or region

  NDVI>calculateNDVI.yml@199|start_date:
    type: string?
    label: Start date
    doc: Start date for summarizing vegetation index
    default: '2024-01-01'

  NDVI>calculateNDVI.yml@199|end_date:
    type: string?
    label: End date
    doc: End date for summarizing vegetation index
    default: '2024-01-31'

  NDVI>calculateNDVI.yml@199|spatial_resolution:
    type: float?
    label: Spatial resolution
    doc: >
      Spatial resolution of the raster for plotting, leave blank to have the original spatial resolution of the layer (10m x 10m). If using a projected CRS, the resolution should be in meters. If using an unprojected CRS (e.g. EPSG:4326), this must be in degrees (0.008 degrees is ~1km at the equator).
      
      Leave blank to have the original spatial resolution of the layer (10m x 10m).
    default: 0.008

  NDVI>calculateNDVI.yml@199|summary_statistic:
    type:
      type: enum
      symbols:
        - mean
        - median
        - max
        - min
    label: Summary statistic
    doc: Statistic to summarize layers over time for summarised raster layer and space for plot of ndvi means over time
    default: mean



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory?
    doc: Optional folder for conda-pack environments, allowing reuse between runs.
      If omitted, environments are prepared in a CWL-managed temporary directory
      and shared between steps for this run only.

  runFolder:
    type: Directory?
    doc:
      Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script.
      If left blank, a temporary folder will be used and discarded after the run.

  environment:
    type: string?
    doc:
      Optional. URL (http/https) or file:// URI pointing to a BON in a Box runner.env
      file, necessary for scripts requiring credentials. If not provided, an empty one will be used.
      Relative paths are not supported.

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
  prepareRunnerEnv:
    doc:
      Copy or download environment file (runner.env) into a CWL output.
      This step is a patch to go around issue https://github.com/common-workflow-language/cwltool/issues/1842.
    when: $(inputs.environment != null)
    in:
      environment: environment
    out: [ environmentFile ]
    run:
      class: CommandLineTool
      requirements:
        NetworkAccess:
          networkAccess: true
        InlineJavascriptRequirement: { }
        EnvVarRequirement:
          envDef:
            RUNNER_ENV_URI: $(inputs.environment)
      baseCommand: [ sh, -c ]
      arguments:
        - |
          echo "Preparing runner.env..."

          case "$RUNNER_ENV_URI" in
            http://*|https://*|file://*)
              if ! curl -fsSL "$RUNNER_ENV_URI" -o runner.env; then
                echo "ERROR: failed to download runner.env from $RUNNER_ENV_URI" >&2
                exit 1
              fi

              if ! . ./runner.env; then
                echo "ERROR: failed to source runner.env" >&2
                exit 1
              fi
              ;;
            *)
              echo "ERROR: environment file input, BON in a Box's "runner.env", was not provided as an URI." >&2
              echo "Please use the format file:// or https://" >&2
              exit 1
              ;;
          esac
      inputs:
        environment:
          type: string
      outputs:
        environmentFile:
          type: File?
          outputBinding:
            glob: runner.env


  # This step prepares the environments for all the following steps
  preparePackedEnvs:
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
                {
                  entry: inputs.envFolderWrite || { "class": "Directory", "listing": [] },
                  entryname: "packed-envs",
                  writable: true
                },
                {
                  entry: { "class": "Directory", "basename": "conda-env-yml", "listing": [] },
                  entryname: "/conda-env-yml",
                  writable: true
                }
              ].concat(
                inputs.runFolderWrite
                  ? [{ entry: inputs.runFolderWrite, writable: true }]
                  : []
              );
            }
        DockerRequirement:
          dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-5f300f2
        EnvVarRequirement:
          envDef:
            CONDA_PKGS_DIRS: /conda-env-yml/pkgs
            CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
            SCRIPT_STUBS_LOCATION: /script-stubs
            OUTPUT_LOCATION: "$(inputs.runFolderWrite ? inputs.runFolderWrite.path : runtime.outdir)"
            PACKED_ENVS_LOCATION: "$(inputs.envFolderWrite ? inputs.envFolderWrite.path : runtime.outdir + '/packed-envs')"
            CONDA_PACK_URL: $(inputs.condaPackURL)
      baseCommand: [bash, -c]
      arguments:
        - |
          echo "Exporting all environments"
          mkdir -p "$OUTPUT_LOCATION" "$CONDA_PKGS_DIRS" /conda-env-yml/envs || exit 1

          function getPackedEnv {
            condaEnvName=$1
            condaEnvYml=$2
            # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context
            dedicatedEnvFolder="$PACKED_ENVS_LOCATION/$condaEnvName"
            mkdir -p "$dedicatedEnvFolder" || return 1

            echo "Exporting $condaEnvName..."
            source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh "$OUTPUT_LOCATION" "$condaEnvName" \
              "$condaEnvYml" "$dedicatedEnvFolder" "$CONDA_PACK_URL" --noActivate || return 1
            source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh "$condaEnvName" "$dedicatedEnvFolder" || return 1
            echo "Done."
          }
          export -f getPackedEnv

          bash -c 'getPackedEnv "NDVI__calculateNDVI" "channels: [conda-forge]
          dependencies: [openeo, pandas, geopandas, pyproj, shapely, pandas, matplotlib]
          name: NDVI__calculateNDVI
          "' || exit 1
          
          bash -c 'getPackedEnv "data__load_polygons" "channels: [conda-forge]
          dependencies: [r-rjson, r-dbplyr=2.5.2, r-dplyr=1.2.1, r-duckdb=1.4.4, r-fs=2.1.0,
            r-arrow=24.0.0, r-nanoarrow=0.8.0, r-geoarrow=0.4.2, r-sf=1.1-0, r-stringi=1.8.7,
            r-stringr=1.6.0, r-tidyr=1.3.2, r-uuid=1.2_2, r-remotes=2.5.0]
          name: data__load_polygons
          "' || exit 1
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
            glob: packed-envs
    in:
      envFolderWrite: envFolder
      runFolder:
        source: runFolder
        valueFrom: "$({ class: 'Directory', location: (self ? self.location : '/tmp/cwl' ) + '/preparePackedEnvs' })"
      condaPackURL: condaPackURL
    out: [envFolder]

  NDVI>calculateNDVI.yml@199:
    run: ../tools/NDVI/calculateNDVI.cwl
    in:
      bbox_crs: pipeline@210
      study_area_polygon: data>load_polygons.yml@211/polygon_out
      start_date: NDVI>calculateNDVI.yml@199|start_date
      end_date: NDVI>calculateNDVI.yml@199|end_date
      spatial_resolution: NDVI>calculateNDVI.yml@199|spatial_resolution
      summary_statistic: NDVI>calculateNDVI.yml@199|summary_statistic
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/NDVI__calculateNDVI' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/NDVI__calculateNDVI/199' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_out, timeseries_out, timeseries_plot_out]


  data>load_polygons.yml@211:
    run: ../tools/data/load_polygons.cwl
    in:
      polygon_type: data>load_polygons.yml@211|polygon_type
      country_region_bbox: pipeline@210
      buffer: { default: 0.0 }
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/211' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon_out, bbox_crs_out]


outputs:
  NDVI>calculateNDVI.yml@199|timeseries_out:
    type: File
    label: Time series of NDVI
    doc: Time series of NDVI values for every date where there is data in the specified time period.
    outputSource: NDVI>calculateNDVI.yml@199/timeseries_out

  NDVI>calculateNDVI.yml@199|timeseries_plot_out:
    type: File
    label: NDVI time series plot
    doc: Plot of NDVI values over time
    outputSource: NDVI>calculateNDVI.yml@199/timeseries_plot_out

  NDVI>calculateNDVI.yml@199|rasters_out:
    type: File[]
    label: Vegetation index rasters
    doc: >
      Raster of the NDVI values summarised by the input statistic (mean, max, min, median) for each pixel within the time span choosen. If multiple indices were chosen, each band corresponds to a different vegetation index
    outputSource: NDVI>calculateNDVI.yml@199/rasters_out

  data>load_polygons.yml@211|polygon_out:
    type: File
    label: Polygon
    doc: Polygons of the country, WDPA, EEZs for the country or region of interest
    outputSource: data>load_polygons.yml@211/polygon_out

