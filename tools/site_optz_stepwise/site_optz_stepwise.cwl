#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Stepwise SURDES optimization with pmedians
doc:
  - |
    Description:
    Uses SURDES stepwise p-median optimization to add demand points to current monitoring sites using a supplied joint environmental and geographic distance matrix. All sites have the same condition value; custom selection conditions are not exposed.
  - |
    Authors:
    Francis van Oordt (https://orcid.org/0000-0002-8471-235X)
  - |
    References:
    Medina et al. (2013). Designing bryophyte surveys for an optimal coverage of diversity gradients.
    https://doi.org/10.1007/s10531-013-0574-5


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
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335
    # dockerImageId: conda-cwl-runner-local
    # dockerFile:
    #     $include: ../runners/cwl/conda-cwl.dockerfile

  EnvVarRequirement:
    envDef:
      CONDA_PKGS_DIRS: /conda-env-yml/pkgs
      CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
      CONDA_PACK_URL: $(inputs.condaPackURL)
      SCRIPT_LOCATION: /scripts
      SCRIPT_PATH: $(inputs.scriptPath)
      SCRIPT_STUBS_LOCATION: /script-stubs
      USERDATA_LOCATION: /userdata
      OUTPUT_LOCATION: "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)"
      PYTHONUNBUFFERED: "1"

  ResourceRequirement:
    ramMin: 5120

baseCommand: ["bash", "-c"]
arguments:
  - |
    log=$OUTPUT_LOCATION/logs.txt
    rm -f $log
    touch "$log"
    tail -f "$log" &
    tailPid=$!
    cleanupTail() {
      kill "$tailPid" 2>/dev/null
      wait "$tailPid" 2>/dev/null
    }
    trap cleanupTail EXIT

    mkdir -p /conda-env-yml/pkgs /conda-env-yml/envs

    cat > "$OUTPUT_LOCATION/input.json" <<'JSON'
    ${
      return JSON.stringify({
        country_polygon: inputs.country_polygon ? inputs.country_polygon.path : null,
        iters: inputs.iters,
        rasters: (inputs.rasters || []).map(function(file) { return file.path; }),
        locations_csv: inputs.locations_csv ? inputs.locations_csv.path : null,
        mdist: inputs.mdist ? inputs.mdist.path : null,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" >> "$log"
    echo "Inputs:" >> "$log"
    cat "$OUTPUT_LOCATION/input.json" >> "$log"

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "site_optz_stepwise__site_optz_stepwise" \
    "channels: [conda-forge, r]
    dependencies: [r-rjson, r-terra, r-tidyterra, r-ggplot2, r-dplyr]
    name: site_optz_stepwise__site_optz_stepwise
    " /conda-envs "$CONDA_PACK_URL" >> "$log" 2>&1

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $OUTPUT_LOCATION \
      "$SCRIPT_LOCATION/$SCRIPT_PATH" \
      >> "$log" 2>&1
    scriptExitCode=$?
    echo "Script exited with code $scriptExitCode" >> "$log"

    if [[ "$OUTPUT_LOCATION" != "$(runtime.outdir)" ]]; then
      echo "Copying results from run folder to CWL output directory" >> "$log"
      cp -a "$OUTPUT_LOCATION"/. "$(runtime.outdir)"/
    fi

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh site_optz_stepwise__site_optz_stepwise /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  country_polygon:
    type: File?
    label: Study-area polygon
    doc: Study-area boundary used for the output map.
    default: study_area.gpkg

  iters:
    type: int?
    label: Algorithm Iterations
    doc: Positive integer number of demand points to add. Must not exceed the number of rows with vini = 0. For example, 40 current sites and 60 demand points allow at most 60 additions. More iterations take longer.
    default: 30

  rasters:
    type: File[]?
    label: Environmental rasters
    doc: Environmental GeoTIFFs used upstream to produce the joint matrix. Retained for pipeline compatibility; this step reads the matrix directly.
    default:
    - predictor1.tiff
    - predictor2.tiff

  locations_csv:
    type: File?
    label: Sampling locations
    doc: Path to one CSV with lon and lat in WGS84 decimal degrees (EPSG:4326), and vini: 1 for current sites, 0 for demand points. Input coordinates always use WGS84, independently of the selected processing CRS.
    default: /scripts/site_optz_stepwise/site_optz_stepwise_EXAMPLE_samp_loc_peru.csv

  mdist:
    type: File?
    label: Joint distance matrix
    doc: CSV matrix produced by the Distance matrix step by multiplying environmental and geodesic distance entries. It must be symmetric with a zero diagonal and use the same site order as the sampling CSV. This step divides entries by their maximum before SURDES, which internally caps distances at 1.
    default: mdist.csv



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
    default: site_optz_stepwise/script_site_optz_stepwise.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  point_sel_out:
    type: File
    label: Selection of demand points
    doc: CSV of newly selected demand points in selection order, including lon, lat, vini, site_row (original CSV row, starting at 1), selected, selection_order, and status. Current sites are excluded.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "point_sel");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  uncov_out:
    type: File
    label: Uncovered variability
    doc: CSV with iteration and uncovered_variability, calculated as the sum of SURDES p-median scores at each iteration. This diagnostic is not a percentage of biodiversity represented and is not guaranteed to decrease monotonically.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "uncov");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  surdes_uncov_out:
    type: File
    label: Uncovered variability plot
    doc: PNG showing the sum of SURDES p-median scores at each iteration. Inspect alongside the selected sites; this diagnostic is not a percentage of biodiversity represented.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "surdes_uncov");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  surdes_map_out:
    type: File
    label: Map for selected points
    doc: PNG showing current sites, unselected demand points, and selected demand points in different colours.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "surdes_map");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  sites_gpkg_out:
    type: File
    label: Sampling sites GeoPackage
    doc: GeoPackage containing all input sites in WGS84 with vini, site_row, selected, selection_order, and status (Current, Demand, or Selected). Use status for viewer styling; automatic colours depend on the viewer.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sites_gpkg");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
