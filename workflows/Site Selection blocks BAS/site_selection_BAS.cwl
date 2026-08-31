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
    
    In a first step, the pipeline produces environmental blocks based on user defined environmental variables (after performing a PCA analysis on said variables and defining a block grid) and can use those blocks to generate an unequal sampling distribution.  
    
    Blocks are created from PCAs performed on the selected environmental variables or can use only two raw environmental variables, in which case no PCA is performed. 
    
    The user must define the grid size for block generation and specify a target  sample size to be allocated using a randomly balanced design. When the “unequal” option  is selected, the inclusion probability of each block is proportional to its area,  ensuring that larger blocks have a higher chance of being sampled.
    
    Alternatively, an equal sampling distribution can be selected, where all blocks have the  same probability of selection. The procedure will also plot the randomly selected sampling  points over the environmental blocks, allowing users to visually assess whether certain  areas are underrepresented or missing from the random sampling pattern.
    ## Limitations 
    * Currently the pipeline only works for a defined geopolitical outline (e.g. country, or province). 
    * Unequal sampling may produce unexpected results in the balanced appproach. 
    ## Before you start
    * Define a projected CRS for your study area 
    * Select environmental variables that may be of ecological importance for your study 
    * Define how many environmental blocks you expect to produce (too many may be noisy, to little may be underrepresenting the environmental diversity). 
  - |
    Authors:
    Francis van Oordt (francis.vanoordtlahoz@mail.mcgill.ca, https://orcid.org/0000-0002-8471-235X)
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
  data>load_polygons.yml@61|polygon_type:
    type:
      type: enum
      symbols:
        - Country or region
        - WDPA
        - EEZ
        - Polygon of bounding box
    label: Polygon type
    doc: Type of polygon to load. Country or region polygons, World database of Protected Areas (WDPA), Exclusive Economic Zones (EEZs), or a custom polygon of a bounding box.
    default: Country or region

  pipeline@60:
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

  data>loadFromStac.yml@2|collections_items:
    type: string[]?
    label: Environmental variables (STAC collection items)
    doc: Set of environmental variables to use  (e.g. for temperature "chelsa-clim|bio1", precipitation "chelsa-clim|bio12"), on which to run the PCA (a minimum of 2 variables are needed). Environmental variables must be continuous values.
    default:
    - chelsa-clim|bio1
    - chelsa-clim|bio2

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
    doc: A number of target sampling sites to obtain with the algorithm
    default: 100

  site_selection_BAS>Block_creation.yml@0|n_cols:
    type: int?
    label: Number of columns
    doc: Number of columns for the environmental space grid (together with rows will define the final number of environmental blocks)
    default: 10

  site_selection_BAS>Block_creation.yml@0|n_rows:
    type: int?
    label: Number of rows
    doc: Number of rows for the environmental space grid (together with columns will define the final number environmental blocks)
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
        valueFrom: "$({ class: 'Directory', location: (self ? self.location : '/tmp/cwl' ) + '/prepareEnvironments' })"
      condaPackURL: condaPackURL
    out: [envFolder]

  site_selection_BAS>Block_creation.yml@0:
    run: ../../tools/site_selection_BAS/Block_creation.cwl
    in:
      country_polygon: data>load_polygons.yml@61/polygon
      n_rows: site_selection_BAS>Block_creation.yml@0|n_rows
      n_cols: site_selection_BAS>Block_creation.yml@0|n_cols
      rasters: data>loadFromStac.yml@2/rasters
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_selection_BAS__Block_creation' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_selection_BAS__Block_creation/0' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rast_blocks, blocks_plot, pca_summary_df, colors_vect]


  data>loadFromStac.yml@2:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@60
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: data>loadFromStac.yml@2|collections_items
      t0: { default: null }
      t1: { default: null }
      temporal_res: { default: null }
      spatial_res: { default: 1000.0 }
      resampling: { default: near }
      aggregation: { default: first }
      study_area: data>load_polygons.yml@61/polygon
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
    out: [rasters]


  site_selection_BAS>BAS_algorithm.yml@26:
    run: ../../tools/site_selection_BAS/BAS_algorithm.cwl
    in:
      colors_vect: site_selection_BAS>Block_creation.yml@0/colors_vect
      country_polygon: data>load_polygons.yml@61/polygon
      rast_blocks: site_selection_BAS>Block_creation.yml@0/rast_blocks
      ndesign: site_selection_BAS>BAS_algorithm.yml@26|ndesign
      options_bas: site_selection_BAS>BAS_algorithm.yml@26|options_bas
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_selection_BAS__BAS_algorithm' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/site_selection_BAS__BAS_algorithm/26' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [maps_output, pts_df, points_shape]


  data>load_polygons.yml@61:
    run: ../../tools/data/load_polygons.cwl
    in:
      polygon_type: data>load_polygons.yml@61|polygon_type
      country_region_bbox: pipeline@60
      buffer: { default: 0.0 }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/61' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon, bbox_crs]


outputs:
  site_selection_BAS>Block_creation.yml@0|rast_blocks:
    type: File[]
    label: Environmental blocks raster
    doc: Raster file of the study area with the environmental blocks as categorical classes  
    outputSource: site_selection_BAS>Block_creation.yml@0/rast_blocks

  site_selection_BAS>Block_creation.yml@0|pca_summary_df:
    type: csv
    label: Summary of PCA
    doc: Principal component analysis summary for the environmental variables included in the analysis
    outputSource: site_selection_BAS>Block_creation.yml@0/pca_summary_df

  site_selection_BAS>Block_creation.yml@0|blocks_plot:
    type: File
    label: Blocks and map plots
    doc: Blocks showing the PCA 1 and 2 result and the predefined blocks dividing the environmental space and the map of the environmental blocks in geographic space
    outputSource: site_selection_BAS>Block_creation.yml@0/blocks_plot

  site_selection_BAS>BAS_algorithm.yml@26|maps_output:
    type: File
    label: Maps output
    doc: Maps of study area with selected sampling points only (no environmental blocks) and also including the environmental blocks.
    outputSource: site_selection_BAS>BAS_algorithm.yml@26/maps_output

  data>loadFromStac.yml@2|rasters:
    type: File[]
    label: Environmental Rasters
    doc: Array of environmental rasters (for exploration only)
    outputSource: data>loadFromStac.yml@2/rasters

  site_selection_BAS>BAS_algorithm.yml@26|pts_df:
    type: csv
    label: Selected points
    doc: dataframe of selected points
    outputSource: site_selection_BAS>BAS_algorithm.yml@26/pts_df

  site_selection_BAS>BAS_algorithm.yml@26|points_shape:
    type: File
    label: selected points shapefile
    doc: Vector shapefile of selected points
    outputSource: site_selection_BAS>BAS_algorithm.yml@26/points_shape

