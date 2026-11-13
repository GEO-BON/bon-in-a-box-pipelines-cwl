cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Site optimization sampling
doc:
  - |
    Description:
    ## Introduction
    
    Biodiversity monitoring programmes may need to expand their sampling network or revisit sites that are no longer regularly monitored. Choosing additional sites can help improve coverage of environmental conditions and geographic areas that are poorly represented by the current network.
    
    This pipeline uses a stepwise p-median optimization procedure as described in Medina et al., 2013.  It is implemented in the [SURDES package](https://rdrr.io/rforge/SURDES/man/SURDES-package.html) to select additional sites from a user-provided candidate list. Selection considers environmental differences and geodesic distances between site coordinates in metres, with the aim of complementing sites already included in the monitoring network.
    
    ## Uses
    
    Use this pipeline to prioritize demand points when expanding or rotating a monitoring network. Demand points may include historical sampling locations or proposed new sites.
    
    The input list must identify two groups:
    
    - **Current sites (`vini = 1`):** Sites already included in the monitoring network.
    - **Demand points (`vini = 0`):** Sites available for additional sampling.
    
    Together, these groups define the set of sites considered in the analysis. The pipeline extracts environmental values at their locations, calculates distance matrices, and selects additional sites through successive optimization steps.
    
    The results include site-selection values, a map, and a curve showing how the remaining uncovered variability changes as sites are added. These outputs support decisions about which demand points to include and how many additional sites to sample.
    
    ## Limitations
    
    - All sites need valid environmental data. Locations outside raster coverage or within cells containing missing values may prevent the analysis from completing.
    - Computation time increases with the number of sites and optimization iterations. Start with a small run to assess performance.
    - The uncovered-variability output is a measure derived from the optimization’s distance matrix. It should not be interpreted as a percentage of biodiversity represented.
    
    ## Before you start
    
    Prepare a CSV containing one row per site and the following columns:
    
    - **lon:** Longitude in decimal degrees, WGS84 (EPSG:4326).
    
    - **lat:** Latitude in decimal degrees, WGS84 (EPSG:4326).
    
    - **vini:** The initial site-selection indicator used by the optimization. Use 1 for current monitoring sites and 0 for demand points available for additional sampling.
    
    Use numeric values without missing coordinates or classifications. Include at least one current site and one demand point. Extra columns may contain site identifiers or other attributes; they do not enter the distance calculations.
    
    Input coordinates must always be WGS84 longitude and latitude, regardless of the CRS selected in the location chooser. Sites are reprojected internally for extracting environmental data; geographic distances are calculated directly from WGS84 coordinates.
    
    Place the file in your BON in a Box `userdata` directory and enter its container path in **Sampling locations**, for example `/userdata/sampling_sites.csv`.
    
    The environmental variables, raster resolution, and supplied demand points determine the differences considered by the optimization. Choose variables relevant to the monitoring objectives and ensure their coverage includes all supplied sites. Set the number of additional sites to a value no greater than the number of rows with `vini = 0`.
    
  - |
    Authors:
    Francis van Oordt (francis.vanoordtlahoz@mail.mcgill.ca, https://orcid.org/0000-0002-8471-235X)
    Samara Manzin (samara.manzin@mcgill.ca, https://orcid.org/0009-0005-9134-9981)
  - |
    References:
    Medina, N. G., Lara, F., Mazimpaka, V., & Hortal, J. (2013). Designing bryophyte surveys for an optimal coverage of diversity gradients. Biodiversity and Conservation, 22(13–14), 3121–3139.
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
  pipeline@67:
    label: Country, region, or bounding box
    doc: Define the study extent and choose the coordinate reference system used to retrieve environmental data.
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

  pipeline@73:
    type:
      type: enum
      symbols:
        - Country or region
        - Polygon of bounding box
    label: Polygon type
    doc: Type of polygon loaded. If a country or region is selected in the above `Choose Bounding Box`, select `Country or region`. If a bounding box is drawn in the above `Choose Bounding Box`, select `Polygon of bounding box`
    default: Country or region

  data>loadFromStac.yml@45|spatial_res:
    type: float?
    label: Spatial resolution
    doc: >
      Environmental raster resolution in the selected CRS units: metres for a CRS measured in metres, degrees for EPSG:4326. 
      
      If blank, the loader attempts native resolution, requiring compatible CRS units. 
      
      This does not change the required WGS84 input coordinates or the geodesic distance method.
    default: 0.00883

  data>loadFromStac.yml@45|collections_items:
    type: string[]?
    label: STAC collection items
    doc: Provide the environmental variables using the format `collection|item`, such as `chelsa-clim|bio1` and `chelsa-clim|bio12`. These variables define the environmental differences between sites.
    default:
    - chelsa-clim|bio1
    - chelsa-clim|bio12

  pipeline@52:
    type: File?
    label: Sampling locations
    doc: Path to one CSV with lon and lat in WGS84 decimal degrees (EPSG:4326), and vini: 1 for current sites, 0 for demand points. Input coordinates always use WGS84, independently of the selected processing CRS.
    default: /scripts/site_optz_stepwise/site_optz_stepwise_EXAMPLE_samp_loc_peru.csv

  pipeline@54:
    type: int?
    label: Algorithm Iterations
    doc: Positive integer number of demand points to add. Must not exceed the number of rows with vini = 0. For example, 40 current sites and 60 demand points allow at most 60 additions. More iterations take longer.
    default: 30



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

          bash -c 'getPackedEnv "site_optz_stepwise__distance_matrix" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-tidyterra, r-tidyterra, r-dplyr]
          name: site_optz_stepwise__distance_matrix
          "' || exit 1
          
          bash -c 'getPackedEnv "data__loadFromStac" "channels: [conda-forge, r]
          dependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,
            r-rcurl, r-rjson, r-sf, r-stars, r-terra]
          name: data__loadFromStac
          "' || exit 1
          
          bash -c 'getPackedEnv "site_optz_stepwise__site_optz_stepwise" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-tidyterra, r-ggplot2, r-dplyr]
          name: site_optz_stepwise__site_optz_stepwise
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

  site_optz_stepwise>distance_matrix.yml@39:
    run: ../../tools/site_optz_stepwise/distance_matrix.cwl
    in:
      rasters: data>loadFromStac.yml@45/rasters_out
      locations_csv: pipeline@52
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_optz_stepwise__distance_matrix' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_optz_stepwise__distance_matrix/39' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [dist_matrix_out, env_matrix_out, mdist_out]


  data>loadFromStac.yml@45:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@67
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: data>loadFromStac.yml@45|collections_items
      t0: { default: null }
      t1: { default: null }
      temporal_res: { default: null }
      spatial_res: data>loadFromStac.yml@45|spatial_res
      resampling: { default: near }
      aggregation: { default: first }
      study_area: { default: null }
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/45' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_out]


  site_optz_stepwise>site_optz_stepwise.yml@61:
    run: ../../tools/site_optz_stepwise/site_optz_stepwise.cwl
    in:
      country_polygon: data>load_polygons.yml@63/polygon_out
      iters: pipeline@54
      rasters: data>loadFromStac.yml@45/rasters_out
      locations_csv: pipeline@52
      mdist: site_optz_stepwise>distance_matrix.yml@39/mdist_out
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_optz_stepwise__site_optz_stepwise' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_optz_stepwise__site_optz_stepwise/61' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [point_sel_out, uncov_out, surdes_uncov_out, surdes_map_out, sites_gpkg_out]


  data>load_polygons.yml@63:
    run: ../../tools/data/load_polygons.cwl
    in:
      polygon_type: pipeline@73
      country_region_bbox: pipeline@67
      buffer: { default: 0.0 }
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/63' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon_out, bbox_crs_out]


outputs:
  site_optz_stepwise>site_optz_stepwise.yml@61|point_sel_out:
    type: File
    label: Selection of demand points
    doc: CSV of newly selected demand points in selection order, including lon, lat, vini, site_row (original CSV row, starting at 1), selected, selection_order, and status. Current sites are excluded.
    outputSource: site_optz_stepwise>site_optz_stepwise.yml@61/point_sel_out

  site_optz_stepwise>site_optz_stepwise.yml@61|uncov_out:
    type: File
    label: Uncovered variability
    doc: CSV with iteration and uncovered_variability, calculated as the sum of SURDES p-median scores at each iteration. This diagnostic is not a percentage of biodiversity represented and is not guaranteed to decrease monotonically.
    outputSource: site_optz_stepwise>site_optz_stepwise.yml@61/uncov_out

  site_optz_stepwise>site_optz_stepwise.yml@61|surdes_uncov_out:
    type: File
    label: Uncovered variability plot
    doc: PNG showing the sum of SURDES p-median scores at each iteration. Inspect alongside the selected sites; this diagnostic is not a percentage of biodiversity represented.
    outputSource: site_optz_stepwise>site_optz_stepwise.yml@61/surdes_uncov_out

  site_optz_stepwise>site_optz_stepwise.yml@61|surdes_map_out:
    type: File
    label: Map for selected points
    doc: PNG showing current sites, unselected demand points, and selected demand points in different colours.
    outputSource: site_optz_stepwise>site_optz_stepwise.yml@61/surdes_map_out

  site_optz_stepwise>site_optz_stepwise.yml@61|sites_gpkg_out:
    type: File
    label: Sampling sites GeoPackage
    doc: GeoPackage containing all input sites in WGS84 with vini, site_row, selected, selection_order, and status (Current, Demand, or Selected). Use status for viewer styling; automatic colours depend on the viewer.
    outputSource: site_optz_stepwise>site_optz_stepwise.yml@61/sites_gpkg_out

