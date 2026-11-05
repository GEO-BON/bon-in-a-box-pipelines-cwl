cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Environmental Sampling Site Selection
doc:
  - |
    Description:
    ## Introduction
    Biodiversity monitoring often requires researchers to draw samples of different population due to limitation of budget, time, and accesibility. Many methods exist to produce samples from a continous surface, but balanced sampling has proven to be one of the most efficient in capturing patterns in different populations. Often, researchers aim to prioritize sampling based on  different parameters, one being environmental characteristics of their study region (as a proxy of biomes or ecological regions). Tools that allow for quick and robust sampling frameworks provide researchers with strong sampling designs to address multiple ecological questions. 
    
    Here we present a method that uses balanced acceptance sampling to randomly select  sampling sites in a defined area, and allows for the prioritization of environmentally different regions within the study area.    
    ## Uses
    Selection of sampling sites using a BAS algorithm with two different approches (equal and unequal sampling distribution).
    ## Methodology
    In a first step, the pipeline performs a  [Principal Component Analysis (PCA)](https://en.wikipedia.org/wiki/Principal_component_analysis) on the user defined environmental variables. It grids them to produce environmental  blocks based on the two axis of the simplified environemental space.  The grid size is user-defined. When only two environmental variables are provided, no PCA is performed and the raw variables are used.
    
    In a second step, it uses the blocks to generate an unequal sampling distribution. The user specifies a target sample size to be allocated using a randomly balanced design. When the “unequal” option is selected, the inclusion probability of each block is proportional to its area, ensuring that larger blocks have a higher chance of being sampled.
    
    Alternatively, an equal sampling distribution can be selected, where all blocks have the same probability of selection. The procedure will also plot the randomly selected sampling  points over the environmental blocks, allowing users to visually assess whether certain areas are underrepresented or missing from the random sampling pattern.
    ## Limitations 
    * Currently the pipeline only works for a defined geopolitical outline (e.g. country, or province). 
    * Unequal sampling may produce unexpected results in the balanced appproach. 
    ## Before you start
    * Select environmental variables that may be of ecological importance for your study.
    * Define how many environmental blocks you expect to produce (too many may be noisy, to little may be underrepresenting the environmental diversity). 
  - "Lifecycle tag: In review."
  - |
    Authors:
    Francis van Oordt (francis.vanoordtlahoz@mail.mcgill.ca, https://orcid.org/0000-0002-8471-235X)
    Samara Manzin (samara.manzin@mcgill.ca, https://orcid.org/0009-0005-9134-9981)
  - |
    References:
    spbal: Spatially Balanced Sampling Algorithms
    null

    Survey-gap analysis in expeditionary research: where do we go from here?
    null

    Selection of sampling sites for biodiversity inventory: Effects of environmental and geographical considerations
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
  pipeline@60:
    label: Bounding box and CRS
    doc: elect your country or region of interest, then choose a projected coordinate reference system (CRS) appropriate for the study area using the dropdown.
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

  data>loadFromStac.yml@2|spatial_res:
    type: float?
    label: Spatial resolution
    doc: Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). This input may be blank when using ESPG:4326.
    default: 0.00883

  pipeline@64:
    type:
      type: enum
      symbols:
        - Country or region
        - Polygon of bounding box
    label: Polygon type
    doc: Type of polygon loaded. If a country or region is selected in the above `Choose Bounding Box`, select `Country or region`. If a bounding box is drawn in the above `Choose Bounding Box`, select `Polygon of bounding box`
    default: Country or region

  data>loadFromStac.yml@2|collections_items:
    type: string[]?
    label: Environmental variables (STAC collection items)
    doc: Provide at least two continuous environmental raster variables, using the format `collection|item`, such as `chelsa-clim|bio1` and `chelsa-clim|bio12`. The pipeline performs PCA on these variables to create the environmental blocks.
    default:
    - chelsa-clim|bio1
    - chelsa-clim|bio12

  site_selection_BAS>BAS_algorithm.yml@26|options_bas:
    type:
      type: enum
      symbols:
        - equal
        - unequal
    label: Sampling type
    doc: Select and option between equal BAS or unequal probability BAS. "Equal" will not consider the blocks and place all sampling randomly in the whole study area.  "Unequal" will take into account the size of the each environmental block and redistribute the sampling sites based on the size of block.  
    default: equal

  site_selection_BAS>BAS_algorithm.yml@26|ndesign:
    type: int?
    label: Target total sites
    doc: >
      A number of target sampling sites to obtain with the algorithm. The user must decide on a number of sites based on their sampling goals and scale of the study. 
      
      Larger study areas should have greater number of sampling locations, but constraints exist (e.g budget, staff, etc.) that may limit sampling locations and coverage. 
      
      Researchers should take into account their specifics sampling goals and timelines, and proceed with caution. 
    default: 100

  site_selection_BAS>Block_creation.yml@0|n_cols:
    type: int?
    label: Number of columns
    doc: >
      Number of columns for the environmental space grid (together with rows will define the final number of environmental blocks). 
      
      Blocks are based on a PCA of the environmental variables selected and represent  a proxy of ecozones in areas with lacking information. 
      
      A general recommendation is to start with fewer blocks because it would simplify computation and understanding of the study region, 5-10 blocks, and later increase if needed.
    default: 10

  site_selection_BAS>Block_creation.yml@0|n_rows:
    type: int?
    label: Number of rows
    doc: >
      Number of rows for the environmental space grid (together with columns will define the final number environmental blocks). 
      
      Blocks are based on a PCA of the environmental variables selected and represent  a proxy of ecozones in areas with lacking information. 
      
      A general recommendation is to start with fewer blocks because it would simplify computation and understanding of the study region, 5-10 blocks, and later increase if needed.
    default: 10



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
          dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335
        EnvVarRequirement:
          envDef:
            CONDA_PKGS_DIRS: /conda-env-yml/pkgs
            CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
            SCRIPT_STUBS_LOCATION: /script-stubs
            OUTPUT_LOCATION: "$(inputs.runFolderWrite ? inputs.runFolderWrite.path : runtime.outdir)"
            CONDA_PACK_URL: $(inputs.condaPackURL)
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
              "$condaEnvYml" "$dedicatedEnvFolder" "$CONDA_PACK_URL" --noActivate
            source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh "$condaEnvName" "$dedicatedEnvFolder"
            echo "Done."
          }
          export -f getPackedEnv

          bash -c 'getPackedEnv "site_selection_BAS__Block_creation" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-ggplot2, r-tidyterra, r-cowplot, r-factoextra]
          name: site_selection_BAS__Block_creation
          "'
          
          bash -c 'getPackedEnv "data__loadFromStac" "channels: [conda-forge, r]
          dependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,
            r-rcurl, r-rjson, r-sf, r-stars, r-terra]
          name: data__loadFromStac
          "'
          
          bash -c 'getPackedEnv "site_selection_BAS__BAS_algorithm" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-ggplot2, r-tidyterra, r-cowplot, r-sf, r-remotes]
          name: site_selection_BAS__BAS_algorithm
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
        valueFrom: "$({ class: 'Directory', location: (self ? self.location : '/tmp/cwl' ) + '/preparePackedEnvs' })"
      condaPackURL: condaPackURL
    out: [envFolder]

  site_selection_BAS>Block_creation.yml@0:
    run: ../../tools/site_selection_BAS/Block_creation.cwl
    in:
      country_polygon: data>load_polygons.yml@61/polygon_out
      n_rows: site_selection_BAS>Block_creation.yml@0|n_rows
      n_cols: site_selection_BAS>Block_creation.yml@0|n_cols
      rasters: data>loadFromStac.yml@2/rasters_out
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_selection_BAS__Block_creation' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_selection_BAS__Block_creation/0' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rast_blocks_out, blocks_plot_out, pca_summary_df_out, colors_vect_out]


  data>loadFromStac.yml@2:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@60
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: data>loadFromStac.yml@2|collections_items
      t0: { default: null }
      t1: { default: null }
      temporal_res: { default: null }
      spatial_res: data>loadFromStac.yml@2|spatial_res
      resampling: { default: near }
      aggregation: { default: first }
      study_area: data>load_polygons.yml@61/polygon_out
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/2' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_out]


  site_selection_BAS>BAS_algorithm.yml@26:
    run: ../../tools/site_selection_BAS/BAS_algorithm.cwl
    in:
      colors_vect: site_selection_BAS>Block_creation.yml@0/colors_vect_out
      country_polygon: data>load_polygons.yml@61/polygon_out
      rast_blocks: site_selection_BAS>Block_creation.yml@0/rast_blocks_out
      ndesign: site_selection_BAS>BAS_algorithm.yml@26|ndesign
      options_bas: site_selection_BAS>BAS_algorithm.yml@26|options_bas
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_selection_BAS__BAS_algorithm' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_selection_BAS__BAS_algorithm/26' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [maps_output_out, pts_df_out, points_shape_out]


  data>load_polygons.yml@61:
    run: ../../tools/data/load_polygons.cwl
    in:
      polygon_type: pipeline@64
      country_region_bbox: pipeline@60
      buffer: { default: 0.0 }
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/61' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon_out, bbox_crs_out]


