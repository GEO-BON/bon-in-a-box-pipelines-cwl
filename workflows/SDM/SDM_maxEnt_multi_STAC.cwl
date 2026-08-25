cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Species distribution modeling with Maxent and multiple STAC catalogues
doc:
  - |
    Description:
    ## Introduction 
    Species distributions are an important [Essential Biodiversity Variable (EBV)](https://geobon.org/ebvs/what-are-ebvs/) in the species populations class. Knowing where species are likely to occur is essential for understanding biodiversity patterns, identifying conservation priorities, assessing potential impacts of environmental change, and supporting biodiversity indicators. However, species occurrence data are often sparse, unevenly distributed, and affected by spatial and taxonomic sampling bias. Species distribution models (SDMs) help fill these gaps by estimating where suitable environmental conditions occur for a species based on known observations and environmental predictors (Peterson, 2001; Elith and Leathwick, 2009).  
    
    The MaxEnt pipeline builds a species distribution model using occurrence records from the [Global Biodiversity Information Facility (GBIF)](https://www.gbif.org/) and environmental raster layers from the [GEO BON STAC catalog](https://stac.geobon.org/). The pipeline retrieves GBIF observations for the selected taxon or taxa, cleans occurrence coordinates, removes highly collinear environmental predictors, generates background points, and fits a MaxEnt model using the ENMeval R package (Kass et al. 2021). MaxEnt is a presence-background modeling approach, meaning it compares known species presences with background environmental conditions across the study area. The MaxEnt SDM is run by 1\) partitioning occurrence and background points into subsets for training and evaluation, 2\) building the model with different algorithmic settings (model tuning), and 3\) evaluating their performance ([see package vignette](https://jamiemkass.github.io/ENMeval/articles/ENMeval-2.0-vignette.html#partition)). Lastly, the pipeline computes the 95% confidence interval using bootstrapping and cross validation techniques.  
    
    The pipeline evaluates different MaxEnt settings, including feature classes and regularization multipliers, and selects a tuned model based on model performance. It produces a habitat suitability prediction raster, cleaned occurrence records, selected environmental predictors, a GBIF download DOI, and a raster summarizing variability among model runs.  
    ## Uses
    The MaxEnt pipeline can be used to estimate the potential distribution or relative habitat suitability of one or more species within a selected study area. Outputs can support conservation planning, sampling prioritization, identification of biodiversity hotspots, protected area planning, risk assessment for species of conservation concern, and environmental impact assessments.  
    
    The results can also be used as inputs to other biodiversity analyses and indicators, such as identifying areas where species are likely to occur, mapping speciesrichness,comparing predicted habitat suitability across regions, or highlighting areas where additional occurrence sampling may be needed. Because the pipeline retrieves both GBIF observations and environmental predictor layers, it provides a reproducible workflow for generating species distribution maps from public biodiversity and environmental data. 
    ## Pipeline limitations
    * MaxEnt uses presence-background data, not confirmed absence data. Predictions should be interpreted as relative habitat suitability or relative occurrence potential, not confirmed species presence or absence.
    * GBIF records may contain spatial, taxonomic, and temporal biases. The pipeline applies coordinate-cleaning steps, but users should still inspect the cleaned presences and interpret results cautiously, especially for poorly sampled taxa or regions.
    * Model quality depends strongly on the number and quality of occurrence records. Very small numbers of cleaned presences may produce unreliable predictions.
    * The choice of environmental predictors, background sampling method, feature classes, regularization multipliers, and partitioning method can affect model outputs. Users should treat the model as sensitive to these settings, especially for final analyses.
    * Environmental predictors must be ecologically relevant to the species being modeled. Including many correlated or irrelevant predictors can reduce interpretability and increase overfitting risk.
    * The pipeline estimates suitability based on the predictor layers supplied by the user. It does not directly account for dispersal limits, biotic interactions, land-use barriers, species detectability, or future environmental change unless those factors are represented in the input data.
    * Larger study areas, finer spatial resolutions, more environmental predictors, and more model runs increase computation time and memory use.
    ## Before you start
    A GBIF API key is required to run this pipeline and can be added into the runner.env file.  
    
    Before running the pipeline, choose the taxon or taxa you want to model and make sure the names match the GBIF taxonomic backbone. Species names can be checked on the [GBIF website](https://www.gbif.org/).  
    
    Select a study area using the bounding box and CRS input. The CRS and spatial resolution determine the scale of the analysis, so choose a CRS appropriate for the region and make sure the spatial resolution is in the units of that CRS.  
    
    Choose environmental predictor layers from the [STAC catalog](https://stac.geobon.org/) that are ecologically relevant to the species being modeled. For example, climate, vegetation, elevation, land cover, or habitat-related predictors may be appropriate depending on the species. Avoid including many predictors that represent the same underlying environmental gradient.
  - |
    Authors:
    Sarah Valentin (Pipeline development, https://orcid.org/0000-0002-9028-681X)
    Guillaume Larocque (Pipeline development, guillaume.larocque@mcgill.ca, https://orcid.org/0000-0002-5967-9156)
    François Rousseu (Pipeline development, https://orcid.org/0000-0002-2400-2479)
  - "External link: https://github.com/GEO-BON/biab-2.0/blob/main/scripts/SDM/runMaxent.R"
  - |
    References:
    Vollering et al. 2019
    null

    Phillips et al. 2009
    null

    Bastion 2023
    null

    Kass et al. 2021
    null

    Elith and Leathwick, 2009
    null

    Peterson, 2001
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
  pipeline@121:
    type: string[]?
    label: Taxa list
    doc: Comma-separated list of [taxa](https://en.wikipedia.org/wiki/Taxon). Each value could be a species name, order, class, genus, kingdom or family, as long as it is an exact match with the GBIF taxonomic backbone. Individual species can be looked up [on the GBIF website](https://www.gbif.org/species/).
    default:
    - Acer saccharum

  data>GBIFHeatmapFromSTAC.yml@139|taxa:
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
    label: Taxonomic group
    doc: Broad taxonomic group used to retrieve the GBIF observation-density heatmap for background-point sampling. Choose the group that best matches the modeled taxa, or all for all GBIF observations.
    default: plants

  pipeline@140:
    label: Bounding box and CRS
    doc: >
      Bounding box and coordinate reference system defining the analysis extent. This extent is used to retrieve GBIF occurrences, environmental predictor rasters, the GBIF sampling-effort heatmap, and the study extent for modelling.
      
      The extent you choose affects how results should be interpreted and may change which predictors emerge as important.
      * Larger than the species' range: results lean toward occurrence/accessibility. Predictors tied to broad-scale distributional limits (climate, biogeography) may dominate.
      * Similar to or smaller than the species' range: results lean toward habitat suitability. Predictors tied to local habitat structure (vegetation, soil) may matter more.
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

  pipeline@152:
    type: File?
    label: Study area
    doc: Polygon of study area used to mask output layers, in geopackage format.

  pipeline@128:
    type: float?
    label: Spatial resolution
    doc: >
      Target spatial resolution for the predictor rasters and GBIF heatmap. Units must match the selected CRS, for example meters for projected CRS or degrees for latitude-longitude CRS.
      
      Choosing a coarser resolution reduces computation time, but at the cost of fine-scale predictor detail. Variables like land cover and elevation may lose relevance at coarse scales, while broader-scale variables such as climate become comparatively more informative.
    default: 1000

  pipeline@151:
    type: string?
    label: Temporal resolution
    doc: Temporal resolution to use when querying STAC items by date, in the format ("P", time interval, and time unit, e.g. "P1Y" is yearly, "P1M" is montly, and "P1D" is daily). Leave blank if not querying by date or if extracting layers from all available dates. If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below.
    default: P1Y

  data>loadFromStac.yml@144|stac_url:
    type: string?
    label: STAC 1 URL
    doc: URL of the first STAC catalog used to retrieve environmental predictor layers.
    default: https://stac.geobon.org/

  data>loadFromStac.yml@144|collections_items:
    type: string[]?
    label: STAC 1 collection items
    doc: >
      To pull a specific collection item, input the collection name followed by | followed by the item ID (e.g. "chelsa-clim|bio1").
      
      To extract a whole collection, type the collection name only (e.g. "chelsa-clim").
      
      If pulling a layer that is tiled (e.g. https://stac.geobon.org/viewer/gfw-lossyear/_80N_180W), enter the collection name (e.g. gfw-lossyear) and a bounding box, and the script will assemble the tiles into a continuous layer automatically.
    default:
    - chelsa-clim|bio1
    - chelsa-clim|bio2

  data>loadFromStac.yml@150|stac_url:
    type: string?
    label: STAC 2 URL
    doc: URL of the second STAC catalog.
    default: https://io.biodiversite-quebec.ca/stac/

  data>loadFromStac.yml@150|collections_items:
    type: string[]?
    label: STAC 2 collection items
    doc: Vector of strings. To pull specific collection items, input the collection name followed by '|' followed by item id (e.g. "chelsa-clim|bio1"). To extract a whole collection, type the collection name only (e.g. "chelsa-clim"). To pull collection items by date, write the collection name and provide a start date, end date, and temporal resolution. If pulling a layer that is tiled (e.g. https://stac.geobon.org/viewer/gfw-lossyear/_80N_180W), enter the collection name (e.g. gfw-lossyear), bounding box and time range if the layer is a time series, and the script will assemble the tiles into a continuous layer automatically.)
    default:
    - chelsa-clim|bio4

  pipeline@145:
    type: string?
    label: Minimum year or start date
    doc: >
      Earliest year for GBIF records. Accepts YYYY or YYYY-MM-DD; if a full date is supplied, only the year is used.
      
      It is recommended to use an early start date (e.g. 1980) to maximize the number of occurrence records for a given species.
    default: '1980'

  pipeline@146:
    type: string?
    label: Maximum year or end date
    doc: Latest year for GBIF records. Accepts YYYY or YYYY-MM-DD; if a full date is supplied, only the year is used.
    default: '2024'

  SDM>selectBackground.yml@40|n_background:
    type: int?
    label: Number of background points
    doc: >
      Target number of background points to generate within the study extent. These points are used to represent the available environment.
      
      Typically it is recommended to start with 10000 points. If you have a very large study area you can increase this amount to fully capture the available environmental space. If you have a very small study area (i.e. fewer than 10000 pixels) you can reduce the number of background points.
    default: 10000

  SDM>selectBackground.yml@40|method_background:
    type:
      type: enum
      symbols:
        - random
        - inclusion_buffer
        - weighted_raster
        - unweighted_raster
        - thickening
    label: Method background
    doc: >
      Background points are generated using one of the five available methods. Choosing the right method can help correct for sampling bias in the GBIF data.
      - `random`: background points are randomly sampled throughout the whole study extent. Good choice if your occurrence data has little spatial bias toward human activity/accessibility (e.g., roads, cities, well-surveyed areas).
      - `weighted_raster`: background points are sampled in proportion to the number of observations in the observation-density heatmap of the selected taxonomic group. Recommended for heavily biased data, or when occurrences are missing due to gaps in survey/study coverage. This is the more extreme correction of the two raster-based methods (weighted and unweighted).
      - `unweighted_raster`: background points are sampled only in cells where there are observations from a target group. Also addresses sampling bias and survey gaps, but more conservatively than weighted_raster. Recommended as the default of the two (weighted and unweighted).
      - `inclusion_buffer`: background points are sampled within a buffer around observations. Useful if you don't think your species is well represented by the target taxonomic group. 
      - `thickening`: background points are sampled in proportion to the local density of observations, within a buffer around each observation. Also useful when the target taxon group doesn't represent your species well, as an alternative to inclusion_buffer.
    default: random

  pipeline@46:
    type: int?
    label: Number of runs
    doc: Number of bootstrap or cross-validation runs used when preparing SDM training and testing data.
    default: 2

  SDM>runMaxent.yml@108|fc:
    type: string[]?
    label: Feature classes
    doc: MaxEnt feature classes control the shapes of relationships the model can learn between species occurrence and environmental predictors. Simpler classes, such as L or LQ, fit smoother, more constrained responses and are often safer for small datasets. More complex combinations, such as LQH or LQHP, can capture more flexible ecological responses but may overfit when occurrence records are limited. This pipeline tests all values provided here and selects the best-performing combination using the parameter selection method configured in the MaxEnt step. Accepted values are combinations of L (linear), Q (quadratic), P (product), H (hinge) or T (threshold).
    default:
    - L
    - LQ
    - LQHP

  SDM>runMaxent.yml@108|rm:
    type: float[]?
    label: Regularization multiplier
    doc: Regularization multiplier values to evaluate for MaxEnt model tuning. The regularization multiplier controls how strongly MaxEnt penalizes model complexity. Lower values allow a more flexible model that may fit local patterns closely. Higher values produce smoother, more generalized predictions and reduce overfitting risk. 
    default:
    - 0.5
    - 1
    - 2

  SDM>runMaxent.yml@108|partition_type:
    type:
      type: enum
      symbols:
        - randomkfold
        - jackknife
        - block
        - checkerboard1
        - checkerboard2
    label: Partition type
    doc: >
      This option controls how ENMeval partitions presence and background data while tuning MaxEnt parameters.
      
      It is recommended to start with random k-fold. If you suspect overfitting or spatial autocorrelation, switch to block or checkerboard because these partition data geographically rather than randomly, which makes evaluation more robust to spatial autocorrelation between nearby points. If you don't have enough occurrence points for spatial partitioning, use jackknife.
      
         - Random k-fold \- partitions groups randomly into a user-specified (K) number of bins, and runs the model k times, with each bin used once as testing. Recommended to start with 10 folds.
        - Block \- partitions the bounding box into four equally sized quadrants and assigns groups by quadrant. Because each fold is a large, contiguous geographic region, this tests how well the model transfers to broad, spatially distinct areas. This is a stricter test of spatial autocorrelation than checkerboard.
        - Checkerboard 1 \- generates a checkerboard grid from the study area and assigns groups based on which square the points fall in. Folds are smaller and spatially interspersed (alternating across the study area) rather than large contiguous blocks, so it tests spatial independence at a finer scale than block.
        - Checkerboard 2 \- Similar to checkerboard 1 but performs this separately for occurrence and background points
        - Jackknife \- Does not partition the background points into testing and training (uses them all), performs leave one out cross validation. Recommended for small datasets only.
    default: randomkfold

  pipeline@147:
    type: int?
    label: Number of folds
    doc: Number of folds for random k-fold MaxEnt partitioning when partition type = random k-fold. Can be left blank when another method is chosen.
    default: 10

  pipeline@148:
    type: string?
    label: Start date
    doc: Start date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if extracting items by name or to extract layers from all available dates.

  pipeline@149:
    type: string?
    label: End date
    doc: End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if extracting items by name or to extract layers from all available dates.

  STAC>createCollection.yml@153|collection_name:
    type: string?
    label: Collection Name
    doc: Name of the STAC collection to be created as output. The collection name should be unique, using lowercase letters and hyphens only. Default is "biab-collection".
    default: biab-collection

  STAC>createCollection.yml@153|collection_description:
    type: string?
    label: Collection Description
    doc: Description of the STAC collection to be created as output.
    default: A STAC collection created from GeoTIFF files.

  STAC>createCollection.yml@153|collection_license:
    type: string?
    label: Collection License
    doc: License for the STAC collection to be created as output. Default is "CC-BY".
    default: CC-BY



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

          bash -c 'getPackedEnv "filtering__cleanCoordinates" "channels: [conda-forge, r]
          dependencies: [r-terra, r-rjson, r-raster, r-dplyr, r-CoordinateCleaner, r-gdalcubes]
          name: filtering__cleanCoordinates
          "'
          
          bash -c 'getPackedEnv "SDM__selectBackground" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-dplyr, r-raster, r-CoordinateCleaner, r-stars,
            r-rstac, r-gdalcubes]
          name: SDM__selectBackground
          "'
          
          bash -c 'getPackedEnv "SDM__setupDataSdm" "channels: [conda-forge, r]
          dependencies: [r-gdalcubes, r-terra, r-rjson, r-raster, r-dplyr, r-ENMeval, r-devtools]
          name: SDM__setupDataSdm
          "'
          
          bash -c 'getPackedEnv "SDM__rangePredictions" "channels: [conda-forge, r]
          dependencies: [r-terra, r-rjson, r-raster, r-dplyr]
          name: SDM__rangePredictions
          "'
          
          bash -c 'getPackedEnv "SDM__removeCollinearity" "channels: [conda-forge, r]
          dependencies: [r-terra, r-rjson, r-dplyr, r-gdalcubes]
          name: SDM__removeCollinearity
          "'
          
          bash -c 'getPackedEnv "SDM__runMaxent" "channels: [conda-forge, r]
          dependencies: [libgdal, r-abind, r-base, r-curl, r-dismo, r-downloader, r-dplyr, r-enmeval=2.0.3,
            r-ecospat, r-essentials, r-geojsonsf, r-ggsci, r-jpeg, r-landscapemetrics, r-magrittr,
            r-png, r-purrr, r-rcurl, r-rgbif, r-remotes, r-rjava, r-rjson, r-sf, r-stars, r-stringr,
            r-terra, r-this.path, r-tidyselect, r-tidyverse, r-stringr]
          name: SDM__runMaxent
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
          
          bash -c 'getPackedEnv "STAC__createCollection" "channels: [conda-forge]
          dependencies: [pystac, gdal, jsonschema, rasterio, shapely, pyproj, geopandas, rasterstats,
            numpy]
          name: STAC__createCollection
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
      presence: data>getGBIFObservations>getGBIFObservations.yml@142/observations_file
      predictors: SDM>removeCollinearity.yml@97/rasters_selected
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
    out: [n_presence, n_clean, clean_presence]


  SDM>selectBackground.yml@40:
    run: ../../tools/SDM/selectBackground.cwl
    in:
      presence: filtering>cleanCoordinates.yml@34/clean_presence
      extent: SDM>studyExtent.yml@104/study_extent
      method_background: SDM>selectBackground.yml@40|method_background
      n_background: SDM>selectBackground.yml@40|n_background
      predictors: SDM>removeCollinearity.yml@97/rasters_selected
      raster: data>GBIFHeatmapFromSTAC.yml@139/rasters
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__selectBackground' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__selectBackground/40' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [n_background, background]


  SDM>setupDataSdm.yml@44:
    run: ../../tools/SDM/setupDataSdm.cwl
    in:
      presence: filtering>cleanCoordinates.yml@34/clean_presence
      background: SDM>selectBackground.yml@40/background
      predictors: SDM>removeCollinearity.yml@97/rasters_selected
      partition_type: { default: bootstrap }
      runs_n: pipeline@46
      boot_proportion: { default: 0.7 }
      cv_partitions: { default: 5 }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__setupDataSdm' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__setupDataSdm/44' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [presence_background]


  SDM>rangePredictions.yml@68:
    run: ../../tools/SDM/rangePredictions.cwl
    in:
      predictions: SDM>runMaxent.yml@108/sdm_runs
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__rangePredictions' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__rangePredictions/68' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [range_predictions]


  SDM>removeCollinearity.yml@97:
    run: ../../tools/SDM/removeCollinearity.cwl
    in:
      rasters:
        source: [data>loadFromStac.yml@150/rasters, data>loadFromStac.yml@144/rasters]
        linkMerge: merge_flattened
      method: { default: vif.cor }
      method_cor_vif: { default: pearson }
      nb_sample: { default: 5000 }
      cutoff_cor: { default: 0.75 }
      cutoff_vif: { default: 8 }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__removeCollinearity' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__removeCollinearity/97' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_selected]


  SDM>studyExtent.yml@104:
    run: ../../tools/SDM/studyExtent.cwl
    in:
      presence: filtering>cleanCoordinates.yml@34/clean_presence
      bbox_crs: pipeline@140
      method: { default: bbox }
      width_buffer: { default: 0 }
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__studyExtent/104' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [area_study_extent, study_extent]


  SDM>runMaxent.yml@108:
    run: ../../tools/SDM/runMaxent.cwl
    in:
      presence_background: SDM>setupDataSdm.yml@44/presence_background
      predictors: SDM>removeCollinearity.yml@97/rasters_selected
      fc: SDM>runMaxent.yml@108|fc
      rm: SDM>runMaxent.yml@108|rm
      partition_type: SDM>runMaxent.yml@108|partition_type
      orientation_block: { default: lat_lon }
      crs: pipeline@140
      n_folds: pipeline@147
      method_select_params: { default: AUC }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__runMaxent' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SDM__runMaxent/108' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [sdm_pred, sdm_runs]


  data>GBIFHeatmapFromSTAC.yml@139:
    run: ../../tools/data/GBIFHeatmapFromSTAC.cwl
    in:
      taxa: data>GBIFHeatmapFromSTAC.yml@139|taxa
      bbox_crs: pipeline@140
      spatial_res: pipeline@128
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__GBIFHeatmapFromSTAC/139' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters]


  data>getGBIFObservations>getGBIFObservations.yml@142:
    run: ../../tools/data/getGBIFObservations/getGBIFObservations.cwl
    in:
      taxa: pipeline@121
      bbox_crs: pipeline@140
      min_year: pipeline@145
      max_year: pipeline@146
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__getGBIFObservations' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__getGBIFObservations/142' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [observations_file, total_records, gbif_doi]


  data>loadFromStac.yml@144:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@140
      stac_url: data>loadFromStac.yml@144|stac_url
      collections_items: data>loadFromStac.yml@144|collections_items
      t0: pipeline@148
      t1: pipeline@149
      temporal_res: pipeline@151
      spatial_res: pipeline@128
      resampling: { default: near }
      aggregation: { default: first }
      study_area: pipeline@152
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/144' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters]


  data>loadFromStac.yml@150:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@140
      stac_url: data>loadFromStac.yml@150|stac_url
      collections_items: data>loadFromStac.yml@150|collections_items
      t0: pipeline@148
      t1: pipeline@149
      temporal_res: pipeline@151
      spatial_res: pipeline@128
      resampling: { default: near }
      aggregation: { default: first }
      study_area: pipeline@152
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/150' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters]


  STAC>createCollection.yml@153:
    run: ../../tools/STAC/createCollection.cwl
    in:
      tiff_files:
        source: [SDM>runMaxent.yml@108/sdm_pred]
        linkMerge: merge_flattened
      collection_name: STAC>createCollection.yml@153|collection_name
      collection_description: STAC>createCollection.yml@153|collection_description
      collection_license: STAC>createCollection.yml@153|collection_license
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/STAC__createCollection' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/STAC__createCollection/153' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [stac_collection]


outputs:
  filtering>cleanCoordinates.yml@34|clean_presence:
    type: File
    label: Presences
    doc: Cleaned GBIF occurrence records that passed the selected coordinate-cleaning tests. These records are used as presence points in the SDM workflow.
    outputSource: filtering>cleanCoordinates.yml@34/clean_presence

  SDM>removeCollinearity.yml@97|rasters_selected:
    type: File[]
    label: Environmental predictors
    doc: GeoTIFF predictor rasters retained after collinearity filtering. These are the environmental variables used to fit and project the MaxEnt model.
    outputSource: SDM>removeCollinearity.yml@97/rasters_selected

  SDM>runMaxent.yml@108|sdm_pred:
    type: File
    label: Predictions
    doc: MaxEnt habitat suitability prediction raster fitted using the selected model settings.
    outputSource: SDM>runMaxent.yml@108/sdm_pred

  SDM>rangePredictions.yml@68|range_predictions:
    type: File
    label: Variability of predictions
    doc: The variability of the 95% confidence of each prediction can be viewed on a map to show uncertainty.
    outputSource: SDM>rangePredictions.yml@68/range_predictions

  pipeline@121|default_output:
    type: string[]
    label: Taxa list
    doc: Taxa supplied to the pipeline and used for GBIF occurrence retrieval and model fitting.
    outputSource: pipeline@121

  data>getGBIFObservations>getGBIFObservations.yml@142|gbif_doi:
    type: string
    label: DOI of GBIF download
    doc: A permanent DOI assigned to this specific GBIF data download. Must be cited in any publication using these data — see [GBIF's citation guidelines](https://www.gbif.org/citation-guidelines).
    outputSource: data>getGBIFObservations>getGBIFObservations.yml@142/gbif_doi

  STAC>createCollection.yml@153|stac_collection:
    type: File
    label: STAC Collection
    doc: JSON file representing a STAC collection containing the provided GeoTIFFs
    outputSource: STAC>createCollection.yml@153/stac_collection

