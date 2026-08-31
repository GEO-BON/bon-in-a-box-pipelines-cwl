cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: ProtConn Analysis with custom PAs
doc:
  - |
    Description:
    ## Introduction
    The Protected Connected Index (ProtConn) is a key indicator within the Kunming-Montreal Global Biodiversity Framework (GBF) to assess progress toward Goal A and Target 3, which aims to  protect 30% of the planet through well-connected networks by 2030. ProtConn quantifies the percentage of a country or region where protected areas are effectively connected, allowing  for species movement and ecological flow. 
    
    ProtConn measures how well a region is protected and connected (Saura et al. 2017, 2018). ProtConn is calculated by evaluating the spatial arrangement of protected areas to determine how easily species can move between them across  a landscape. It treats protected areas as "nodes" and potential movement between them as "links",  measuring the probability that a species with a given dispersal distance will be able to travel between protected areas. This probability is calculated between the nearest edge of adjacent protected areas with a negative exponential dispersal kernel with the input dispersal distance as the median, or where dispersal probability is 0.5. The final  ProtConn value is expressed as a percentage of the total study area, partitioned into percentages that account for connectivity within PAs, between different PAs, and across international borders. To learn more about the ProtConn method, see Saura et al. 2017, 2018, 2019. 
    ## Uses
    ProtConn can be used to assess current progress towards Goal A and Target 3 of the the GBF. The pipeline can also be used to compare the connectedness of different proposed protected areas, assisting with planning and design. The pipeline can be run with a combination of current protected areas from WDPA and user-input polygons of  proposed protected area sites, allowing users to evaluate different plans for protected area expansion.
    ## Pipeline limitations 
    * On larger datasets, the pipeline is slow and uses a lot of memory, especially with larger input dispersal distances. 
    * Currently, the pipeline does not take into account landscape resistance (ie. whether land between protected areas is easily traversed by species) 
    ## Before you start 
    No API keys are needed to run this pipeline.
    If you would like to run the pipeline with a custom polygon for your study area, input your file path starting from the user data folder into the "polygon of study area" input box  (ex: /userdata/study_area_polygon.gpkg).
    
    This pipeline requires an input file of protected areas. ensure your data is in GeoPackage format and input the file path into the "polygon of protected areas" input (ex: /userdata/my_PA_polygons.gpkg).
    If you would like to run the pipeline with WDPA data, or a combination of combination of custom protected area polygons and WDPA data, please use  the `ProtConn Analysis with WDPA` pipeline.
    
    
     Click [here](https://boninabox.geobon.org/indicator?i=ProtConn) for more information about 
     parameterizing and running the pipeline.
  - "Lifecycle tag: Reviewed."
  - |
    Authors:
    Jory Griffith (Pipeline development, jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)
    Guillaume Larocque (Pipeline development, guillaume.larocque@mcgill.ca, https://orcid.org/0000-0002-5967-9156)
    Laetitia Tremblay (Pipeline testing, debugging and documentation, laetita.tremblay@mcgill.ca, https://www.linkedin.com/in/laetitia-tremblay-b0619b273/)
    Jean-Michel Lord (Environment setup, technical support, standards review, jean-michel.lord@mcgill.ca, https://orcid.org/0009-0007-3826-1125)
  - |
    Reviewers:
    Santiago Saura (santiago.saura@upm.es)
    Oscar Godinez-Gomez (oscargodinezgome@ufl.edu)
    Camilo Andres Correa Ayram (correa.c@javeriana.edu.co)
    Teresa Goicolea (t.goicolea@gmail.com)
    Corey Ruha (coreyruha@gmail.com)
  - |
    References:
    Godínez-Gómez, O., Correa Ayram, C.A., Goicolea, T., Saura, S. 2026. Makurhini An R package for comprehensive analysis of landscape fragmentation and connectivity. Environmental Modelling & Software.
    null

    Saura, Santiago, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2017. “Protected Areas in the World’s Ecoregions: How Well Connected Are They?” Ecological Indicators 76:144–58.
    null

    Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2018. “Protected Area Connectivity: Shortfalls in Global Targets and Country-Level Priorities.” Biological Conservation 219:53–67.
    null

    Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2019. “Global Trends in Protected Area Connectivity from 2010 to 2018.” Biological Conservation 238:108183.
    null

    UNEP-WCMC and IUCN (2026), Protected Planet: The World Database on Protected Areas (WDPA), Cambridge, UK: UNEP-WCMC and IUCN.
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
  pipeline@36:
    label: Bounding box and CRS
    doc: >
      Select a country/region and a CRS to obtain the associated bounding box.
      
      The chosen CRS **must** be in a projected coordinate reference system (in meters) to calculate correct distances between protected areas. 
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

  pipeline@31:
    type: File[]?
    label: Polygon of study area (optional)
    doc: Polygon of the study area, in geopackage format. To use a custom study area, input the path to the file in userdata (e.g. /userdata/study_area_polygon.gpkg) and it will override the country polygon from the "Get country polygon" script. Leave blank to use country or region polygons pulled from the "Get country polygon" script. Protected areas outside of the country polygon will be cropped out.
    default: []

  pipeline@29:
    type: File[]?
    label: Polygon of protected areas
    doc: The protected areas of interest, in geopackage format. Add the path to the custom geopackage here (e.g. /userdata/my_protected_areas.gpkg). If you want to use World Database of Protected Areas (WDPA) data or a combination of WDPA data with custom data, use the "ProtConn analysis with WDPA" pipeline.
    default: []

  protconn_analysis>protconn_analysis.yml@8|date_column_name:
    type: string?
    label: Date column name (optional)
    doc: Name of the column in the user provided protected area file that specifies when the PA was created. Leave blank if your protected area file does not have a date column.

  pipeline@32:
    type: int[]?
    label: Distance analysis threshold
    doc: >
      Refers to the threshold distance (in meters) used to estimate if the areas are connected in a spatial analysis. This threshold represents the median dispersal probability (i.e. where the dispersal probability between patches is 0.5). Dispersal probability is calculated with an exponential decay function with increasing distance.
      
      Common dispersal distances that encompass a large majority of terrestrial species are 1000 meters (1km), 3000 meters (3km), 10,000 meters (10 km), and 100,000 meters (100 km; Saura et al. 2017).
      
      Note that the more distances included, the longer the pipeline will take to run and the more memory it will require. Additionally, larger dispersal distances will be more computationally intensive. 
    default:
    - 1000
    - 10000

  protconn_analysis>protconn_analysis.yml@8|time_series:
    type: boolean?
    label: Time series
    doc: Toggle on to calculate a time series ProtConn values based on date of PA establishment
    default: true

  protconn_analysis>protconn_analysis.yml@8|start_year:
    type: int?
    label: Start year (optional)
    doc: Year to start the time series. This input will only be used if the time series input is selected.
    default: 1980

  protconn_analysis>protconn_analysis.yml@8|years:
    type: int?
    label: Year for cutoff
    doc: Year for which you want ProtConn calculated (e.g. an input of 2000 will calculate ProtConn for only PAs that were designated before the year 2000). Leave blank if your protected area file does not have a date column. 
    default: 2025

  protconn_analysis>protconn_analysis.yml@8|year_int:
    type: int?
    label: Year interval (optional)
    doc: Year interval for the time series plot of ProtConn values (e.g. an input of 10 will calculate ProtConn for every 10 years). This input will only be used if the time series input is selected.
    default: 20

  protconn_analysis>protconn_analysis.yml@8|pa_size_threshold:
    type: float?
    label: PA size threshold
    doc: Size threshold for PAs, in meters squared. Protected areas smaller than this area will be removed. A threshold of 1km2 was used in Saura et al. 2017 because at larger scales, protected areas less than 1km2 (1000 m2) do not have a large impact on ProtConn values. Removing small protected areas significantly speeds up calculation and is recommended for large areas. Input a value of 0 to keep all protected areas.
    default: 1000

  protconn_analysis>protconn_analysis.yml@8|buffer:
    type: float?
    label: Transboundary buffer
    doc: Buffer for pulling transboundary protected areas (WDPA data only). The buffer will pull protected areas within that distance of the country border or bounding box in the unit of the coordinate reference system (meters or degrees). If pulling WDPA data with a custom bounding box, the buffer will not be applied.
    default: 0

  protconn_analysis>protconn_analysis.yml@8|include_na_dates:
    type: boolean?
    label: Include missing values for date
    doc: How missing values for date should be handled in the time series analysis. If the box is checked, protected areas with missing values for establishment date will be included in the time series analysis and assigned to the chosen value for start year. If not checked, these protected areas will be omitted from the time series analysis (note they will still be included in the main analysis).
    default: true



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

  protconn_analysis>protconn_analysis.yml@8:
    run: ../../tools/protconn_analysis/protconn_analysis.cwl
    in:
      study_area_polygon:
        source: [pipeline@31, data>load_polygons.yml@37/polygon]
        linkMerge: merge_flattened
      protected_area_polygon: pipeline@29
      buffer: protconn_analysis>protconn_analysis.yml@8|buffer
      date_column_name: protconn_analysis>protconn_analysis.yml@8|date_column_name
      crs: pipeline@36
      distance_threshold: pipeline@32
      pa_size_threshold: protconn_analysis>protconn_analysis.yml@8|pa_size_threshold
      years: protconn_analysis>protconn_analysis.yml@8|years
      time_series: protconn_analysis>protconn_analysis.yml@8|time_series
      include_na_dates: protconn_analysis>protconn_analysis.yml@8|include_na_dates
      start_year: protconn_analysis>protconn_analysis.yml@8|start_year
      year_int: protconn_analysis>protconn_analysis.yml@8|year_int
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/protconn_analysis__protconn_analysis/8' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [protected_areas, study_area_km2, protected_area_km2, protconn_result, result_plot, result_yrs_plot, result_yrs]


  data>load_polygons.yml@37:
    run: ../../tools/data/load_polygons.cwl
    in:
      polygon_type: { default: Country or region }
      country_region_bbox: pipeline@36
      buffer: { default: 0.0 }
      envFolder:
        source: prepareEnvironments/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/37' } : null)"
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [polygon, bbox_crs]


outputs:
  protconn_analysis>protconn_analysis.yml@8|protected_areas:
    type: File[]
    label: Protected areas
    doc: Protected areas polygons for the ProtConn calculation. Overlapping protected areas have been merged to speed up calculation.
    outputSource: protconn_analysis>protconn_analysis.yml@8/protected_areas

  protconn_analysis>protconn_analysis.yml@8|protconn_result:
    type: File
    label: ProtConn results
    doc: >
      The results of the ProtConn calculations. "Prot" and "Unprot" is the percentage of the study area that is 
            protected and unprotected, respectively. "ProtConn" is the percentage of the study area that is protected, and
            connected, ProtUnconn is the percentage that is protected but unconnected. "ProtConn Within" is the percentage
            of the landscape that is connected within a single protected area, i.e. the contribution to overall connectivity
            coming from within the protected area, without species having to traverse unprotected land. "ProtConn Contig"
            is the proportion connected through direct physical adjascency, capturing the value of neighboring or touching PAs.
    outputSource: protconn_analysis>protconn_analysis.yml@8/protconn_result

  protconn_analysis>protconn_analysis.yml@8|result_plot:
    type: File
    label: ProtConn result plot
    doc: Donut plot of the percentage of total area that is unprotected, protected and connected, and protected and unconnected for each input dispersal distance (in meters).
    outputSource: protconn_analysis>protconn_analysis.yml@8/result_plot

  protconn_analysis>protconn_analysis.yml@8|result_yrs:
    type: File
    label: ProtConn time series results
    doc: Table of the time series of ProtConn and ProtUnconn values, calculated at the time interval that is specified.
    outputSource: protconn_analysis>protconn_analysis.yml@8/result_yrs

  protconn_analysis>protconn_analysis.yml@8|result_yrs_plot:
    type: File[]
    label: ProtConn time series plot
    doc: Change in the percentage area that is protected and the percentage that is protected and connected over time, at the chosen time interval, compared to the Kunming-Montreal GBF goals.
    outputSource: protconn_analysis>protconn_analysis.yml@8/result_yrs_plot