outputs:
  site_selection_BAS>Block_creation.yml@0|rast_blocks_out:
    type: File[]
    label: Environmental blocks raster
    doc: A categorical GeoTIFF identifying the environmental block assigned to each classified raster cell.
    outputSource: site_selection_BAS>Block_creation.yml@0/rast_blocks_out

  site_selection_BAS>Block_creation.yml@0|pca_summary_df_out:
    type: csv
    label: Summary of PCA
    doc: A CSV showing the standard deviation, percentage of variance explained, and cumulative percentage of variance explained for the principal components. Use it to assess how much environmental variation the first two components represent.
    outputSource: site_selection_BAS>Block_creation.yml@0/pca_summary_df_out

  site_selection_BAS>Block_creation.yml@0|blocks_plot_out:
    type: File
    label: Blocks and map plots
    doc: A figure showing environmental blocks in principal-component space alongside their geographic distribution.
    outputSource: site_selection_BAS>Block_creation.yml@0/blocks_plot_out

  site_selection_BAS>BAS_algorithm.yml@26|maps_output_out:
    type: File
    label: Maps output
    doc: Two maps showing the proposed sampling sites: one over the study-area polygon and one over the environmental blocks. Use these to inspect geographic and environmental coverage.
    outputSource: site_selection_BAS>BAS_algorithm.yml@26/maps_output_out

  data>loadFromStac.yml@2|rasters_out:
    type: File[]
    label: Environmental Rasters
    doc: The environmental rasters retrieved for the analysis, provided for inspection and further exploration.
    outputSource: data>loadFromStac.yml@2/rasters_out

  site_selection_BAS>BAS_algorithm.yml@26|pts_df_out:
    type: csv
    label: Selected points
    doc: A CSV containing the proposed sites’ longitude and latitude in WGS84 (EPSG:4326), with columns named lon and lat.
    outputSource: site_selection_BAS>BAS_algorithm.yml@26/pts_df_out

  site_selection_BAS>BAS_algorithm.yml@26|points_shape_out:
    type: File
    label: Selected points GeoJSON
    doc: A GeoJSON file containing the proposed sampling locations
    outputSource: site_selection_BAS>BAS_algorithm.yml@26/points_shape_out

