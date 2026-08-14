#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Get area of habitat
doc:
  - |
    Description:
    This script loads the data needed to calculate the area of habitat for a species to use it for the Species Habitat Index(SHI)
  - |
    Authors:
    Maria Isabel Arce-Plata (https://orcid.org/0000-0003-4024-9268)
    Guillaume Larocque (https://orcid.org/0000-0002-5967-9156)
    Laetitia Tremblay (https://www.linkedin.com/in/laetitia-tremblay-b0619b273/)
  - |
    References:
    Brooks, T. M., Pimm, S. L., Akçakaya, H. R., Buchanan, G. M., Butchart, S. H. M., Foden, W., Hilton-Taylor, C., Hoffmann, M., Jenkins, C. N., Joppa, L., Li, B. V., Menon, V., Ocampo-Peñuela, N., & Rondinini, C. (2019). Measuring Terrestrial Area of Habitat (AOH) and Its Utility for the IUCN Red List. Trends in Ecology & Evolution, 34(11), 977–986. https://doi.org/10.1016/j.tree.2019.06.009 [https://www.sciencedirect.com/science/article/pii/S0169534719301892?via%3Dihub]
    null

    Jetz et al., Species Habitat Index [accessed on 24/8/2022](https://mol.org/indicators/habitat/background)
    null

    Jetz, W., McGowan, J., Rinnan, D. S., Possingham, H. P., Visconti, P., O’Donnell, B., & Londoño-Murcia, M. C. (2022). Include biodiversity representation indicators in area-based conservation targets. Nature Ecology & Evolution, 6(2), 123–126. https://doi.org/10.1038/s41559-021-01620-y [https://www.nature.com/articles/s41559-021-01620-y]
    null

    Chacón-Pacheco J. J., Figel J., Rojano C., Racero-Casarrubia J., Humanez-López E. & Padilla H. 2017. Modelo de distribución de Myrmecophaga tridactyla ID MAM-1. Instituto Alexander von Humboldt.[Biomodelos](http://biomodelos.humboldt.org.co/es/species/visor?species_id=6188)
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
        spat_res: inputs.spat_res,
        crs: inputs.crs,
        study_area: inputs.study_area ? inputs.study_area.path : null,
        country_region_polygon: inputs.country_region_polygon ? inputs.country_region_polygon.path : null,
        buff_size: inputs.buff_size,
        species: inputs.species,
        range_map_type: inputs.range_map_type,
        sf_range_map: (inputs.sf_range_map || []).map(function(file) { return file.path; }),
        r_range_map: (inputs.r_range_map || []).map(function(file) { return file.path; }),
        elevation_filter: inputs.elevation_filter,
        elev_buffer: inputs.elev_buffer,
        rasters: (inputs.rasters || []).map(function(file) { return file.path; }),
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "data__getAreaOfHabitat" \
    "channels: [conda-forge, r]
    dependencies: [r-rjson, r-rstac, r-dplyr, r-tidyr, r-purrr, r-terra, r-stars, r-sf,
      r-readr, r-geodata, r-gdalcubes, r-rredlist=1.0.0, r-stringr, r-httr2, r-geojsonsf,
      r-sp, r-lwgeom]
    name: data__getAreaOfHabitat
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

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__getAreaOfHabitat /conda-envs >> "$log" 2>&1

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

  study_area:
    type: File?
    label: study area
    doc: Path to the study area file. This file should be a polygon with a .gpkg extension or .shp (in this case do not forget to add the projection file to the folder)

  country_region_polygon:
    type: File?
    label: Polygon of country or region
    doc: A GeoPackage file containing the polygon of the chosen country or region of interest, in the specified crs.

  buff_size:
    type: int?
    label: buffer for study area
    doc: Size of the buffer around the study area. If it is not defined it will be estimated as half of the total width of the study area.
    default: 0

  species:
    type: string[]?
    label: species
    doc: Scientific name of the species. Multiple species names can be specified, separated with a comma.
    default:
    - Myrmecophaga tridactyla

  range_map_type:
    type:
      type: enum
      symbols:
        - Polygon
        - Raster
        - Both
    label: type of range map
    doc: Select type of range map according to the type of the source file: 1) polygon, 2) raster, 3) an intersection between the raster and polygon files.
    default: Polygon

  sf_range_map:
    type: File[]?
    label: range map (polygon)
    doc: One geopackage file with the polygon or polygons of the expected area for each species. If it is not available from scp_SHI_GetRangeMap.R then it is recommended to add a polygon with the limits of a species distribution model for the species.
    default:
    - /scripts/SHI/Myrmecophaga tridactyla_range.gpkg

  r_range_map:
    type: File[]?
    label: range map (raster)
    doc: Binary raster with expected area for the species or raster with values equal to 1 where the species is distributed and the rest is empty.
    default:
    - /scripts/SHI/myrmecophaga_tridactyla.tif

  elevation_filter:
    type:
      type: enum
      symbols:
        - Yes
        - No
    label: filter by elevation
    doc: If 'yes' an elevation filter using IUCN information is applied, if 'no' the range map is taken as the area of habitat.
    default: 'Yes'

  elev_buffer:
    type: int?
    label: elevation buffer
    doc: Elevation buffer in meters to add (or substract) to the reported species elevation range. Default is zero. Positive values will increase the range in that value in meters and negative values will reduce the range in that value.

  rasters:
    type: File[]?
    label: Rasters
    doc: rasters for elevation limits



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
    default: data/getAreaOfHabitat.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  r_area_of_habitat:
    type: File[]
    label: area of habitat
    doc: Raster file with the area of habitat.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "r_area_of_habitat");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  sf_bbox:
    type: File[]
    label: bounding box
    doc: Bounding box for the area of habitat.
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "sf_bbox");
          if (value === null) return null;
          var items = Array.isArray(value) ? value : [value];
          return items.map(function (value) {
            if (value === null) return null;
            return { class: "File", location: "file://" + value };
          });
        }

  df_aoh_areas:
    type: File
    label: table with size of areas of reference.
    doc: A TSV (Tab Separated Values) file containing the area of the range map loaded (area_range_map), the size of the study area (area_study_a), the area of the bounding box for the analysis (area_bbox_analysis), size of the buffer used to create the bounding box for the analysis, the size of the area of habitat(area_aoh).
    outputBinding:
      glob: "output.json"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "df_aoh_areas");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }


  logs:
    type: File
    outputBinding:
      glob: "logs.txt"
