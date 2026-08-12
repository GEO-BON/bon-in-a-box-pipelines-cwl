#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Get protected areas
doc:
  - "Description:
    This script finds and saves a polygon of the country and state that is specified in the input and the polygon of protected areas in that region from the world database of protected areas (WDPA)."
  - "Lifecycle tag: Deprecated. This script is deprecated and will be removed in a future release.
Please use the new Python script `getWDPA.py` instead.
"
  - "Authors:
    Jory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)"
  - "External link: https://github.com/GEO-BON/biab-2.0/getProtectedAreasWDPA.R"
  - "References:
    UNEP-WCMC and IUCN (2024), Protected Planet. The World Database on Protected Areas (WDPA)[On-line], [October 2024], Cambridge, UK. UNEP-WCMC and IUCN. Available at. https://doi.org/10.34892/6fwd-af11 null"


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
        country: inputs.country,
        region: inputs.region,
        study_area_polygon: inputs.study_area_polygon,
        pa_input_type: inputs.pa_input_type,
        transboundary_distance: inputs.transboundary_distance,
        protected_area_file: inputs.protected_area_file,
        date_column_name: inputs.date_column_name,
        crs: inputs.crs,
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
  country:
    type: string?
    label: Country
    doc: Country of interest
    default: Colombia

  region:
    type: string?
    label: State/Province
    doc: State of interest

  study_area_polygon:
    type: File?
    label: Study area polygon
    doc: Study area of interest in a geopackage file

  pa_input_type:
    type:
      type: enum
      symbols:
        - WDPA
        - User input
        - Both
    label: Protected area input
    doc: Type of input for protected areas. Option "WDPA" uses protected areas from the World Database of Protected Areas. Option "User input" uses polygons input by the user. "Both" combines the WDPA protected areas and user input polygons.
    default: WDPA

  transboundary_distance:
    type: int?
    label: Transboundary distance
    doc: Distance (in meters) beyond the boundary of the study area to be included in the ProtConn index. Protected areas within this distance of the edge of the study area will be included in the calculation of ProtConn. A transboundary distance of 0 will only include protected areas in the study area.
    default: 0

  protected_area_file:
    type: string?
    label: Protected areas file
    doc: File path of the shapefile of protected areas (Leave blank if using data from WDPA). Must be in geopackage format.

  date_column_name:
    type: string?
    label: Date column name
    doc: Name of the column in the user provided protected area file that specifies when the PA was created (leave blank if only using WDPA data).

  crs:
    type: string?
    label: Coordinate reference system
    doc: Numerical value referring to the EPSG code (European Petroleum Survey Group) associated with the spatial reference system that will be used as a reference for the study area. This numerical value specifies the projection and geodetic datum used to define the coordinates and spatial representation of the data in the study area. For further information on coordinate systems and EPSG codes, you can access the official database on the EPSG website at https://epsg.org/home.html. The website provides documentation, resources, and tools for searching and understanding the EPSG codes used in various geospatial contexts.
    default: EPSG:4326



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
    default: data/getProtectedAreasWDPA.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  study_area:
    type: File
    label: Polygon of study area
    doc: The map of the study area
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "study_area");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  protected_areas:
    type: File
    label: Polygon of protected areas
    doc: The map of the protected areas within the study area
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "protected_areas");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  number_pas:
    type: string
    label: Number of protected areas
    doc: Number of protected areas in the country of interest
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "number_pas");
          return value;
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
