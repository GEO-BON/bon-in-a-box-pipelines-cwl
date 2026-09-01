#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Summarise Layers
doc:
  - |
    Description:
    This script summarizes multiple time series layers through space and time for a selected spatial resolution and time period using the specified aggregation methods. The resulting
    output will give you a spatially aggregated and temporally aggregated layer. 
  - |
    Authors:
    Samara Manzin (samara.manzin@mcgill.ca, https://orcid.org/0009-0005-9134-9981)


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
        layers: (inputs.layers || []).map(function(file) { return file.path; }),
        bbox_crs: inputs.bbox_crs,
        start_year: inputs.start_year,
        end_year: inputs.end_year,
        spatial_resolution: inputs.spatial_resolution,
        temporal_resolution: inputs.temporal_resolution,
        spatial_aggregation_method: inputs.spatial_aggregation_method,
        temporal_aggregation_method: inputs.temporal_aggregation_method,
        bands: inputs.bands,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "summarise_layers__summarise_layers" \
    "channels: [conda-forge, r]
    dependencies: [r-rjson, r-gdalcubes=0.7.1, r-terra, r-sf]
    name: summarise_layers__summarise_layers
    " /conda-envs $(inputs.condaPackURL) >> "$log" 2>&1

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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh summarise_layers__summarise_layers /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  layers:
    type: File[]?
    label: layers
    doc: Path to the raster layers to be summarized. The layers should be in GeoTIFF format. The layers should have the same spatial resolution and extent.

  bbox_crs:
    label: Bounding box and CRS
    doc: Bounding box and coordinate reference system defining the analysis extent.
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

  start_year:
    type: string?
    label: Start year
    doc: Start year for the time series.
    default: '2017'

  end_year:
    type: string?
    label: End year
    doc: End year for the time series.
    default: '2024'

  spatial_resolution:
    type: float?
    label: Spatial resolution
    doc: Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). If this is left blank it will attempt to use the native resolution of the rasters, however the input CRS units must match the units of the native resolution. If the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled with using method bilinear.
    default: 1000

  temporal_resolution:
    type: string?
    label: Temporal resolution
    doc: Temporal resolution in ISO 8601 duration format (e.g. "P1Y", "P1M", "P1D"). Leave blank to default to yearly ("P1Y").
    default: P1Y

  spatial_aggregation_method:
    type:
      type: enum
      symbols:
        - mean
        - median
        - max
        - min
        - sum
        - first
        - last
    label: Spatial aggregation method
    doc: Method to use for spatial aggregation of the raster layers. Options are "mean", "median", "max", "min", "sum", "first", "last".
    default: min

  temporal_aggregation_method:
    type:
      type: enum
      symbols:
        - mean
        - median
        - max
        - min
        - sum
        - first
        - last
    label: Temporal aggregation method
    doc: Method to use for temporal aggregation of the raster layers. Options are "mean", "median", "max", "min", "sum", "first", "last".
    default: mean

  bands:
    type: string?
    label: Bands
    doc: Name of bands to use for the aggregation.
    default: LAI



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
    default: summarise_layers/summarise_layers.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  rasters_out:
    type: File[]
    label: summarised rasters
    doc: >
      A single raster layer that is the result of the spatial and temporal aggregation of the input layers. The output is in GeoTIFF format.
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


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
