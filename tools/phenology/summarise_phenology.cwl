#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Summarise phenology
doc:
  - "Description:
    Summarises the yearly phenology data for a country (Europe only) using the copernicus data space ecosystem phenology layer. The script uses the openEO python client to send a job to openEO.
    The raster has values for the Plant Phenology Index (PPI), which is a vegetation index that helps estimate vegetation health and photosynthetic activity throughout the growing season.
    It is more directly related to plant phenology compared to other vegetation indices like NDVI, and does not saturate in high biomass conditions.
    It is computed with near infrared reflectance, which is strongly reflected by healthy vegetation. You can read more about the phenology layers [here](https://land.copernicus.eu/en/dataset-catalog).""
  - "Authors:
    Jory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)"


requirements:
  InlineJavascriptRequirement:
    expressionLib:
      - |
        function extractOutput(outputFiles, key) {
          if (!outputFiles || outputFiles.length === 0) return null;
          var value = JSON.parse(outputFiles[0].contents)[key]
          if (value === undefined) return null

          if(inputs.runFolder != null) {
            if(Array.isArray(value)) {
              value = value.map(function (item) {
                return item.replace(inputs.runFolder.path, runtime.outdir);
              });
            } else {
              value = value.replace(inputs.runFolder.path, runtime.outdir);
            }
          }
          return value;
        }
  InplaceUpdateRequirement:
    inplaceUpdate: true
  NetworkAccess:
    networkAccess: true
  InitialWorkDirRequirement:
    listing: |
      ${
        return [
          {
            entry: { "class": "Directory", "basename": "conda-env-yml", "listing": [] },
            entryname: "/conda-env-yml",
            writable: true
          }
        ].concat(
          inputs.envFolder
            ? {
                entry: inputs.envFolder,
                entryname: "/conda-envs",
                writable: inputs.envFolderWritable
              }
            : []
        ).concat(
          inputs.environment
            ? [{ entry: inputs.environment, entryname: "/runner.env" }]
            : []
        ).concat(
          inputs.runFolder
            ? [{ entry: inputs.runFolder, writable: true }]
            : []
        ).concat( // For debugging, overrides /scripts
          inputs.scripts_root
            ? [{ entry: inputs.scripts_root, entryname: "/scripts" }]
            : []
        );
      }


  DockerRequirement:
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:cwl-poc
    # dockerImageId: conda-cwl-runner-local
    # dockerFile:
    #     $include: ../runners/cwl/conda-cwl.dockerfile

  EnvVarRequirement:
    envDef:
      CONDA_PKGS_DIRS: /conda-env-yml/pkgs
      CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
      SCRIPT_LOCATION: /scripts
      SCRIPT_STUBS_LOCATION: /script-stubs
      USERDATA_LOCATION: /userdata
      OUTPUT_LOCATION: "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)"

