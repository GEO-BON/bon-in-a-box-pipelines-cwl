cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Species Habitat Index
doc:
  - |
    Description:
    This pipeline takes the outputs from the Species Habitat Score (SHS) pipeline and measures the Species Habitat Index for the species used as inputs, following the methodology proposed for Jetz et al. 2022 (https://cdn.mol.org/static/files/indicators/habitat/WCMC-species_habitat_index-15Feb2022.pdf). The index has two componentes an Area Score and a Connectivity score that are measured for the habitat of the required species (Species Habitat Score),  the Species Habitat Index is the average between those scores for the study area  Index. It can also have weight values assigned according to the proportion of the area of the habitat of the species that is located in the study area.
  - |
    Authors:
    Maria Isabel Arce-Plata (Pipeline development, https://orcid.org/0000-0003-4024-9268)
    Guillaume Larocque (Pipeline development, guillaume.larocque@mcgill.ca, https://orcid.org/0000-0002-5967-9156)
    Jaime Burbano-Girón (Pipeline development, https://orcid.org/0000-0001-6570-439X)
    Maria Camila Díaz (Pipeline development)
    Timothée Poisot (Pipeline development, https://orcid.org/0000-0002-0735-5184)
    Laetitia Tremblay (Maintenance, https://www.linkedin.com/in/laetitia-tremblay-b0619b273/)
  - "External link: https://github.com/GEO-BON/biab-2.0/tree/main/scripts/SHI"
  - |
    References:
    Brooks, T. M., Pimm, S. L., Akçakaya, H. R., Buchanan, G. M., Butchart, S. H. M., Foden, W., Hilton-Taylor, C., Hoffmann, M., Jenkins, C. N., Joppa, L., Li, B. V., Menon, V., Ocampo-Peñuela, N., & Rondinini, C. (2019). Measuring Terrestrial Area of Habitat (AOH) and Its Utility for the IUCN Red List. Trends in Ecology & Evolution, 34(11), 977–986. https://doi.org/10.1016/j.tree.2019.06.009 [https://www.sciencedirect.com/science/article/pii/S0169534719301892?via%3Dihub]
    null

    Jetz et al., Species Habitat Index [accessed on 24/8/2022](https://mol.org/indicators/habitat/background)
    null

    Jetz, W., McGowan, J., Rinnan, D. S., Possingham, H. P., Visconti, P., O’Donnell, B., & Londoño-Murcia, M. C. (2022). Include biodiversity representation indicators in area-based conservation targets. Nature Ecology & Evolution, 6(2), 123–126. https://doi.org/10.1038/s41559-021-01620-y [https://www.nature.com/articles/s41559-021-01620-y]
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
  pipeline@76:
    type: string[]?
    label: Species
    doc: Scientific name of the species. Multiple species names can be specified, separated with a comma.
    default:
    - Myrmecophaga tridactyla
    - Ateles fusciceps

  pipeline@118:
    label: Bounding box and CRS
    doc: Object containing the chosen bounding box and CRS.
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

  pipeline@112:
    type: File?
    label: Study area
    doc: Path to the study area file. This file should be a polygon with a .gpkg extension or .shp (in this case do not foget to add the projection file to the folder). This input is optional and can be used if the user wants to provide a custom study area.

  data>getAreaOfHabitat.yml@80|buff_size:
    type: int?
    label: Buffer for study area
    doc: Size of the buffer around the study area. If it is not defined it will be estimated as half of the total width of the study area.
    default: 0

  data>getAreaOfHabitat.yml@80|range_map_type:
    type:
      type: enum
      symbols:
        - Polygon
        - Raster
        - Both
    label: Type of range map
    doc: Select type of range map according to the type of the source file: 1) polygon, 2) raster, 3) an intersection between the raster and polygon files.
    default: Polygon

  pipeline@77:
    type:
      type: enum
      symbols:
        - MOL
        - IUCN
        - QC
    label: Source of expert range map
    doc: >
      Source of the expert range map for the species. The options are:
      Map of Life (MOL), International union for conservation of nature (IUCN) and range maps from the Ministère de l’Environnement du Québec (QC).
    default: IUCN

  data>getAreaOfHabitat.yml@80|r_range_map:
    type: File[]?
    label: Range map (raster)
    doc: Raster with expected area for the species if choosing option "Raster"
    default:
    - null

  SHI>habitatChange_GFW.yml@96|min_forest:
    type: int[]?
    label: Min forest
    doc: Minimum tree cover percentage required for each species, based on suitable habitat of the species. Acts as a filter for the Global Forest Watch Data. If not available, use Map of Life Values (e.g. [https://mol.org/species/range/Myrmecophaga-tridactyla]). For multiple species, input in the same order as input in species and separate with a comma.
    default:
    - 0

  SHI>habitatChange_GFW.yml@96|max_forest:
    type: int[]?
    label: Max forest
    doc: Maximum tree cover percentage required for each species, based on suitable habitat of the species. Acts as a filter for the Global Forest Watch Data. If not available, use Map of Life Values (e.g. [https://mol.org/species/range/Myrmecophaga-tridactyla]). For multiple species, input in the same order as input in species and separate with a comma.
    default:
    - 100

  SHI>habitatChange_GFW.yml@96|t_0:
    type: int?
    label: Initial time
    doc: Year where the analysis should start. Starts in 2000, check the time interval available for the [Global Forest Watch data](https://stac.geobon.org/collections/gfw-lossyear).
    default: 2000

  SHI>habitatChange_GFW.yml@96|t_n:
    type: int?
    label: Final time
    doc: Year where the analysis should end (it should be later than Initial time). It should be inside the time interval for the [Global Forest Watch data](https://stac.geobon.org/collections/gfw-lossyear).
    default: 2020

  SHI>habitatChange_GFW.yml@96|time_step:
    type: int?
    label: Time step
    doc: Temporal resolution for analysis given in number of years. To get values for the end year, time step should fit evenly into the given analysis range.
    default: 10

  pipeline@79:
    type: int?
    label: Output spatial resolution
    doc: >
      Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). 
      
      If this is left blank it will use the native resolution of the rasters. 
      
      If the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled with the resampling method chosen below.
    default: 1000

  data>getAreaOfHabitat.yml@80|elevation_filter:
    type:
      type: enum
      symbols:
        - Yes
        - No
    label: Filter by elevation
    doc: If 'yes' an elevation filter using IUCN information is applied, if 'no' the range map is taken as the area of habitat.
    default: 'Yes'

  data>getAreaOfHabitat.yml@80|elev_buffer:
    type: int?
    label: Elevation buffer
    doc: Elevation buffer in meters to add (or substract) to the reported species elevation range. Default is zero. Positive values will increase the range in that value in meters and negative values will reduce the range in that value.
    default: 0

  data>loadFromStac.yml@107|resampling:
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
    doc: Resampling method used when rescaling the raster layers. See [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) for description.
    default: near

  data>loadFromStac.yml@107|aggregation:
    type:
      type: enum
      symbols:
        - first
        - min
        - max
        - mean
        - median
    label: Aggregation method
    doc: Method used to aggregate items that overlay each other
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

          bash -c 'getPackedEnv "data__getRangeMap" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-dplyr, r-tidyr, r-purrr, r-sf, r-stringr]
          name: data__getRangeMap
          "'
          
          bash -c 'getPackedEnv "SHI__calculateSHI" "channels: [conda-forge, r]
          dependencies: [r-dplyr, r-purrr, r-readr, r-ggplot2, r-rjson]
          name: SHI__calculateSHI
          "'
          
          bash -c 'getPackedEnv "data__getAreaOfHabitat" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-rstac, r-dplyr, r-tidyr, r-purrr, r-terra, r-stars, r-sf,
            r-readr, r-geodata, r-gdalcubes, r-rredlist=1.0.0, r-stringr, r-httr2, r-geojsonsf,
            r-sp, r-lwgeom]
          name: data__getAreaOfHabitat
          "'
          
          bash -c 'getPackedEnv "SHI__habitatChange_GFW" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-dplyr, r-tidyr, r-purrr, r-terra, r-stars, r-sf, r-readr,
            r-geodata, r-gdalcubes, r-rredlist, r-stringr, r-tmaptools, r-ggplot2, r-rstac,
            r-lubridate, r-RCurl]
          name: SHI__habitatChange_GFW
          "'
          
          bash -c 'getPackedEnv "data__loadFromStac" "channels: [conda-forge, r]
          dependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,
            r-rcurl, r-rjson, r-sf, r-stars, r-terra]
          name: data__loadFromStac
          "'
          
          bash -c 'getPackedEnv "data__getCountryPolygon" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-jsonlite, r-sf, r-remotes, r-dplyr, r-countrycode, r-httr2,
            r-jsonlite]
          name: data__getCountryPolygon
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

  data>getRangeMap.yml@65:
    run: ../../tools/data/getRangeMap.cwl
    in:
      species: pipeline@76
      expert_source: pipeline@77
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getRangeMap' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getRangeMap/65' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [sf_range_map]


  SHI>calculateSHI.yml@68:
    run: ../../tools/SHI/calculateSHI.cwl
    in:
      df_shs_tidy: SHI>habitatChange_GFW.yml@96/df_shs_tidy
      df_aoh_areas: data>getAreaOfHabitat.yml@80/df_aoh_areas
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SHI__calculateSHI' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SHI__calculateSHI/68' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [df_shi, img_shi_timeseries, img_w_shi_timeseries]


  data>getAreaOfHabitat.yml@80:
    run: ../../tools/data/getAreaOfHabitat.cwl
    in:
      spat_res: pipeline@79
      crs: pipeline@118
      study_area: pipeline@112
      country_region_polygon: data>getCountryPolygon.yml@114/country_region_polygon
      buff_size: data>getAreaOfHabitat.yml@80|buff_size
      species: pipeline@76
      range_map_type: data>getAreaOfHabitat.yml@80|range_map_type
      sf_range_map: data>getRangeMap.yml@65/sf_range_map
      r_range_map: data>getAreaOfHabitat.yml@80|r_range_map
      elevation_filter: data>getAreaOfHabitat.yml@80|elevation_filter
      elev_buffer: data>getAreaOfHabitat.yml@80|elev_buffer
      rasters: data>loadFromStac.yml@107/rasters
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getAreaOfHabitat' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getAreaOfHabitat/80' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [r_area_of_habitat, sf_bbox, df_aoh_areas]


  SHI>habitatChange_GFW.yml@96:
    run: ../../tools/SHI/habitatChange_GFW.cwl
    in:
      spat_res: pipeline@79
      crs: pipeline@118
      species: pipeline@76
      r_area_of_habitat: data>getAreaOfHabitat.yml@80/r_area_of_habitat
      sf_bbox: data>getAreaOfHabitat.yml@80/sf_bbox
      min_forest: SHI>habitatChange_GFW.yml@96|min_forest
      max_forest: SHI>habitatChange_GFW.yml@96|max_forest
      t_0: SHI>habitatChange_GFW.yml@96|t_0
      t_n: SHI>habitatChange_GFW.yml@96|t_n
      time_step: SHI>habitatChange_GFW.yml@96|time_step
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SHI__habitatChange_GFW' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SHI__habitatChange_GFW/96' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [img_shs_map, r_habitat_by_tstep, img_shs_timeseries, df_shs, df_shs_tidy, habitat_change_map]


  data>loadFromStac.yml@107:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: pipeline@118
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: { default: [earthenv_topography|elevation_min, earthenv_topography|elevation_max] }
      t0: { default: null }
      t1: { default: null }
      temporal_res: { default: null }
      spatial_res: pipeline@79
      resampling: data>loadFromStac.yml@107|resampling
      aggregation: data>loadFromStac.yml@107|aggregation
      study_area: pipeline@112
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/107' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters]


  data>getCountryPolygon.yml@114:
    run: ../../tools/data/getCountryPolygon.cwl
    in:
      bbox_crs: pipeline@118
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getCountryPolygon' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getCountryPolygon/114' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [country, region, country_region_polygon]


outputs:
  pipeline@76|default_output:
    type: string[]
    label: Species
    doc: Scientific name of the species. Multiple species names can be specified, separated with a comma.
    outputSource: pipeline@76

  data>getRangeMap.yml@65|sf_range_map:
    type: File[]
    label: Expert range map
    doc: Polygon with expected area for the species.
    outputSource: data>getRangeMap.yml@65/sf_range_map

  SHI>habitatChange_GFW.yml@96|r_habitat_by_tstep:
    type: File[]
    label: Habitat by time step
    doc: Raster of habitat by time step.
    outputSource: SHI>habitatChange_GFW.yml@96/r_habitat_by_tstep

  SHI>habitatChange_GFW.yml@96|habitat_change_map:
    type: File[]
    label: Raster plot of forest change
    doc: Figure showing a map with changes in the habitat for the time range for each species.
    outputSource: SHI>habitatChange_GFW.yml@96/habitat_change_map

  SHI>habitatChange_GFW.yml@96|df_shs:
    type: File[]
    label: SHS table
    doc: A TSV (Tab Separated Values) file containing Area Score, Connectivity Score and SHS by time step for each species. Percentage of change, 100% being equal to the reference year.
    outputSource: SHI>habitatChange_GFW.yml@96/df_shs

  SHI>habitatChange_GFW.yml@96|img_shs_map:
    type: File[]
    label: SHS map
    doc: Figure showing a map with changes in the habitat for the time range for each species.
    outputSource: SHI>habitatChange_GFW.yml@96/img_shs_map

  SHI>habitatChange_GFW.yml@96|img_shs_timeseries:
    type: File[]
    label: SHS time series
    doc: Figure showing a time series of SHS values per time step for each species.
    outputSource: SHI>habitatChange_GFW.yml@96/img_shs_timeseries

  SHI>calculateSHI.yml@68|df_shi:
    type: File
    label: SHI table
    doc: Table with SHI and Steward’s SHI values for the complete area of study.
    outputSource: SHI>calculateSHI.yml@68/df_shi

  SHI>calculateSHI.yml@68|img_shi_timeseries:
    type: File
    label: SHI time series
    doc: Figure showing a time series of SHI values for each time step, 100% being equal to the reference year.
    outputSource: SHI>calculateSHI.yml@68/img_shi_timeseries

  SHI>calculateSHI.yml@68|img_w_shi_timeseries:
    type: File
    label: Steward’s SHI time series
    doc: Figure showing a time series of Steward’s SHI values for each time step. This is weighted by the proportion between the area of habitat for the study area and the total range map of the species. The reference year will start at the proportion of area of habitat in the study area. For example, if half of the species habitat is covered by the study area, the reference year’s value will be 50%.
    outputSource: SHI>calculateSHI.yml@68/img_w_shi_timeseries

