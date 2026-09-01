#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Protconn Analysis
doc:
  - |
    Description:
    This script calculates the Protected Connected Index (ProtConn) from protected area polygons using the MK_ProtConn function in the Makurhini package. This creates a distance matrix from protected area polygons and calculates ProtConn using dispersal probabilities between protected areas.
  - "Lifecycle tag: Reviewed."
  - |
    Authors:
    Jory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)
  - "External link: https://github.com/GEO-BON/biab-2.0/tree/main/scripts/protconn_analysis"
  - |
    References:
    Godínez-Gómez, O., Correa Ayram, C.A., Goicolea, T., Saura, S. 2026. Makurhini An R package for comprehensive analysis of landscape fragmentation and connectivity. Environmental Modelling & Software.
    https://doi.org/10.1016/j.envsoft.2026.106981

    Saura, Santiago, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2017. “Protected Areas in the World’s Ecoregions: How Well Connected Are They?” Ecological Indicators 76:144–58.
    https://doi.org/10.1016/j.ecolind.2016.12.047

    Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2018. “Protected Area Connectivity: Shortfalls in Global Targets and Country-Level Priorities.” Biological Conservation 219:53–67.
    https://doi.org/10.1016/j.biocon.2017.12.020

    Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2019. “Global Trends in Protected Area Connectivity from 2010 to 2018.” Biological Conservation 238:108183.
    https://doi.org/10.1016/j.biocon.2019.07.028

    UNEP-WCMC and IUCN (2026), Protected Planet: The World Database on Protected Areas (WDPA), Cambridge, UK: UNEP-WCMC and IUCN.
    https://doi.org/10.34892/6fwd-af11


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
                if(typeof item.replace === "function")
                  return item.replace(inputs.runFolder.path, runtime.outdir);
                else return item
              });
            } else if(typeof value.replace === "function") {
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
            : { // fallback
                entry: { "class": "Directory", "basename": "conda-envs", "listing": [] },
                entryname: "/conda-envs",
                writable: true
              }
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
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-eee5c95
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
        study_area_polygon: (inputs.study_area_polygon || []).map(function(file) { return file.path; }),
        protected_area_polygon: (inputs.protected_area_polygon || []).map(function(file) { return file.path; }),
        buffer: inputs.buffer,
        date_column_name: inputs.date_column_name,
        crs: inputs.crs,
        distance_threshold: inputs.distance_threshold,
        pa_size_threshold: inputs.pa_size_threshold,
        years: inputs.years,
        time_series: inputs.time_series,
        include_na_dates: inputs.include_na_dates,
        start_year: inputs.start_year,
        year_int: inputs.year_int,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "rbase" \
    "" /conda-envs $(inputs.condaPackURL) >> "$log" 2>&1

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log
  
    if [[ "$OUTPUT_LOCATION" != "$(runtime.outdir)" ]]; then
      echo "Copying results from run folder to CWL output directory" | tee -a $log
      cp -a "$OUTPUT_LOCATION"/. "$(runtime.outdir)"/
    fi

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  study_area_polygon:
    type: File[]?
    label: Polygon of study area
    doc: Polygon of the study area, in GeoPackage format. To use a custom study area, input the path to the file in the userdata folder (e.g. /userdata/study_area_polygon.gpkg).

  protected_area_polygon:
    type: File[]?
    label: Polygon of protected areas
    doc: The protected areas (PAs) of interest.

  buffer:
    type: float?
    label: Transboundary buffer
    doc: Buffer for pulling transboundary protected areas (WDPA data only). The buffer will pull protected areas within that distance of the country border or bounding box in the unit of the coordinate reference system (meters or degrees). If pulling WDPA data with a custom bounding box, the buffer will not be applied.
    default: 0

  date_column_name:
    type: string?
    label: Date column name
    doc: Name of the column in the user provided protected area file that specifies when the PA was created. Leave blank if only using WDPA data or your protected area file does not have a date column.

  crs:
    label: CRS
    doc: Object containing CRS.
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

  distance_threshold:
    type: int[]?
    label: Distance analysis threshold
    doc: >
      Refers to the threshold distance (in meters) used to estimate if the areas are connected in a spatial analysis. This threshold represents the median dispersal probability (i.e. where the dispersal probability between patches is 0.5). Dispersal probability is calculated with an exponential decay function with increasing distance.
      
      Common dispersal distances that encompass a large majority of terrestrial species are 1000 meters, 3000 meters, 10,000 meters, and 100,000 meters (Saura et al. 2017).
      
      Note that the more distances you include, the longer the pipeline will take to complete and the more memory it will require. Additionally, larger dispersal distances will be more computationally intensive.
    default:
    - 1000
    - 10000

  pa_size_threshold:
    type: float?
    label: PA size threshold
    doc: Size threshold for PAs, in meters squared. Protected areas smaller than this area will be removed. A threshold of 1km2 was used in Saura et al. 2017 because at larger scales, protected areas less than 1km2 (1000 m2) do not have a large impact on ProtConn values. Removing small protected areas significantly speeds up calculation and is recommended for large areas. To not PAs filter by size threshold, input a value of 0.
    default: 1000

  years:
    type: int?
    label: Year for cutoff
    doc: Year for which you want ProtConn calculated (e.g. an input of 2000 will calculate ProtConn for only PAs that were designated before the year 2000). Leave blank if only using WDPA data or your protected area file does not have dates. Note that if your protected area file doesn't have dates you cannot do the time series analysis.
    default: 2025

  time_series:
    type: boolean?
    label: Time series
    doc: Whether to calculate time series plot of ProtConn values based on date of PA establishment
    default: true

  include_na_dates:
    type: boolean?
    label: Include missing values for date
    doc: How missing values for date should be handled in the time series analysis. If the box is checked, protected areas with missing values for establishment date will be included in the time series analysis and assigned to the chosen value for start year. If not checked, these protected areas will be omitted from the time series analysis (note they will still be included in the main analysis).
    default: true

  start_year:
    type: int?
    label: Start year
    doc: Year for the time series plot to start. Missing dates for protected area establishment will be automatically assigned to this year for the time series analysis. Leave blank if time series is not selected.
    default: 1980

  year_int:
    type: int?
    label: Year interval
    doc: Year interval for the time series plot of ProtConn values (e.g. an input of 20 will calculate ProtConn for every 20 years by filtering out protected areas established before that year). The last year will always be the input year. Leave blank if time series is not selected.
    default: 20



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory?
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.

  envFolderWritable:
    type: boolean
    doc:
      Whether the envFolder should be writable. If false, the folder will be mounted read-only.
      In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run.
      envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.
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
    default: protconn_analysis/protconn_analysis.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  protected_areas_out:
    type: File[]
    label: Protected areas
    doc: Protected areas on which ProtConn has been calculated. Overlapping protected areas have been merged into one to speed up calculation. Protected areas less than the threshold size were also removed.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "protected_areas");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  study_area_km2_out:
    type: string
    label: Area of study area
    doc: Area of the study area in square kilometers
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "study_area_km2");
          return value;
        }

  protected_area_km2_out:
    type: string
    label: Area of protected areas
    doc: Total area of the protected areas in square kilometers
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "protected_area_km2");
          return value;
        }

  protconn_result_out:
    type: File
    label: ProtConn results
    doc: >
      The results of the ProtConn calculations. "Prot" and "Unprot" is the percentage of the study area that is protected and unprotected, respectively. "ProtConn" is the percentage of the study area that is protected, and connected, ProtUnconn is the percentage that is protected but unconnected. "ProtConn Within" is the percentage of the landscape that is connected within a single protected area, i.e. the contribution to overall connectivity coming from within the protected area, without species having to traverse unprotected land. "ProtConn Contig" is the proportion connected through direct physical adjascency, capturing the value of neighboring or touching PAs.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "protconn_result");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  result_plot_out:
    type: File
    label: ProtConn result plot
    doc: >
      Donut plot of the percentage of total area that is unprotected, protected-connected, and protected-unconnected for each input dispersal distance (in meters).
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "result_plot");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  result_yrs_plot_out:
    type: File[]
    label: ProtConn time series plot
    doc: Change in the percentage area that is protected and the percentage that is protected and connected over time, at the chosen time interval, compared to the Kunming-Montreal GBF goals.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "result_yrs_plot");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  result_yrs_out:
    type: File
    label: ProtConn time series results
    doc: Table of the time series of ProtConn and ProtUnconn values, calculated at the time interval that is specified
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "result_yrs");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
