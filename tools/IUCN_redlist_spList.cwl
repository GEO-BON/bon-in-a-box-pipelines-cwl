#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this step individually:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: IUCN combine species lists
doc:
  - "Description:
    This script returns the IUCN redlist species list for a country, filtered by taxonomic group, threat category, and species use, to be able to calculate the redlist index."
  - "Authors:
    Maria Camila diaz (maria.camila.diaz.corzo@usherbrooke.ca)
    Victor Julio Rincon (rincon-v@javeriana.edu.co)
    Laetitia Tremblay (laetitia.tremblay@mcgill.ca, http://www.linkedin.com/in/laetitia-tremblay-b0619b273)"


requirements:
  InlineJavascriptRequirement:
    expressionLib:
      - |
        function extractOutput(outputFiles, key) {
          if (!outputFiles || outputFiles.length === 0) return null;
          var value = JSON.parse(outputFiles[0].contents)[key]
          if (value === undefined) return null
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
            entry: inputs.envFolder,
            entryname: "/conda-envs",
            writable: inputs.envFolderWritable
          },
          {
            entry: { "class": "Directory", "basename": "conda-env-yml", "listing": [] },
            entryname: "/conda-env-yml",
            writable: true
          }
        ].concat(
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
    #     $include: ../runners/cwl/conda-cwl-dockerfile

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
        splist_taxon: inputs.splist_taxon,
        splist_country: inputs.splist_country,
        splist_use: inputs.splist_use,
        splist_threat: inputs.splist_threat,
        taxonomic_group: inputs.taxonomic_group,
        species_use: inputs.species_use,
        threat: inputs.threat,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "IUCNRedlistIndex__IUCN_redlist_spList" \
      "
        channels: [conda-forge, r]
        dependencies: [r-magrittr, r-dplyr, r-rredlist, r-this.path, r-rjson]
        name: IUCNRedlistIndex__IUCN_redlist_spList
      " /conda-envs $(inputs.condaPackURL) >> "$log" 2>&1

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IUCNRedlistIndex__IUCN_redlist_spList /conda-envs >> "$log" 2>&1

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  splist_taxon:
    type: File
    label: IUCN species list for a taxon group
    doc: Dataset with the list of species for a taxonomic group.

  splist_country:
    type: File
    label: IUCN species list for a country
    doc: Dataset with the list of species for a country.

  splist_use:
    type: File
    label: IUCN species list for use(s) or trade(s)
    doc: Dataset with the list of species for uses or trades

  splist_threat:
    type: File
    label: IUCN species list for a threat(s)
    doc: Dataset with the list of species for a threat category

  taxonomic_group:
    type: string[]
    label: Taxonomic group
    doc: The taxonomic group selected

  species_use:
    type: string[]
    label: Species use(s) or trade(s)
    doc: The species use or trade selected

  threat:
    type: string[]
    label: Species threat(s)
    doc: The threat category selected



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.
    default:
      class: Directory
      path: ./envs

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
    default: IUCNRedlistIndex/IUCN_redlist_spList.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  iucn_splist:
    type: File
    label: IUCN species list
    doc: Dataset with the list of species for the specified country for the specified filters. It contains the scientific name of the species and their most recent threat categorization according to the IUCN Red List.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "iucn_splist");
          if (value === null) return null;
          return { class: "File", location: "file://" + value };
        }

  number_species:
    type: int
    label: Number of species
    doc: Number of species in that country, filtered by taxon, threat, and use categories.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: |
        ${
          var value = extractOutput(self, "number_species");
          if (value === null) return null;
          return parseInt(value);
        }


  logs:
    type: File
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'logs.txt')"
