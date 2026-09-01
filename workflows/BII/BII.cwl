cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Biodiversity Intactness Index
doc:
  - |
    Description:
    ## Introduction 
    The Biodiversity Intactness Index (BII) is a metric designed to assess the degree to which ecosystems are intact and functioning relative to their natural state. It measures the abundance and diversity of species in a given area compared to what would be expected in an undisturbed ecosystem. The BII accounts for various factors, including habitat loss, fragmentation, and degradation, providing a comprehensive view of biodiversity health. A higher BII value indicates a more intact ecosystem with greater species diversity and abundance, while a lower value suggests significant ecological disruption. The biodiversity intactness index is a complimentary indicator in the GBF. The BII was created by the Natural History Museum and uses their PREDICTS database, which aggregates data from studies comparing terrestrial biodiversity at sites experiencing varying levels of human pressure. The database is used to establish a reference state using the biodiversity patterns in habitats with minimal disturbance levels. Then, it assigns sensitivity scores to each species based on their vulnerability to human pressure. Intactness is calculated by comparing the observed species abundance in a given area to what is expected under reference conditions with low human impact. It currently contains over 3 million records from more than 26,000 sites across 94 countries, representing a diverse array of over 45,000 plant, invertebrate, and vertebrate species.
    ## Uses 
    The Biodiversity Intactness Index is a complimentary indicator in the GBF. This pipeline can be used to calculate summary statistics and plot a time series of the 10km resolution BII layer for a given country or region. The BII is expressed as a percentage, with higher percentages being more intact.
    ## Pipeline limitations 
    The pipeline does not model the Biodiversity Intactness Index from the data, it calculates summary statistics over the 10 x 10 km BII layer pre-calcuated by the Natural History Museum calculated global layer. Therefore, you cannot customize the model or input custom data and you cannot increase the resolution of the layer. Additionally, because BII is a modelled data layer, the values may be less accurate in areas where there is a lack of data. To learn more about the PREDICTS database, visit the [page on the Natural History Museum website](https://www.nhm.ac.uk/our-science/research/projects/predicts/science.html).
    ## Before you start 
    There are no data or API keys required for this analysis. To view the global layer, go to our [STAC catalog](https://stac.geobon.org/viewer/bii_nhm/bii_nhm_10km_2020).
  - |
    Authors:
    Jory Griffith (Pipeline development, jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)
    Laetitia Tremblay (Pipeline documentation, laetita.tremblay@mcgill.ca, https://www.linkedin.com/in/laetitia-tremblay-b0619b273/)
  - |
    References:
    De Palma et al. 2024
    null

    Newbold et al. 2016
    null

    Bastion 2023
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
  data>load_polygons.yml@68|polygon_type:
    type:
      type: enum
      symbols:
        - Country or region
        - Polygon of bounding box
    label: Polygon type
    doc: Type of polygon to load. Country or region polygons, World database of Protected Areas (WDPA), Exclusive Economic Zones (EEZs), or a custom polygon of a bounding box.
    default: Country or region

  pipeline@67:
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

  zonal_statistics>zonal_stats.yml@25|summary_statistic:
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

  data>loadFromStac.yml@56|spatial_res:
    type: float?
    label: Spatial resolution (optional)
    doc: Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). If this is left blank it will use the native resolution of the rasters. If the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled using method "near".
    default: 0.00833

  pipeline@63:
    type: string?
    label: Start date (optional)
    doc: Start date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if using all available dates.

  pipeline@64:
    type: string?
    label: End date (optional)
    doc: End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if using all available dates.



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

          bash -c 'getPackedEnv "zonal_statistics__zonal_stats" "channels: [conda-forge, r]
          dependencies: [r-rjson, r-terra, r-dplyr, r-sf, r-exactextractr, r-tidyr]
          name: zonal_statistics__zonal_stats
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

  BII>BIIChange.yml@14:
    run: ../../tools/BII/BIIChange.cwl
    in:
      rasters: data>loadFromStac.yml@56/rasters_out
      start_year: pipeline@63
      end_year: pipeline@64
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/BII__BIIChange/14' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [bii_change_out]


  zonal_statistics>zonal_stats.yml@25:
    run: ../../tools/zonal_statistics/zonal_stats.cwl
    in:
      rasters: data>loadFromStac.yml@56/rasters_out
      bbox_crs: pipeline@67
      study_area_polygon: data>load_polygons.yml@68/polygon_out
      summary_statistic: zonal_statistics>zonal_stats.yml@25|summary_statistic
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/zonal_statistics__zonal_stats' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/zonal_statistics__zonal_stats/25' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [zonal_stats_out]


  data>loadFromStac.yml@56:
    run: ../../tools/data/loadFromStac.cwl
    in:
      bbox_crs: data>load_polygons.yml@68/bbox_crs_out
      stac_url: { default: https://stac.geobon.org/ }
      collections_items: { default: [bii_nhm] }
      t0: pipeline@63
      t1: pipeline@64
      temporal_res: { default: P5Y }
      spatial_res: data>loadFromStac.yml@56|spatial_res
      resampling: { default: near }
      aggregation: { default: first }
      study_area: data>load_polygons.yml@68/polygon_out
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/56' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [rasters_out]


  data>load_polygons.yml@68:
    run: ../../tools/data/load_polygons.cwl
    in:
      polygon_type: data>load_polygons.yml@68|polygon_type
      country_region_bbox: pipeline@67
      buffer: { default: 0.0 }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/68' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon_out, bbox_crs_out]


outputs:
  zonal_statistics>zonal_stats.yml@25|zonal_stats_out:
    type: File
    label: Summary statistic
    doc: Summary statistic over the polygon
    outputSource: zonal_statistics>zonal_stats.yml@25/zonal_stats_out

  BII>BIIChange.yml@14|bii_change_out:
    type: File[]
    label: Change in BII
    doc: Raster plot of change in BII. Higher numbers indicate greater BII loss.
    outputSource: BII>BIIChange.yml@14/bii_change_out

  data>load_polygons.yml@68|polygon_out:
    type: File
    label: Polygon
    doc: Polygons of the country, WDPA, EEZs for the country or region of interest
    outputSource: data>load_polygons.yml@68/polygon_out

  data>loadFromStac.yml@56|rasters_out:
    type: File[]
    label: Rasters
    doc: Output raster files in geotiff format.
    outputSource: data>loadFromStac.yml@56/rasters_out

