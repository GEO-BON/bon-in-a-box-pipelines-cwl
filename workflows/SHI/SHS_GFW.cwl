cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Species Habitat Score
doc:
  - "Description:
    This pipeline measures the Species Habitat Score (SHS), for the species used as inputs. It uses the range maps, the elevation ranges and the habitat categories available from The International Union for Conservation of Nature (IUCN). Changes in the habitat are measured using the Global Forest Watch layers and soon other land cover layers will be added. For the specific case of Quebec it has range maps available from the Ministère de l’Environnement. The outputs are a table with the changes in the area of the habitat by year requested and a graph with a timeseries of these values. Rasters of the habitat available for each year can also be requested."
  - "Authors:
    Maria Isabel Arce-Plata (Pipeline development, https://orcid.org/0000-0003-4024-9268)
    Guillaume Larocque (Pipeline development, guillaume.larocque@mcgill.ca, https://orcid.org/0000-0002-5967-9156)"
  - "External link: https://github.com/GEO-BON/biab-2.0/tree/main/scripts/SHI"


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement

inputs:
  #################
  # Script inputs #
  #################
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

  pipeline@76:
    type: string[]
    label: Species
    doc: Scientific name of the species. Multiple species names can be specified, separated with a comma.
    default:
    - Myrmecophaga tridactyla

  data>getAreaOfHabitat.yml@80|r_range_map:
    type: File[]
    label: Range map (raster)
    doc: Raster with expected area for the species if choosing option "Raster"
    default:
    - null

  data>loadFromStac.yml@84|resampling:
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
    doc: Resampling method used when rescaling and/or reprojecting the raster layers. See [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) for description.
    default: near

  pipeline@93:
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

  data>getAreaOfHabitat.yml@80|buff_size:
    type: int
    label: Buffer for study area
    doc: Size of the buffer around the study area. If it is not defined it will be estimated as half of the total width of the study area.
    default: 0

  pipeline@90:
    type: File
    label: Study area
    doc: Custom polygon of study area used to mask output layers, in geopackage format. This input is for user's to input their own polygon rather than inputing a country/region.

  data>getAreaOfHabitat.yml@80|elev_buffer:
    type: int
    label: Elevation buffer
    doc: Elevation buffer in meters to add (or substract) to the reported species elevation range. Default is zero. Positive values will increase the range in that value in meters and negative values will reduce the range in that value.

  data>getAreaOfHabitat.yml@80|elevation_filter:
    type:
      type: enum
      symbols:
        - Yes
        - No
    label: Filter by elevation
    doc: If 'yes' an elevation filter using IUCN information is applied, if 'no' the range map is taken as the area of habitat.
    default: 'Yes'

  SHI>habitatChange_GFW.yml@67|max_forest:
    type: int[]
    label: Maximum forest cover percentage
    doc: Maximum tree cover percentage required for each species, based on suitable habitat of the species. Acts as a filter for the Global Forest Watch Data. If not available, use Map of Life Values (e.g. [https://mol.org/species/range/Saguinus_oedipus])
    default:
    - 100

  SHI>habitatChange_GFW.yml@67|t_0:
    type: int
    label: Start year
    doc: Year where the analysis should start. Starts in 2000, check the time interval available for the Global Forest Watch data at https://stac.geobon.org/collections/gfw-lossyear.
    default: 2000

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

  SHI>habitatChange_GFW.yml@67|time_step:
    type: int
    label: Time step
    doc: Temporal resolution for analysis given in number of years. To get values for the end year, time step should fit evenly into the given analysis range.
    default: 10

  data>loadFromStac.yml@84|aggregation:
    type:
      type: enum
      symbols:
        - first
        - min
        - max
        - mean
        - median
    label: Aggregation method
    doc: Method used to aggregate items when layers combining over time.
    default: first

  SHI>habitatChange_GFW.yml@67|t_n:
    type: int
    label: End year
    doc: Year where the analysis should end (it should be later than Initial time). It should be inside the time interval for the Global Forest Watch data at https://stac.geobon.org/collections/gfw-lossyear.
    default: 2020

  SHI>habitatChange_GFW.yml@67|min_forest:
    type: int[]
    label: Minimum forest cover percentage
    doc: Minimum tree cover percentage required for each species, based on suitable habitat of the species. Acts as a filter for the Global Forest Watch Data. If not available, use Map of Life Values (e.g. [https://mol.org/species/range/Saguinus_oedipus])
    default:
    - 50

  pipeline@79:
    type: int
    label: Spatial resolution
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
          
          bash -c 'exportEnv "data__getRangeMap" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-dplyr, r-tidyr, r-purrr, r-sf, r-stringr]
          name: data__getRangeMap
          "'
          
          bash -c 'exportEnv "SHI__habitatChange_GFW" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-dplyr, r-tidyr, r-purrr, r-terra, r-stars, r-sf, r-readr,
            r-geodata, r-gdalcubes, r-rredlist, r-stringr, r-tmaptools, r-ggplot2, r-rstac,
            r-lubridate, r-RCurl]
          name: SHI__habitatChange_GFW
          "'
          
          bash -c 'exportEnv "data__getAreaOfHabitat" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-rstac, r-dplyr, r-tidyr, r-purrr, r-terra, r-stars, r-sf,
            r-readr, r-geodata, r-gdalcubes, r-rredlist=1.0.0, r-stringr, r-httr2, r-geojsonsf,
            r-sp, r-lwgeom]
          name: data__getAreaOfHabitat
          "'
          
          bash -c 'exportEnv "data__loadFromStac" "channels: [conda-forge, r]
          dependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,
            r-rcurl, r-rjson, r-sf, r-stars, r-terra]
          name: data__loadFromStac
          "'
          
          bash -c 'exportEnv "data__getCountryPolygon" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-jsonlite, r-sf, r-remotes, r-dplyr, r-countrycode, r-httr2,
            r-jsonlite]
          name: data__getCountryPolygon
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

  data>getRangeMap.yml@65:
    run: ../../tools/getRangeMap.cwl
    in:
      species: pipeline@76
      expert_source: pipeline@77
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getRangeMap/65' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [sf_range_map]


  SHI>habitatChange_GFW.yml@67:
    run: ../../tools/habitatChange_GFW.cwl
    in:
      spat_res: pipeline@79
      crs: pipeline@93
      species: pipeline@76
      r_area_of_habitat: data>getAreaOfHabitat.yml@80/r_area_of_habitat
      sf_bbox: data>getAreaOfHabitat.yml@80/sf_bbox
      min_forest: SHI>habitatChange_GFW.yml@67|min_forest
      max_forest: SHI>habitatChange_GFW.yml@67|max_forest
      t_0: SHI>habitatChange_GFW.yml@67|t_0
      t_n: SHI>habitatChange_GFW.yml@67|t_n
      time_step: SHI>habitatChange_GFW.yml@67|time_step
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/SHI__habitatChange_GFW/67' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [img_shs_map, r_habitat_by_tstep, img_shs_timeseries, df_shs, df_shs_tidy, habitat_change_map]


  data>getAreaOfHabitat.yml@80:
    run: ../../tools/getAreaOfHabitat.cwl
    in:
      spat_res: pipeline@79
      crs: pipeline@93
      study_area: pipeline@90
      country_region_polygon: data>getCountryPolygon.yml@92/country_region_polygon
      buff_size: data>getAreaOfHabitat.yml@80|buff_size
      species: pipeline@76
      range_map_type: data>getAreaOfHabitat.yml@80|range_map_type
      sf_range_map: data>getRangeMap.yml@65/sf_range_map
      r_range_map: data>getAreaOfHabitat.yml@80|r_range_map
      elevation_filter: data>getAreaOfHabitat.yml@80|elevation_filter
      elev_buffer: data>getAreaOfHabitat.yml@80|elev_buffer
      rasters: data>loadFromStac.yml@84/rasters
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getAreaOfHabitat/80' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [r_area_of_habitat, sf_bbox, df_aoh_areas]


  data>loadFromStac.yml@84:
    run: ../../tools/loadFromStac.cwl
    in:
      bbox_crs: pipeline@93
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: { default: [earthenv_topography|elevation_min, earthenv_topography|elevation_max] }
      t0: { default: null }
      t1: { default: null }
      temporal_res: { default: null }
      spatial_res: pipeline@79
      resampling: data>loadFromStac.yml@84|resampling
      aggregation: data>loadFromStac.yml@84|aggregation
      study_area: pipeline@90
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/84' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters]


  data>getCountryPolygon.yml@92:
    run: ../../tools/getCountryPolygon.cwl
    in:
      bbox_crs: pipeline@93
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getCountryPolygon/92' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [country, region, country_region_polygon]


outputs:
  SHI>habitatChange_GFW.yml@67|r_habitat_by_tstep:
    type: File[]
    label: Habitat by time step
    doc: Raster of habitat by time step.
    outputSource: SHI>habitatChange_GFW.yml@67/r_habitat_by_tstep

  SHI>habitatChange_GFW.yml@67|img_shs_timeseries:
    type: File[]
    label: SHS time series
    doc: Figure showing a time series of SHS values per time step for each species.
    outputSource: SHI>habitatChange_GFW.yml@67/img_shs_timeseries

  SHI>habitatChange_GFW.yml@67|img_shs_map:
    type: File[]
    label: SHS map
    doc: Figure showing a map with changes in the habitat for the time range for each species.
    outputSource: SHI>habitatChange_GFW.yml@67/img_shs_map

  SHI>habitatChange_GFW.yml@67|df_shs:
    type: File[]
    label: SHS table
    doc: A TSV (Tab Separated Values) file containing Area Score, Connectivity Score and SHS by time step for each species. Percentage of change, 100% being equal to the reference year.
    outputSource: SHI>habitatChange_GFW.yml@67/df_shs

  SHI>habitatChange_GFW.yml@67|habitat_change_map:
    type: File[]
    label: SHS Map (raster)
    doc: Figure showing a map with changes in the habitat for the time range for each species (raster).
    outputSource: SHI>habitatChange_GFW.yml@67/habitat_change_map

