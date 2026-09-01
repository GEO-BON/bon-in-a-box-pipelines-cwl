#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Measure habitat change
doc:
  - |
    Description:
    This script loads the area of habitat of the species and the Global Forest Watch (GFW) layers to measure changes on the habitat of the species. It uses the layers the 2000 forest layer as a reference and removes the pixels from the loss layer of GFW data.
  - |
    Authors:
    Maria Isabel Arce-Plata (https://orcid.org/0000-0003-4024-9268)
    Guillaume Larocque (https://orcid.org/0000-0002-5967-9156)
  - "External link: https://github.com/GEO-BON/biab-2.0/tree/main/scripts/SHI"
  - |
    References:
    Jetz et al., Species Habitat Index [accessed on 24/8/2022](https://mol.org/indicators/habitat/background)
    null

    Jetz, W., McGowan, J., Rinnan, D. S., Possingham, H. P., Visconti, P., O’Donnell, B., & Londoño-Murcia, M. C. (2022). Include biodiversity representation indicators in area-based conservation targets. Nature Ecology & Evolution, 6(2), 123–126. [https://doi.org/10.1038/s41559-021-01620-y](https://www.nature.com/articles/s41559-021-01620-y)
    null


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
        spat_res: inputs.spat_res,
        crs: inputs.crs,
        species: inputs.species,
        r_area_of_habitat: (inputs.r_area_of_habitat || []).map(function(file) { return file.path; }),
        sf_bbox: (inputs.sf_bbox || []).map(function(file) { return file.path; }),
        min_forest: inputs.min_forest,
        max_forest: inputs.max_forest,
        t_0: inputs.t_0,
        t_n: inputs.t_n,
        time_step: inputs.time_step,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "SHI__habitatChange_GFW" \
    "channels: [conda-forge, r]
    dependencies: [r-rjson, r-dplyr, r-tidyr, r-purrr, r-terra, r-stars, r-sf, r-readr,
      r-geodata, r-gdalcubes, r-rredlist, r-stringr, r-tmaptools, r-ggplot2, r-rstac,
      r-lubridate, r-RCurl]
    name: SHI__habitatChange_GFW
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SHI__habitatChange_GFW /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  spat_res:
    type: float?
    label: output spatial resolution
    doc: Spatial resolution (in meters) for the output of the analysis.
    default: 1000

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

  species:
    type: string[]?
    label: species
    doc: Scientific name of the species. Multiple species names can be specified, separated with a comma.
    default:
    - Myrmecophaga tridactyla

  r_area_of_habitat:
    type: File[]?
    label: area of habitat
    doc: Raster file with the area of habitat for each species.
    default:
    - /scripts/SHI/myrmecophaga_tridactyla.tif

  sf_bbox:
    type: File[]?
    label: bounding box
    doc: Bounding box of the area of habitat for each species.
    default:
    - /scripts/SHI/Myrmecophaga tridactyla_range.gpkg

  min_forest:
    type: int[]?
    label: min forest
    doc: Minimum tree cover percentage required for each species, based on suitable habitat of the species. Acts as a filter for the Global Forest Watch Data. If not available, use Map of Life Values (e.g. [https://mol.org/species/range/Myrmecophaga-tridactyla]). For multiple species, input in the same order as input in species and separate with a comma.
    default:
    - 0

  max_forest:
    type: int[]?
    label: max forest
    doc: Maximum tree cover percentage required for each species, based on suitable habitat of the species. Acts as a filter for the Global Forest Watch Data. If not available, use Map of Life Values (e.g. [https://mol.org/species/range/Myrmecophaga-tridactyla]). For multiple species, input in the same order as input in species and separate with a comma.
    default:
    - 100

  t_0:
    type: int?
    label: initial time
    doc: Year where the analysis should start. Starts in 2000, check the time interval available for the Global Forest Watch data at https://stac.geobon.org/collections/gfw-lossyear.
    default: 2000

  t_n:
    type: int?
    label: final time
    doc: Year where the analysis should end (it should be later than Initial time). It should be inside the time interval for the Global Forest Watch data at https://stac.geobon.org/collections/gfw-lossyear.
    default: 2020

  time_step:
    type: int?
    label: time step
    doc: Temporal resolution for analysis given in number of years. To get values for the end year, time step should fit evenly into the given analysis range.
    default: 10



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
    default: SHI/habitatChange_GFW.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  img_shs_map_out:
    type: File[]
    label: SHS map (png)
    doc: Figure showing a map with changes in the habitat for the time range for each species (png).
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "img_shs_map");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  r_habitat_by_tstep_out:
    type: File[]
    label: Habitat by time step
    doc: Raster of habitat by time step.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "r_habitat_by_tstep");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  img_shs_timeseries_out:
    type: File[]
    label: SHS time series
    doc: Figure showing a time series of SHS values per time step for each species.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "img_shs_timeseries");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  df_shs_out:
    type: File[]
    label: SHS table
    doc: A TSV (Tab Separated Values) file containing Area Score, Connectivity Score and SHS by time step for each species. Percentage of change, 100% being equal to the reference year.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "df_shs");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  df_shs_tidy_out:
    type: File[]
    label: SHS table (long format)
    doc: A TSV (Tab Separated Values) file in long format containing Area Score (AS), Connectivity Score (CS) and Species Habitat Score (SHS) by time step for each species. The SHS is the mean value between the AS and CS. Percentage of change, 100% being equal to the reference year.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "df_shs_tidy");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  habitat_change_map_out:
    type: File[]
    label: SHS Map (raster)
    doc: Figure showing a map with changes in the habitat for the time range for each species (raster).
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "habitat_change_map");
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