baseCommand: ["bash", "-c"]
arguments:
  - |
    log=$OUTPUT_LOCATION/logs.txt
    rm -f $log
    mkdir -p /conda-env-yml/pkgs /conda-env-yml/envs

    cat > "$OUTPUT_LOCATION/input.json" <<'JSON'
    ${
      return JSON.stringify({
        bbox_crs: inputs.bbox_crs,
        study_area_polygon: inputs.study_area_polygon,
        start_year: inputs.start_year,
        end_year: inputs.end_year,
        season: inputs.season,
        bands: inputs.bands,
        aggregate_function: inputs.aggregate_function,
        spatial_resolution: inputs.spatial_resolution,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "phenology__summarise_phenology" \
    "channels: [conda-forge]
    dependencies: [openeo, pandas, geopandas, shapely]
    name: phenology__summarise_phenology
    " /conda-envs $(inputs.condaPackURL) >> "$log" 2>&1

    python3 \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.py \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log
  
    if [[ "$OUTPUT_LOCATION" != "$(runtime.outdir)" ]]; then
      echo "Copying results from run folder to CWL output directory" | tee -a $log
      cp -a "$OUTPUT_LOCATION"/. "$(runtime.outdir)"/
    fi

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh phenology__summarise_phenology /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  bbox_crs:
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

  study_area_polygon:
    type: File?
    label: Polygon of study area
    doc: Polygon of the study area of interest. Leave blank if you do not want to crop by a polygon and want to use the bounding box instead.

  start_year:
    type: string?
    label: Start year
    doc: Start date for phenology time series.
    default: '2017'

  end_year:
    type: string?
    label: End year
    doc: End date for phenology time series.
    default: '2024'

  season:
    type:
      type: enum
      symbols:
        - SEASON1
        - SEASON2
    label: Season of interest
    doc: >
      Season for which to run phenology analyses. Season 1 is the first growing season (spring and early summer)
      and season 2 is the second growing season (late summer and fall).
    default: SEASON1

  bands:
    type:
      type: enum[]
      symbols:
        - SOSD
        - EOSD
        - SOSV
        - EOSV
        - MAXD
        - MAXV
        - MINV
        - AMPL
        - LENGTH
        - LSLOPE
        - RSLOPE
        - SPROD
        - TPROD
        - QFLAG
    label: Bands
    doc: >
      Bands of interest for the calculations.
      - Start of season date (SOSD) - date when the vegetation growing season starts, when the PPI value reaches 25% of the season amplitude during the green-up period.
      - End of season date (EOSD) - the date when the vegetation growing season ends in the time profile of the PPI. Occurs when the PPI value reaches 15% of the season ampltitude during the green-down period.
      - Start of season value (SOSV) - the value of the PPI at the start of the vegetation growing season
      - End of season value (EOSV) - the value of the PPI at the end of the vegetation growing season
      - Season maximum value (MAXV) - the maximum (peak) value that the PPI reaches during the vegetation growing season
      - Season maximum date (MAXD) - date in the vegetation growing season where the mximum PPI is reached
      - Season minimum value (MINV) - average PPI of minima of left adn right sides of each season
      - Season amplitude (AMPL) - difference between the maximum and minimum PPI values reached during the season
      - Season length (LENGTH) - number of days between the start and end dates of the vegetation growing season
      - Slope of the green-up period (LSLOPE) - the rate of change in the values of PPI at the day when the vegetation growing season starts
      - Slope of the green-down period (RSLOPE) - the rate of change in tha values of PPO at the dat when the vegetatio growing season ends
      - Seasonal productivity (SPROD) - growing season integral computed as sum of all daily PPI values between the dates of the season start and end, minus their base level.
      - Total productivity (TPROD) - the growing season integral computed as sum of all daily PPI values between the dates of the season start and end
      - Quality flag (QFLAG) - quality indicator assisting users with the screening of clouds, shadows from clouds and topography, other dark areas, snow and water surfaces in their analysis of the PPI dataset
    default:
    - LENGTH
    - AMPL

  aggregate_function:
    type:
      type: enum
      symbols:
        - mean
        - min
        - max
    label: Aggregate function
    doc: Function to spatially aggregate the phenology data
    default: mean

  spatial_resolution:
    type: float?
    label: Spatial resolution
    doc: Spatial resolution, in meters, of the raster for plotting, leave blank to have the original spatial resolution of the layer (10m x 10m).
    default: 1000



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory?
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.

  envFolderWriteable:
    type: boolean
    doc:
      Whether the envFolder should be writable. If false, the folder will be mounted read-only.
      In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run.
      envFolderWriteable must be false when running in a workflow, but can be true when ran as an individual tool.
    default: true

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

  scriptPath:
    type: string
    doc: Path to the script, relative to scripts root.
    default: phenology/summarise_phenology.py

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  rasters:
    type: File[]
    label: Phenology rasters
    doc: >
      Rasters of phenology layers, with one raster per year in the input time range.
      Will either be the raw raster layers or resampled to the spatial resolution input by the user.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "rasters");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  timeseries:
    type: File
    label: Zonal statistics
    doc: Summarised values over the polygon of interest (mean, minimum, or maximum) for each year for each band of interest
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "timeseries");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
