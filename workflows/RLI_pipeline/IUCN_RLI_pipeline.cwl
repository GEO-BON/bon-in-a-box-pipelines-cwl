cwlVersion: v1.2
class: Workflow

# To run this workflow:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Red List Index (RLI) pipeline
doc:
  - "Description:
    ## Introduction
    The Red List Index (RLI) shows trends in overall extinction risk for species, and is used to track progress towards reducing extinctions and biodiversity loss. Many species that move categories in the Red List do so because of revised taxonomy or improved knowledge. Therefore, looking at raw trends in Red List status can be misleading.  RLI models these trends to show overall changes the status of species groups that are  based only on genuine improvement or deterioriation.
    RLI has been widely integrated into various policy frameworks. Initially used to assess  progress towards the Convention on Biological Diversity’s 2010 target (Rodrigues, 2006),  it has since been employed in regional, thematic, and global assessments by bodies such as  the Intergovernmental Science-Policy Platform on Biodiversity and Ecosystem Services (IPBES),  the Global Environment Outlook, and others (Global Biodiversity Outlook, 2010).
    ## Uses
    The RLI is a key indicator for the UN Sustainable Development Goals, particularly Goal 15,  and is adopted by the Convention on Migratory Species and its agreements. It also serves as  a headline indicator for Goal A and Target 4 of the CBD’s Kunming-Montreal Global Biodiversity  Framework (CBD, 2022). Furthermore, by tracking the proportion of threatened species showing  status improvement, the RLI plays a central role in evaluating progress toward Goal A. Beyond  global trends, the RLI can be used to track changes in extinction risk across biogeographic realms,  political units, ecosystems, habitats, taxonomic groups, threat types, use or trades, and those  relevant to various international agreements and treaties (Butchart et al., 2004; Butchart et al., 2005).  The RLI supports progress towards several other goals and targets within the framework, such as Goal B,  Target 2, and Target 5, highlighting changes in extinction risk, including for utilized species.  By calculating the RLI in more specific contexts, such as for species impacted by pollution  (Target 7), species affected by invasive alien species (Target 6b), or those used for food and medicine  (Target 9b), the indicator provides targeted insights that directly inform efforts to meet these goals.  To read more about the RLI indicator in the Global Biodiversity Framework, see the metadata  [here](https://www.gbf-indicators.org/metadata/headline/A-3).
      
    The following are suggested inputs that are goal-specific:
    1. RLI of species impacted by pollution (Target 7)
      - Country: User's choice 
      - Taxonomic group: All 
      - Threat category: Pollution 
      - Species use: Do not filter by species use or trade
    
    2. RLI of species impacted by invasive alien species (Target 6b)
      - Country: User's choice
      - Taxonomic group: All
      - Threat category: Invasive alien species or diseases
      - Species use: Do not filter by species use or trade
    
    3. RLI of species used in food and medicine (Target 9b)
      - Country: User's choice
      - Taxonomic group: All
      - Threat category: Do not filter by threat category
      - Species use: Food - human, Food - animal, Medicine human & veterinary
    
    4. RLI for all utilized species (Goal B and Target 5)
      - Country: User's choice
      - Taxonomic group: All
      - Threat category: Do not filter by threat category
      - Species use: All
    
    5. RLI for species threatened by fisheries (Target 9)
      - Country: User's choice
      - Taxonomic group: All
      - Threat category: Fisheries
      - Species use: Do not filter by species use or trade
    
    ## Pipeline Limitations
    * On large or species-rich countries, as well as in threat or use categories that have a substantial  number of species, this pipeline takes a significant amount of time to retrieve the data.
    * This pipeline calculates the RLI for species only. Subspecies, subpopulations, and varieties are  excluded from the analysis.
    * The list of IUCN assessments extracted for this pipeline are only the ones done on a Global scale.  Regional scale assessments are excluded from the analysis.
    ## Before you start
    To use this pipeline, you’ll need an [IUCN token](https://api.iucnredlist.org/users/sign_up) to access  data on the International Union for Conservation of Nature (IUCN) Red List of Threatened Species.
    To interpret the results of this pipeline, it's important to understand the IUCN threat categorizations,  which are present throughout the outputs. Some results present these categorizations directly,  while others such as the Red List Index (RLI) calculations, use them to model changes in extinction  risk over time. 
    The IUCN Red List of Threatened Species defines the following threat categories:
      - EX: Exinct 
      - EW: Extinct in the wild 
      - RE: Regionally extinct 
      - CR: Critically endangered 
      - EN: Endangered 
      - VU: Vulnerable 
      - LR/cd: Lower risk 
      - Conservation dependent 
      - NT or LR/nt: Near threatened 
      - LC or LR/lc: Least concern 
      - DD: Data deficient
    
    (IUCN, 2025)"
  - "Authors:
    Victor Julio Rincon (Pipeline development, rincon-v@javeriana.edu.co)
    Maria Camila Diaz (Pipeline development, maria.camila.diaz.corzo@usherbrooke.ca)
    Laetitia Tremblay (Pipeline development, laetitia.tremblay@mcgill.ca, https://www.linkedin.com/in/laetitia-tremblay-b0619b273/)
    Jory Griffith (Pipeline development, jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)"


requirements:
  StepInputExpressionRequirement:
    class: StepInputExpressionRequirement
  InlineJavascriptRequirement:
    class: InlineJavascriptRequirement

inputs:
  #################
  # Script inputs #
  #################
  IUCNRedlistIndex>IUCN_redlist_spThreats.yml@92|threat_category_input:
    type:
      type: enum[]
      symbols:
        - Do not filter by threat category
        - Residential & commercial development
        - Agriculture & aquaculture
        - Energy production & mining
        - Transportation & service corridors
        - Biological resource use
        - Human intrusions & disturbance
        - Natural system modifications
        - Invasive and other problematic species, genes & diseases
        - Invasive alien species or diseases
        - Pollution
        - Geological events
        - Climate change & severe weather
        - Fisheries
        - Other options
    label: Threat category
    doc: Select the species threat(s) to filter for. This returns a list of IUCN Red List species that are threatened by the categories selected.
    default:
    - Do not filter by threat category

  pipeline@95:
    label: Country
    doc: Country of interest.
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

  IUCNRedlistIndex>IUCN_redlist_spGroup.yml@82|taxonomic_group:
    type:
      type: enum[]
      symbols:
        - All
        - Amphibians
        - Birds
        - Mammals
        - Reptiles
        - Fishes
        - Insects
        - Angelfishes
        - Arachnids
        - Blennies
        - Brown algae
        - Butterfly fishes
        - Cacti
        - Chameleons
        - Cone snails
        - Conifers
        - Corals
        - Crocodiles and alligators
        - Crustaceans
        - Cycads
        - Fernes and allies
        - Flowering plants
        - Fw caridean shrimps
        - Fw crabs
        - Fw crayfish
        - Green algae
        - Groupers
        - Gymnosperms
        - Hagfishes
        - Horseshoe crabs
        - Lichens
        - Lobsters
        - Magnolias
        - Mangrove plants
        - Molluscs
        - Mosses
        - Mushrooms
        - Others
        - Pufferfishes
        - Red algae
        - Reef building corals
        - Seabreams porgies picarels
        - Seagrasses
        - Seasnakes
        - Sharks and rays
        - Sturgeons
        - Surgeonfishes
        - Tarpons and ladyfishes
        - Tunas and billfishes
        - Velvet worms
        - Wrasses and parrotfishes
    label: Taxonomic group
    doc: Select the taxonomic groups for which to calculate the RLI. If 'All' is selected, the pipeline will include all taxonomic groups.
    default:
    - Mammals

  IUCNRedlistIndex>IUCN_redlist_spUse.yml@77|species_use:
    type:
      type: enum[]
      symbols:
        - All
        - Do not filter by species use or trade
        - Food - human
        - Food - animal
        - Medicine - human & veterinary
        - Poisons
        - Manufacturing chemicals
        - Other chemicals
        - Fuels
        - Fibre
        - Construction or structural materials
        - Wearing apparel, accessories
        - Other household goods
        - Handicrafts, jewellery, etc.
        - Pets/display animals, horticulture
        - Research
        - Sport hunting/specimen collecting
        - Establishing ex-situ production
        - Other
        - Unknown
    label: Species use
    doc: Select the species use(s) or trade(s). This will filter the species list to only include species with the selected uses. If 'All' is selected, the pipeline will include all species that have a use recorded in the Red List database. You may omit this filter by selecting 'Do not filter by species use or trade'.
    default:
    - Do not filter by species use or trade



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.
    default:
      class: Directory
      path: ./envs

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

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.



steps:
  # This step prepares the environments for all the following steps
  prepareEnvironments:
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
          dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:cwl-poc
        EnvVarRequirement:
          envDef:
            CONDA_PKGS_DIRS: /conda-env-yml/pkgs
            CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
            SCRIPT_STUBS_LOCATION: /script-stubs
            OUTPUT_LOCATION: "$(inputs.runFolderWrite ? inputs.runFolderWrite.path : runtime.outdir)"
      baseCommand: [bash, -c]
      arguments:
        - |
          echo "Exporting all environments"
          mkdir -p "$OUTPUT_LOCATION" "$CONDA_PKGS_DIRS" /conda-env-yml/envs
          
          function exportEnv {
            condaEnvName=$1
            condaEnvYml=$2
            unpackedFolder=$(inputs.envFolderWrite.path)/$condaEnvName
            
            echo "Exporting $condaEnvName..."
            source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION "$condaEnvName" \
            "$condaEnvYml" $(inputs.envFolderWrite.path) $(inputs.condaPackURL)
            source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh $condaEnvName $(inputs.envFolderWrite.path)
            if [[ ! -d "$unpackedFolder" ]]; then
              mkdir -p "$unpackedFolder"
              tar -xf "$unpackedFolder.tar.gz" -C "$unpackedFolder" --use-compress-program=pigz
            fi
            echo "Done."
          }
          export -f exportEnv
          
          bash -c 'exportEnv "IUCNRedlistIndex__IUCN_redlist_historyAssesment" "channels: [conda-forge, r]
          dependencies: [r-magrittr, r-data.table, r-dplyr, r-plyr, r-ggplot2, r-tibble, r-pbapply,
            r-rredlist, r-plyr, r-reshape2, r-rjson]
          name: IUCNRedlistIndex__IUCN_redlist_historyAssesment
          "'
          
          bash -c 'exportEnv "IUCNRedlistIndex__IUCN_redlist_spList" "channels: [conda-forge, r]
          dependencies: [r-magrittr, r-dplyr, r-rredlist, r-this.path, r-rjson]
          name: IUCNRedlistIndex__IUCN_redlist_spList
          "'
          
          bash -c 'exportEnv "IUCNRedlistIndex__RedListIndex" "channels: [conda-forge, r]
          dependencies: [r-magrittr, r-data.table, r-reshape2, r-dplyr, r-plyr, r-ggplot2, r-tibble,
            r-pbapply, r-rredlist, r-plyr, r-gdistance, r-BAT, r-ape, r-geometry, r-magic, r-hypervolume,
            r-ks, r-mclust, r-mvtnorm, r-pracma, r-fastcluster, r-pdist, r-palmerpenguins, r-caret,
            r-recipes, r-timeDate, r-gower, r-hardhat, r-ipred, r-prodlim, r-lava, r-future.apply,
            r-future, r-globals, r-listenv, r-parallelly, r-ModelMetrics, r-pROC, r-nls2, r-proto,
            r-vegan, r-permute, r-phytools, r-combinat, r-clusterGeneration, r-DEoptim, r-expm,
            r-optimParallel, r-phangorn, r-fastmatch, r-scatterplot3d, r-predicts, r-coda, r-mnormt,
            r-numDeriv, r-quadprog, r-dismo, r-geosphere, r-rjson]
          name: IUCNRedlistIndex__RedListIndex
          "'
          
          bash -c 'exportEnv "IUCNRedlistIndex__IUCN_redlist_spUse" "channels: [conda-forge, r]
          dependencies: [r-magrittr, r-dplyr, r-rredlist, r-this.path, r-rjson]
          name: IUCNRedlistIndex__IUCN_redlist_spUse
          "'
          
          bash -c 'exportEnv "IUCNRedlistIndex__IUCN_redlist_spGroup" "channels: [conda-forge, r]
          dependencies: [r-magrittr, r-dplyr, r-rredlist, r-this.path, r-rjson]
          name: IUCNRedlistIndex__IUCN_redlist_spGroup
          "'
          
          bash -c 'exportEnv "IUCNRedlistIndex__IUCN_redlist_spThreats" "channels: [conda-forge, r]
          dependencies: [r-magrittr, r-dplyr, r-rredlist, r-this.path, r-rjson]
          name: IUCNRedlistIndex__IUCN_redlist_spThreats
          "'
          
          bash -c 'exportEnv "IUCNRedlistIndex__IUCN_redlist_spCountry" "channels: [conda-forge, r]
          dependencies: [r-magrittr, r-dplyr, r-rredlist, r-this.path, r-rjson]
          name: IUCNRedlistIndex__IUCN_redlist_spCountry
          "'
          
      inputs:
        envFolderWrite:
          type: Directory
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
        valueFrom: "$({ class: 'Directory', location: (self ? self.location : '/tmp/cwl' ) + '/prepareEnvironments' })"
      condaPackURL: condaPackURL
    out: [envFolder]

  IUCNRedlistIndex>IUCN_redlist_historyAssesment.yml@55:
    run: ../../tools/IUCN_redlist_historyAssesment.cwl
    in:
      species_data: IUCNRedlistIndex>IUCN_redlist_spList.yml@58/iucn_splist
      sp_col: { default: scientific_name }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IUCNRedlistIndex__IUCN_redlist_historyAssesment/55' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [iucn_history_assessment_data, api_citation]


  IUCNRedlistIndex>IUCN_redlist_spList.yml@58:
    run: ../../tools/IUCN_redlist_spList.cwl
    in:
      splist_taxon: IUCNRedlistIndex>IUCN_redlist_spGroup.yml@82/iucn_taxon_splist
      splist_country: IUCNRedlistIndex>IUCN_redlist_spCountry.yml@96/iucn_country_splist
      splist_use: IUCNRedlistIndex>IUCN_redlist_spUse.yml@77/iucn_use_splist
      splist_threat: IUCNRedlistIndex>IUCN_redlist_spThreats.yml@92/iucn_threats_splist
      taxonomic_group: IUCNRedlistIndex>IUCN_redlist_spGroup.yml@82/taxonomic_group
      species_use: IUCNRedlistIndex>IUCN_redlist_spUse.yml@77/species_use
      threat: IUCNRedlistIndex>IUCN_redlist_spThreats.yml@92/threat_category
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IUCNRedlistIndex__IUCN_redlist_spList/58' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [iucn_splist, number_species]


  IUCNRedlistIndex>RedListIndex.yml@59:
    run: ../../tools/RedListIndex.cwl
    in:
      history_assessment_data: IUCNRedlistIndex>IUCN_redlist_historyAssesment.yml@55/iucn_history_assessment_data
      country: pipeline@95
      taxonomic_group: IUCNRedlistIndex>IUCN_redlist_spGroup.yml@82/taxonomic_group
      species_use: IUCNRedlistIndex>IUCN_redlist_spUse.yml@77/species_use
      threat: IUCNRedlistIndex>IUCN_redlist_spThreats.yml@92/threat_category
      sp_col: { default: scientific_name }
      time_col: { default: assess_year }
      threat_category_code_column: { default: code }
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IUCNRedlistIndex__RedListIndex/59' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [redlist_trend_plot, redlist_data, redlist_matrix]


  IUCNRedlistIndex>IUCN_redlist_spUse.yml@77:
    run: ../../tools/IUCN_redlist_spUse.cwl
    in:
      species_use: IUCNRedlistIndex>IUCN_redlist_spUse.yml@77|species_use
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IUCNRedlistIndex__IUCN_redlist_spUse/77' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [iucn_use_splist, species_use, api_citation]


  IUCNRedlistIndex>IUCN_redlist_spGroup.yml@82:
    run: ../../tools/IUCN_redlist_spGroup.cwl
    in:
      taxonomic_group: IUCNRedlistIndex>IUCN_redlist_spGroup.yml@82|taxonomic_group
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IUCNRedlistIndex__IUCN_redlist_spGroup/82' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [iucn_taxon_splist, taxonomic_group, api_citation]


  IUCNRedlistIndex>IUCN_redlist_spThreats.yml@92:
    run: ../../tools/IUCN_redlist_spThreats.cwl
    in:
      threat_category_input: IUCNRedlistIndex>IUCN_redlist_spThreats.yml@92|threat_category_input
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IUCNRedlistIndex__IUCN_redlist_spThreats/92' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [threat_category, threats_list, iucn_threats_splist, api_citation]


  IUCNRedlistIndex>IUCN_redlist_spCountry.yml@96:
    run: ../../tools/IUCN_redlist_spCountry.cwl
    in:
      country: pipeline@95
      envFolder: prepareEnvironments/envFolder
      envFolderWriteable:
        default: false
      runFolder:
          source: runFolder
          valueFrom: "$(self ? { class: 'Directory', location: self.location + '/IUCNRedlistIndex__IUCN_redlist_spCountry/96' } : null)" 
      environment: environment
      condaPackURL: condaPackURL
      scripts_root: scripts_root
    out: [iucn_country_splist, api_citation]


outputs:
  IUCNRedlistIndex>RedListIndex.yml@59|redlist_data:
    type: File
    label: Red List data
    doc: Dataset containing the results of the Red List Index (RLI) calculation.
    outputSource: IUCNRedlistIndex>RedListIndex.yml@59/redlist_data

  IUCNRedlistIndex>IUCN_redlist_spList.yml@58|number_species:
    type: int
    label: Number of species
    doc: Number of species in that country, filtered by taxon, threat, and use categories.
    outputSource: IUCNRedlistIndex>IUCN_redlist_spList.yml@58/number_species

  IUCNRedlistIndex>IUCN_redlist_spGroup.yml@82|taxonomic_group:
    type: File
    label: Taxonomic group(s)
    doc: The taxonomic group(s) of interest.
    outputSource: IUCNRedlistIndex>IUCN_redlist_spGroup.yml@82/taxonomic_group

  IUCNRedlistIndex>IUCN_redlist_spThreats.yml@92|threat_category:
    type: string[]
    label: Species threat(s)
    doc: IUCN threat category
    outputSource: IUCNRedlistIndex>IUCN_redlist_spThreats.yml@92/threat_category

  IUCNRedlistIndex>RedListIndex.yml@59|redlist_trend_plot:
    type: File
    label: Red List trend
    doc: The Red List Index of species for the chosen taxonomy group over time. An RLI of 1.0 indicates that all species have a status of Least Concerned, while 0.0 indicates Extinct. If the RLI value is constant over time, the overall extinction risk remains unchanged. An upward trend shows a reduction in the rate of biodiversity loss.
    outputSource: IUCNRedlistIndex>RedListIndex.yml@59/redlist_trend_plot

  IUCNRedlistIndex>IUCN_redlist_historyAssesment.yml@55|api_citation:
    type: File
    label: IUCN API citation
    doc: Citation for the data acquired using the IUCN Red List API.
    outputSource: IUCNRedlistIndex>IUCN_redlist_historyAssesment.yml@55/api_citation

  IUCNRedlistIndex>RedListIndex.yml@59|redlist_matrix:
    type: File
    label: Red List matrix
    doc: Matrix showing the distribution of threat categories over time for the group of species.
    outputSource: IUCNRedlistIndex>RedListIndex.yml@59/redlist_matrix

  IUCNRedlistIndex>IUCN_redlist_spUse.yml@77|species_use:
    type: string[]
    label: Species use(s)
    doc: The species use(s) or trade(s) selected.
    outputSource: IUCNRedlistIndex>IUCN_redlist_spUse.yml@77/species_use

