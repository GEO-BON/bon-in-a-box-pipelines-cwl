#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: BRT
doc:
  - |
    Description:
    This script creates a Species Distribution Model (SDM) and uncertainty map based on using Boosted Regression Trees (BRTs) using the package SpeciesDistributionToolkit.jl and EvoTrees.jl
  - "Lifecycle tag: In review."
  - |
    Authors:
    Michael D. Catchen (https://orcid.org/0000-0002-6506-6487)


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
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-57a4a4a
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
        occurrence: inputs.occurrence ? inputs.occurrence.path : null,
        predictors: (inputs.predictors || []).map(function(file) { return file.path; }),
        bbox_crs: inputs.bbox_crs,
        water_mask: (inputs.water_mask || []).map(function(file) { return file.path; }),
        max_candidate_pseudoabsences: inputs.max_candidate_pseudoabsences,
        pseudoabsence_buffer: inputs.pseudoabsence_buffer,
        pa_proportion: inputs.pa_proportion,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" >> "$log"
    echo "Inputs:" >> "$log"
    cat "$OUTPUT_LOCATION/input.json" >> "$log"

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "" \
    "" /conda-envs "$CONDA_PACK_URL" >> "$log" 2>&1

    julia \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.jl \
      $OUTPUT_LOCATION \
      "$SCRIPT_LOCATION/$SCRIPT_PATH" \
      >> "$log" 2>&1
    scriptExitCode=$?
    echo "Script exited with code $scriptExitCode" >> "$log"

    if [[ "$OUTPUT_LOCATION" != "$(runtime.outdir)" ]]; then
      echo "Copying results from run folder to CWL output directory" >> "$log"
      cp -a "$OUTPUT_LOCATION"/. "$(runtime.outdir)"/
    fi

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh  /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  occurrence:
    type: File?
    label: Occurrence records
    doc: Presence records (TSV with lon and lat columns, in the CRS of the bounding box). Use cleaned records. Fewer than about 50 presences in the region give a very small test set and unreliable fit statistics.
    default: /output/data/getObservations/9f7d1cc148464cd0517e01c67af0ab5b/obs_data.tsv

  predictors:
    type: File[]?
    label: Predictor rasters
    doc: Environmental rasters (GeoTIFF) on the same grid (extent, resolution, CRS). Choose few variables that plausibly limit the species and avoid highly correlated ones. Only the first 5 are shown in the Environment space output.
    default: /output/foo/bar

  bbox_crs:
    label: Extent and CRS
    doc: Bounding box and CRS of the study area. Occurrences and rasters must be in this CRS. Choose an area that contains enough presences (see Occurrence records).
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

  water_mask:
    type: File[]?
    label: Water mask
    doc: A single land-cover raster on the same grid as the predictors. Cells with value 210 (open water) are excluded; all others are kept. Intended for terrestrial species.
    default: /output/foo/bar

  max_candidate_pseudoabsences:
    type: int?
    label: Candidate pseudoabsences
    doc: Maximum number of cells considered as pseudoabsence candidates, from which the pseudoabsences are then drawn. If the region has more valid cells (cells with data, outside the water mask) than this limit, a random subset of that size is used, so lowering it speeds up large regions. Otherwise, every valid cell that is not a presence is a candidate and the limit has no effect.
    default: 100000

  pseudoabsence_buffer:
    type: float?
    label: Pseudoabsence buffer
    doc: Minimum distance in kilometers between a pseudoabsence and any presence. Keep it well below the size of the study area, otherwise no candidate cell remains. Larger values make absences more distinct from presences but exclude nearby suitable habitat.
    default: 10.0

  pa_proportion:
    type: float?
    label: Pseudoabsence proportion
    doc: Number of pseudoabsences per presence (for example 2.4 gives 2.4 pseudoabsences for each presence). Higher values sample the environment more thoroughly but lower the share of presences in the test set, which lowers precision and PR AUC without the model being worse. Compare these statistics only between runs with the same value.
    default: 2.4



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
    default: SDM/BRT/fitBRT.jl

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  predicted_sdm_out:
    type: File
    label: Predicted SDM
    doc: >
      Map of the model's occurrence score. Higher means more suitable relative to the pseudoabsences. 
      It is not a calibrated probability and may fall outside 0 to 1: use it to compare locations, 
      not as an absolute likelihood.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "predicted_sdm");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  sdm_uncertainty_out:
    type: File
    label: SDM uncertainty
    doc: >
      Map of the variance predicted by the model for each cell (not a bootstrap uncertainty). 
      Higher values mean less certain scores: use it to down-weight or mask areas of the predicted map.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sdm_uncertainty");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  fit_stats_out:
    type: File
    label: Fit statistics
    doc: >
      Test-set statistics and optimal threshold: 
      - ROC AUC (0.5 is random, above 0.7 is acceptable), 
      - PR AUC (compare with the share of presences in the test set), 
      - MCC at the best threshold (0 is random, 1 is perfect). 
      
      
      Computed on one small random split, so treat as indicative. Check the warning output for suspicious values.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "fit_stats");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  range_out:
    type: File
    label: Range map
    doc: Binary map (1 is predicted suitable) obtained by applying the MCC-maximizing threshold to the Predicted SDM. It shows where the model predicts suitability, not confirmed presence, and depends on the pseudoabsence settings.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "range");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  pseudoabsences_out:
    type: File
    label: Pseudoabsences
    doc: Coordinates of the pseudoabsence points used to train and test the model. Check that they cover the environments of the study area and are not concentrated around the presences.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "pseudoabsences");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  env_corners_out:
    type: File
    label: Environment space
    doc: Plot of presences (blue) and pseudoabsences (green) in environment space, for the first 5 predictors. Presences in a distinct part of the cloud mean informative predictors; strong overlap means the model can hardly separate them.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "env_corners");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  tuning_out:
    type: File
    label: Tuning curve
    doc: >
      MCC as a function of the threshold between 0 and 1.
      
      
      The peak is the threshold used for the Range map. A good curve has one clear peak at an intermediate threshold,
      with an MCC well above 0.3. A flat curve, or a peak near 0 or 1, means weak separation or scores squeezed into
      a narrow range.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "tuning");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
