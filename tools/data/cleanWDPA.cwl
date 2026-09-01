#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Clean protected areas from WDPA API
doc:
  - |
    Description:
    This script cleans geometry issues in WDPA data and allows the user to filter based on the following criteria:
    - protected area legal status types (designated, inscribed, established)
    - inclusion of UNESCO Biosphere reserves
    - inclusion of marine protected areas
    - inclusion of areas with other effective area-based conservation measures (OECMs)
    - inclusion of protected areas represented as points
    - study area of interest
  - "Lifecycle tag: Core."
  - |
    Authors:
    Jory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)


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
        study_area_polygon: inputs.study_area_polygon ? inputs.study_area_polygon.path : null,
        protected_area_file: inputs.protected_area_file ? inputs.protected_area_file.path : null,
        crs: inputs.crs,
        status_type: inputs.status_type,
        include_unesco: inputs.include_unesco,
        buffer_points: inputs.buffer_points,
        include_marine: inputs.include_marine,
        include_oecm: inputs.include_oecm,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "data__cleanWDPA" \
    "channels: [conda-forge, r]
    dependencies: [r-rjson=0.2.23, r-sf=1.1-0, r-lwgeom, r-remotes, r-lubridate=1.9.5,
      r-tidyverse=2.0.0]
    name: data__cleanWDPA
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__cleanWDPA /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  study_area_polygon:
    type: File?
    label: Study area polygon
    doc: >
      Study area of interest in a GeoPackage file.

  protected_area_file:
    type: File?
    label: Protected areas file
    doc: >
      Optional, additionnal user-provided protected areas in GeoPackage format. When left blank, the script will only use the protected areas from WDPA.

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

  status_type:
    type:
      type: enum[]
      symbols:
        - Proposed
        - Inscribed
        - Adopted
        - Designated
        - Established
    label: PA legal status types to include
    doc: >
      Legal status types of protected areas to include.
      
      **Proposed:** The site is in the process of gaining recognition through legal or other effective means. It may still be managed as a protected area during this process.
      
      **Inscribed:** Protected areas designated under the UNESCO World Heritage Convention.
      
      **Adopted:** Specially protected areas of marine importance (SPAMI) created under the Barcelona convention,
      focusing on the protection of the marine environment and coastal region of the mediterranean.
      
      **Designated:** The site is legally recognized as a protected area. This implies specific binding commitment to
      conservation in the long term.
      
      **Established:** The site is recognized as protected area through other effective means. This implies long-term commitment to conservation, but without legal recognition.
    default:
    - Proposed
    - Inscribed
    - Adopted
    - Designated
    - Established

  include_unesco:
    type: boolean?
    label: Include UNESCO Biosphere reserves
    doc: >
      Check to include UNESCO Biosphere reserves. These serve as learning sites for sustainable development and combine biodiversity conservation with the sustainable use of natural resources and sustainable development. They may not be legally protected and may not be fully conserved, because they are often used for development or human settlement.
      
      Excluding these will limit the dataset to meeting stricter conservation standards.
    default: true

  buffer_points:
    type: boolean?
    label: Include protected area points
    doc: >
      Check to include protected area represented by points. These protected areas are reported as a single point rather than a polygon. If checked, this will create a circular protected area around the reported point that is equal to the reported area. If left unchecked, all protected areas represented as points will be removed.
      
      Protected area points with no reported area will be removed in all cases.
    default: true

  include_marine:
    type: boolean?
    label: Include marine and coastal protected areas
    doc: >
      Check to include marine and coastal protected areas.
      
      Note that the analysis is still limited to the bounds of the study area polygon. The chosen polygon needs to exceed the country land boundaries in order to really include marine protected areas.
    default: false

  include_oecm:
    type: boolean?
    label: Include OECMs
    doc: >
      Check to include areas with other effective area-based conservation measures (OECMs). These are not officially designated protected areas but are still achieving conservation outcomes.
    default: true



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
    default: data/cleanWDPA.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  study_area_clean_out:
    type: File
    label: Study area
    doc: Study area with fixed geometry
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "study_area_clean");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  protected_areas_clean_out:
    type: File
    label: Polygon of protected areas
    doc: Map of the protected areas in GeoPackage format, cleaned and filtered according to the input criteria.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "protected_areas_clean");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
