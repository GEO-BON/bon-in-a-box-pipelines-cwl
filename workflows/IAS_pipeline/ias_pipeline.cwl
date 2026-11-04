cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Invasive alien species
doc:
  - |
    Description:
    ## Introduction 
    Invasive alien species are a major threat to biodiversity. Reducing the rates of introduction and establishment of invasive alien species is an important component of Target 6, indicator 6.1 of the Kunming Montreal Global Biodiversity Framework (GBF).
    
    The pipeline compiles national information on alien and invasive species and evaluates patterns across time from their first documented records. It combines national checklist data from the Global Register of Introduced and Invasive Species (GRIIS) or optionally user input national data with the Alien Species First Records database.
    
    The pipeline applies the Standardising and Integrating Alien Species data (SInAS) workflow to standardise and merge these source datasets. Species names, locations, habitats, occurrence information and first-record dates are standardised before the GRIIS and First Records data are merged. Species names and taxonomic classifications are checked against the GBIF taxonomic backbone. Records that cannot be fully standardised are documented in the pipeline's data-quality outputs.
    If users upload their own national data the species list will be used instead of the GRIIS checklist. If a first record column is provided in the national data the national first record data will be used instead of the First Records dataset for those species that have both.
    The pipeline creates an annual time series of invasive alien species first records for the selected country. A first record represents the first documented detection of a species; it does not necesarrily represent the year that the species was introduced, established, or became invasive.
    
    Depending on first-record completeness and the number of years containing records, the pipeline selects one of four approaches:
    - no modelling when the available data are too sparse;
    - a qualitative comparison of first-record and GBIF observation patterns;
    - a reduced set of quantitative models; or
    - the complete set of quantitative models.
    
    The quantitative approaches include a naive Poisson model, a constant-detection model, a Solow–Costello model, and a sampling model that uses annual GBIF record volume as an indirect proxy for observation effort. The outputs describe the assumptions, fit, estimated trend, interpretation, and limitations of each model. For more information about estimating introduction rates from first-record data, see McGeoch et al. (2023) and Buba et al. (2024).
    
    ## Uses
    This pipeline can be used to:
    - Compile and standardise national GRIIS and First Records data to produce a taxonomically standardised national dataset of alien and invasive
      alien species.
    
    - Identify unmatched, excluded, or potentially problematic records for
      data-quality review.
    
    - Summarize and examine temporal patterns in observed first records.
    - Compare models with different assumptions about detection and observation
      effort.
    
    - Support national assessment and reporting related to Target 6 of GBF.
    ## Pipeline limitations 
    * This pipeline cannot currently be run for the following countries because of
      unresolved source-data, checklist-name, or location-mapping issues: United
      States of America (USA), Belgium (BEL), Thailand (THA), Eswatini (SWZ),
      Hungary (HUN), and Norway (NOR).
    
    * Annual GBIF record counts are used as an indirect proxy for changing
      observation effort. GBIF record volume is not a direct measurement of
      invasive alien species survey effort.
    
    * Model results must be interpreted with caution, please read the model interpretation outputs and papers listed below for guidance.
    * Automated taxonomic and location standardisation cannot resolve every
      record. Users should review the data-quality, unmatched-value and
      excluded-record outputs before interpreting results.
    
    * When a first-record date is supplied as a range, the pipeline uses its mean
      year. This estimated year does not represent a precisely documented
      detection date.
    
    * The results depend on the versions and coverage of the underlying GRIIS,
      First Records, GBIF, and configuration data.
    
    
    ## Before you start 
    A free GBIF account is required to obtain the GBIF observation data used by this pipeline. Add your GBIF username, password, and account email address to the `runner.env` file using the following environment variables: `GBIF_USER`, `GBIF_PWD`, and `GBIF_EMAIL`.
    
    Users should note the versions of the source databases and workflow used for an analysis. Any modifications to the workflow, configuration tables, or source data should also be reported to support transparency and reproducibility.
    
    If a national dataset is being uploaded by the user ensure that the column names match what you include in the input form. Review the unmatched-value, excluded-record, taxonomic-matching, merge-conflict, and other data-quality outputs before interpreting the results.
  - |
    Authors:
    Rachel Mason (https://orcid.org/0000-0003-2692-9902)
    Saxbee Affleck (https://orcid.org/0009-0007-4589-887X)
    Manuela Gómez-Suárez (https://orcid.org/0000-0002-6100-9207)
    Hanno Seebens (https://orcid.org/0000-0001-8993-6419)
    Samara Manzin (samara.manzin@mcgill.ca, https://orcid.org/0009-0005-9134-9981)
    Melodie McGeoch (https://orcid.org/0000-0003-3388-2241)
  - "External link: https://doi.org/10.5281/zenodo.17727120"
  - |
    References:
    Buba et al., (2024)
    https://doi.org/10.1111/geb.13859

    Buba (2024)
    https://doi.org/10.32614/CRAN.package.alien

    McGeoch et al., (2023)
    https://doi.org/10.1111/conl.12981

    Seebens & Gomez-Suarez (2025)
    https://doi.org/10.5281/zenodo.17727120


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement
  MultipleInputFeatureRequirement:
    class: MultipleInputFeatureRequirement

inputs:
  #################
  # Script inputs #
  #################
  pipeline@41:
    label: Country name
    doc: >
      Name of the country for the Invasive Alien Species analysis.
      
      This pipeline cannot currently be run for the following countries because of unresolved source-data, checklist-name, or location-mapping issues: United States of America (USA), Belgium (BEL), Thailand (THA), Eswatini (SWZ), Hungary (HUN), and Norway (NOR).
    type:
      type: record
      name: country
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

  pipeline@73:
    type: int?
    label: Start year
    doc: Start year for which to get GBIF observations. These will be used as a proxy for sampling effort in the given country.
    default: 1970

  pipeline@74:
    type: int?
    label: End year
    doc: End year for which to get GBIF observations. These will be used as a proxy for sampling effort in the given country.
    default: 2025

  pipeline@97:
    type: File?
    label: National checklist (optional)
    doc: >
      Optional national checklist CSV file. This file should contain a column containing species scientific names and optionally a column containing associated year of first recorded introduction.
      
      Leave empty to use the GRIIS and First Records datasets for the selected country.

  pipeline@98:
    type: string?
    label: Species column (optional)
    doc: >
      Exact column name containing scientific species names. 
      
      Required only when a checklist is uploaded.

  pipeline@99:
    type: string?
    label: First record column (optional)
    doc: >
      Exact column name containing the first documented occurrence year in the selected country. 
      
      Required only when a checklist is uploaded; leave blank if not provided. Date standardisation occurs in data preparation step.

  pipeline@100:
    type: string?
    label: Dataset citation (optional)
    doc: Include citation for the national dataset. Defaults to user_input_data when blank.

  IAS>prepare_datasets.yml@80|kingdoms:
    type:
      type: array
      items:
        type: enum
        symbols:
          - PLANTAE
          - ANIMALIA
    label: Kingdoms
    doc: Kingdoms to retain in both the GRIIS and First Records datasets.
    default:
    - PLANTAE
    - ANIMALIA

  IAS>prepare_datasets.yml@80|habitats:
    type:
      type: array
      items:
        type: enum
        symbols:
          - TERRESTRIAL
          - FRESHWATER
          - FRESHWATER|BRACKISH
          - TERRESTRIAL|FRESHWATER
          - MARINE|FRESHWATER|BRACKISH
          - TERRESTRIAL|BRACKISH
          - TERRESTRIAL|FRESHWATER|BRACKISH
          - TERRESTRIAL|MARINE|FRESHWATER
          - TERRESTRIAL|MARINE|BRACKISH
          - MARINE|FRESHWATER
          - TERRESTRIAL|MARINE
    label: Habitat types
    doc: Habitat values to retain in both the GRIIS and First Records datasets.
    default:
    - TERRESTRIAL
    - FRESHWATER
    - FRESHWATER|BRACKISH
    - TERRESTRIAL|FRESHWATER
    - MARINE|FRESHWATER|BRACKISH
    - TERRESTRIAL|BRACKISH
    - TERRESTRIAL|FRESHWATER|BRACKISH
    - TERRESTRIAL|MARINE|FRESHWATER
    - TERRESTRIAL|MARINE|BRACKISH
    - MARINE|FRESHWATER
    - TERRESTRIAL|MARINE



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory?
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.

  runFolder:
    type: Directory?
    doc:
      Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script.
      If left blank, a temporary folder will be used and discarded after the run.

  environment:
    type: string?
    doc:
      Optional. URL (http/https) or file:// URI pointing to a BON in a Box runner.env
      file, necessary for scripts requiring credentials. If not provided, an empty one will be used.
      Relative paths are not supported.

  #################################################################
  # The following inputs should not be changed in a regular setup #
  #################################################################

  condaPackURL:
    type: string
    doc: Base URL to check for conda-pack environments.
    default: https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.



steps:
  prepareRunnerEnv:
    doc: 
      Copy or download environment file (runner.env) into a CWL output.
      This step is a patch to go around issue https://github.com/common-workflow-language/cwltool/issues/1842.
    when: $(inputs.environment != null)
    in:
      environment: environment
    out: [ environmentFile ]
    run:
      class: CommandLineTool
      requirements:
        NetworkAccess:
          networkAccess: true
        InlineJavascriptRequirement: { }
        EnvVarRequirement:
          envDef:
            RUNNER_ENV_URI: $(inputs.environment)
      baseCommand: [ bash, -c ]
      arguments:
        - |
          echo "Preparing runner.env..."
          
          if [[ "$RUNNER_ENV_URI" == http://* ||
                  "$RUNNER_ENV_URI" == https://* ||
                  "$RUNNER_ENV_URI" == file://* ]]; then
            if ! curl -fsSL "$RUNNER_ENV_URI" -o runner.env; then
              echo "ERROR: failed to download runner.env from $RUNNER_ENV_URI" >&2
              exit 1
            fi
            source runner.env
          else
            echo "ERROR: environment file input, BON in a Box's "runner.env", was not provided as an URI." >&2
            echo "Please use the format file:// or https://" >&2
            exit 1;
          fi
      inputs:
        environment:
          type: string
      outputs:
        environmentFile:
          type: File?
          outputBinding:
            glob: runner.env


  # This step prepares the environments for all the following steps
  preparePackedEnvs:
    when: $(inputs.envFolderWrite != null)
    run:
      class: CommandLineTool
      requirements:
        InplaceUpdateRequirement:
          inplaceUpdate: true
        NetworkAccess:
          networkAccess: true
        InlineJavascriptRequirement: {}
        InitialWorkDirRequirement:
          listing: |
            ${
              return [
                { entry: inputs.envFolderWrite, writable: true },
                {
                  entry: { "class": "Directory", "basename": "conda-env-yml", "listing": [] },
                  entryname: "/conda-env-yml",
                  writable: true
                }
              ].concat(
                inputs.runFolderWrite
                  ? [{ entry: inputs.runFolder, writable: true }]
                  : []
              );
            }
        DockerRequirement:
          dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335
        EnvVarRequirement:
          envDef:
            CONDA_PKGS_DIRS: /conda-env-yml/pkgs
            CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
            SCRIPT_STUBS_LOCATION: /script-stubs
            OUTPUT_LOCATION: "$(inputs.runFolderWrite ? inputs.runFolderWrite.path : runtime.outdir)"
            CONDA_PACK_URL: $(inputs.condaPackURL)
      baseCommand: [bash, -c]
      arguments:
        - |
          echo "Exporting all environments"
          mkdir -p "$OUTPUT_LOCATION" "$CONDA_PKGS_DIRS" /conda-env-yml/envs
          
          function getPackedEnv {
            condaEnvName=$1
            condaEnvYml=$2
            # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context
            dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName
            mkdir -p "$dedicatedEnvFolder"
            
            echo "Exporting $condaEnvName..."
            source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh "$OUTPUT_LOCATION" "$condaEnvName" \
              "$condaEnvYml" "$dedicatedEnvFolder" "$CONDA_PACK_URL" --noActivate
            source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh "$condaEnvName" "$dedicatedEnvFolder"
            echo "Done."
          }
          export -f getPackedEnv

          bash -c 'getPackedEnv "IAS__download_firstrecords" "channels: [conda-forge, r]
          dependencies: [r-jsonlite, r-dplyr, r-duckdb, r-rjson, r-stringr, r-openxlsx]
          name: IAS__download_firstrecords
          "'
          
          bash -c 'getPackedEnv "IAS__download_griischecklist" "channels: [conda-forge, r]
          dependencies: [r-xml, r-dplyr, r-stringr, r-readr, r-tidyrss, r-tidyr, r-rvest, r-rjson,
            r-readxl, r-countrycode]
          name: IAS__download_griischecklist
          "'
          
          bash -c 'getPackedEnv "IAS__merge_datasets" "channels: [conda-forge, r]
          dependencies: [r-base, r-rjson]
          name: IAS__merge_datasets
          "'
          
          bash -c 'getPackedEnv "IAS__summarise_ias" "channels: [conda-forge, r]
          dependencies: [r-dplyr, r-gt, r-readr, r-stringr, r-tibble, r-tidyr, r-rjson]
          name: IAS__summarise_ias
          "'
          
          bash -c 'getPackedEnv "IAS__prepare_datasets" "channels: [conda-forge, r]
          dependencies: [r-dplyr, r-jsonlite, r-duckdb, r-rjson, r-stringr, r-rgbif, r-tidyr,
            r-stringi, r-openxlsx]
          name: IAS__prepare_datasets
          "'
          
          bash -c 'getPackedEnv "IAS__model_data" "channels: [conda-forge, r]
          dependencies: [r-base, r-cli, r-dharma, r-dplyr, r-ggeffects, r-ggplot2, r-mass, r-metrics,
            r-purrr, r-remotes, r-rjson, r-scales, r-tibble, r-tidyr]
          name: IAS__model_data
          "'
          
          bash -c 'getPackedEnv "data__getGBIFObservations__get_GBIF_country_SQL" "channels: [conda-forge, r]
          dependencies: [r-rgbif, r-countrycode, r-readr, r-rjson]
          name: data__getGBIFObservations__get_GBIF_country_SQL
          "'
          
          bash -c 'getPackedEnv "IAS__import_national_checklist" "channels: [conda-forge, r]
          dependencies: [r-base, r-rjson]
          name: IAS__import_national_checklist
          "'
      inputs:
        envFolderWrite:
          type: Directory?
        runFolderWrite:
          type: Directory?
        condaPackURL:
          type: string
      outputs:
        envFolder:
          type: Directory
          outputBinding:
            glob: .
            outputEval: $(inputs.envFolderWrite)
    in:
      envFolderWrite: envFolder
      runFolder:
        source: runFolder
        valueFrom: "$({ class: 'Directory', location: (self ? self.location : '/tmp/cwl' ) + '/preparePackedEnvs' })"
      condaPackURL: condaPackURL
    out: [envFolder]

  IAS>download_firstrecords.yml@37:
    run: ../../tools/IAS/download_firstrecords.cwl
    in:
      country_name: pipeline@41
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__download_firstrecords' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__download_firstrecords/37' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [taxonomy_issues_out, firstrecords_cleaned_out]


  IAS>download_griischecklist.yml@38:
    run: ../../tools/IAS/download_griischecklist.cwl
    in:
      country_name: pipeline@41
      compendium_countries: { default: /scripts/IAS/compendiumCountries.xlsx }
      global_invasive_checklist: { default: /scripts/IAS/species_isInvasiveAnywhere.csv }
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__download_griischecklist' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__download_griischecklist/38' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [griis_checklist_out, griis_summary_out, griis_directory_out, all_data_summary_out, per_list_summary_out]


  IAS>merge_datasets.yml@52:
    run: ../../tools/IAS/merge_datasets.cwl
    in:
      country_name: pipeline@41
      griis_clean: IAS>prepare_datasets.yml@80/griis_clean_out
      first_records_clean: IAS>prepare_datasets.yml@80/first_records_clean_out
      national_clean: IAS>prepare_datasets.yml@80/national_clean_out
      full_taxa_list: IAS>prepare_datasets.yml@80/full_taxa_list_out
      cleaning_summary: IAS>prepare_datasets.yml@80/cleaning_summary_out
      qc_status: IAS>prepare_datasets.yml@80/qc_status_out
      unmatched_values: IAS>prepare_datasets.yml@80/unmatched_values_out
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__merge_datasets' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__merge_datasets/52' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [merged_dataset_out, data_quality_report_out, run_summary_out, merge_summary_out, merge_conflicts_out]


  IAS>summarise_ias.yml@76:
    run: ../../tools/IAS/summarise_ias.cwl
    in:
      merged_dataset: IAS>merge_datasets.yml@52/merged_dataset_out
      gbif_country_observations: data>getGBIFObservations>get_GBIF_country_SQL.yml@91/gbif_country_observations_out
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__summarise_ias' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__summarise_ias/76' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [ias_summary_out, ias_annual_summary_out, ias_summary_table_out]


  IAS>prepare_datasets.yml@80:
    run: ../../tools/IAS/prepare_datasets.cwl
    in:
      country_name: pipeline@41
      griis_checklist: IAS>download_griischecklist.yml@38/griis_checklist_out
      first_records: IAS>download_firstrecords.yml@37/firstrecords_cleaned_out
      global_invasive_checklist: { default: /scripts/IAS/species_isInvasiveAnywhere.csv }
      national_checklist: IAS>import_national_checklist.yml@96/national_checklist_out
      kingdoms: IAS>prepare_datasets.yml@80|kingdoms
      habitats: IAS>prepare_datasets.yml@80|habitats
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__prepare_datasets' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__prepare_datasets/80' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [global_invasive_matches_out, griis_clean_out, first_records_clean_out, national_clean_out, file_info_out, translated_locations_out, full_taxa_list_out, translated_event_dates_out, cleaning_summary_out, qc_status_out, unmatched_values_out, excluded_records_out]


  IAS>model_data.yml@81:
    run: ../../tools/IAS/model_data.cwl
    in:
      country_name: pipeline@41
      integrated_data: IAS>merge_datasets.yml@52/merged_dataset_out
      covariate_data: data>getGBIFObservations>get_GBIF_country_SQL.yml@91/gbif_country_observations_out
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__model_data' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__model_data/81' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [model_outputs_out, model_decision_out, data_summary_out, model_input_out, qualitative_plot_out, qualitative_interpretation_out, quantitative_plot_out]


  data>getGBIFObservations>get_GBIF_country_SQL.yml@91:
    run: ../../tools/data/getGBIFObservations/get_GBIF_country_SQL.cwl
    in:
      country_name: pipeline@41
      start_year: pipeline@73
      end_year: pipeline@74
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__get_GBIF_country_SQL' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__get_GBIF_country_SQL/91' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [gbif_country_observations_out]


  IAS>import_national_checklist.yml@96:
    run: ../../tools/IAS/import_national_checklist.cwl
    in:
      country_name: pipeline@41
      national_checklist: pipeline@97
      species_column: pipeline@98
      first_record_column: pipeline@99
      dataset_citation: pipeline@100
      envFolder:
        source: preparePackedEnvs/envFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__import_national_checklist' } : null)"
      envFolderWritable:
        default: false
      runFolder:
        source: runFolder
        valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IAS__import_national_checklist/96' } : null)"
      environment: prepareRunnerEnv/environmentFile
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [national_checklist_out]


outputs:
  pipeline@41|default_output_out:
    label: Country name
    doc: Name of the country for the Invasive Alien Species analysis.
    type:
      type: record
      name: country
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

  IAS>merge_datasets.yml@52|merged_dataset_out:
    type: File
    label: SInAS merged dataset
    doc: One record per standardised taxon-location-establishment combination.
    outputSource: IAS>merge_datasets.yml@52/merged_dataset_out

  IAS>merge_datasets.yml@52|data_quality_report_out:
    type: File
    label: SInAS data-quality report
    doc: Combined quality-control status, unmatched values, and merge conflicts, including the action taken for each issue.
    outputSource: IAS>merge_datasets.yml@52/data_quality_report_out

  IAS>prepare_datasets.yml@80|excluded_records_out:
    type: File
    label: SInAS excluded records
    doc: Complete source records excluded from the merge because their locations could not be standardised.
    outputSource: IAS>prepare_datasets.yml@80/excluded_records_out

  IAS>merge_datasets.yml@52|run_summary_out:
    type: File
    label: SInAS run summary
    doc: Preparation and merge record counts, warning counts, exclusions, and overall quality-control status.
    outputSource: IAS>merge_datasets.yml@52/run_summary_out

  IAS>model_data.yml@81|model_outputs_out:
    type: File
    label: Model outputs
    doc: Model assumptions, parameters, fit statistics, convergence status, estimated trend direction, interpretation, and caveats for every model option. First-record trends are not automatically equivalent to introduction trends.
    outputSource: IAS>model_data.yml@81/model_outputs_out

  IAS>model_data.yml@81|model_decision_out:
    type: File
    label: Modelling decision
    doc: Selected data scenario, adequacy criteria, supported level of inference, interpretation guidance, shared scope, and references.
    outputSource: IAS>model_data.yml@81/model_decision_out

  IAS>model_data.yml@81|data_summary_out:
    type: File
    label: Modelling data summary
    doc: Data-adequacy statistics for the selected country. First-record completeness is the percentage of GRIIS taxa flagged invasive anywhere that have a first-record year; it is not overall checklist completeness.
    outputSource: IAS>model_data.yml@81/data_summary_out

  IAS>model_data.yml@81|quantitative_plot_out:
    type: File
    label: Quantitative model comparison
    doc: Fitted annual discovery records from models with alternative detection assumptions. Compare fit statistics only among converged models fitted to the same country and time series.
    outputSource: IAS>model_data.yml@81/quantitative_plot_out

  IAS>model_data.yml@81|qualitative_plot_out:
    type: File
    label: Qualitative model plot
    doc: Descriptive comparison of annual IAS first records with the GBIF observation proxy. Similar patterns may indicate an observation-effort effect; this plot is not a corrected introduction-rate estimate.
    outputSource: IAS>model_data.yml@81/qualitative_plot_out

  IAS>model_data.yml@81|qualitative_interpretation_out:
    type: string
    label: Qualitative model interpretation
    doc: Interpretation selected from the fitted IAS-observation and survey-effort trend combination. A trend is classified as stable when its fitted time slope is not significant at alpha = 0.05.
    outputSource: IAS>model_data.yml@81/qualitative_interpretation_out

