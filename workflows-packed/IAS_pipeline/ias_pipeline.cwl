{
    "$graph": [
        {
            "class": "CommandLineTool",
            "label": "Download First Records Data",
            "doc": [
                "Description:\nStream the pinned SInAS 3.0 release for testing across all mapped locations associated with a selected country, preserve source locations, join kingdom and taxaGroup by taxonID from the same release's companion taxonomy table, and standardise habitat terminology for GRIIS integration.\n",
                "Authors:\nSaxbee Affleck\nSamara Manzin (samara.manzin@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
                        },
                        {
                            "envValue": "$(inputs.condaPackURL)",
                            "envName": "CONDA_PACK_URL"
                        },
                        {
                            "envValue": "/conda-env-yml/pkgs",
                            "envName": "CONDA_PKGS_DIRS"
                        },
                        {
                            "envValue": "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)",
                            "envName": "OUTPUT_LOCATION"
                        },
                        {
                            "envValue": "1",
                            "envName": "PYTHONUNBUFFERED"
                        },
                        {
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
                        },
                        {
                            "envValue": "$(inputs.scriptPath)",
                            "envName": "SCRIPT_PATH"
                        },
                        {
                            "envValue": "/script-stubs",
                            "envName": "SCRIPT_STUBS_LOCATION"
                        },
                        {
                            "envValue": "/userdata",
                            "envName": "USERDATA_LOCATION"
                        }
                    ],
                    "class": "EnvVarRequirement"
                },
                {
                    "listing": "${\n  return [\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.envFolder\n      ? {\n          entry: inputs.envFolder,\n          entryname: \"/conda-envs\",\n          writable: inputs.envFolderWritable\n        }\n      : { // fallback\n          entry: { \"class\": \"Directory\", \"basename\": \"conda-envs\", \"listing\": [] },\n          entryname: \"/conda-envs\",\n          writable: true\n        }\n  ).concat(\n    inputs.environment\n      ? [{ entry: inputs.environment, entryname: \"/runner.env\" }]\n      : []\n  ).concat(\n    inputs.runFolder\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  ).concat( // For debugging, overrides /scripts\n    inputs.scripts_root\n      ? [{ entry: inputs.scripts_root, entryname: \"/scripts\" }]\n      : []\n  );\n}\n",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "expressionLib": [
                        "function extractOutput(outputFiles, key) {\n  if (!outputFiles || outputFiles.length === 0) return null;\n  var value = JSON.parse(outputFiles[0].contents)[key]\n  if (value === undefined) return null\n\n  if(inputs.runFolder != null) {\n    if(Array.isArray(value)) {\n      value = value.map(function (item) {\n        if(typeof item.replace === \"function\")\n          return item.replace(inputs.runFolder.path, runtime.outdir);\n        else return item\n      });\n    } else if(typeof value.replace === \"function\") {\n      value = value.replace(inputs.runFolder.path, runtime.outdir);\n    }\n  }\n  return value;\n}\n"
                    ],
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "inplaceUpdate": true,
                    "class": "InplaceUpdateRequirement"
                },
                {
                    "networkAccess": true,
                    "class": "NetworkAccess"
                },
                {
                    "ramMin": 5120,
                    "class": "ResourceRequirement"
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    country_name: inputs.country_name,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"IAS__download_firstrecords\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-jsonlite, r-dplyr, r-duckdb, r-rjson, r-stringr, r-openxlsx]\nname: IAS__download_firstrecords\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__download_firstrecords /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#download_firstrecords.cwl/condaPackURL"
                },
                {
                    "label": "Country name",
                    "doc": "Name of the country for which to download the first records data.",
                    "type": {
                        "type": "record",
                        "name": "#download_firstrecords.cwl/country_name/country",
                        "fields": [
                            {
                                "name": "#download_firstrecords.cwl/country_name/country/country",
                                "type": {
                                    "name": "#download_firstrecords.cwl/country_name/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#download_firstrecords.cwl/country_name/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#download_firstrecords.cwl/country_name/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#download_firstrecords.cwl/country_name/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#download_firstrecords.cwl/country_name"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#download_firstrecords.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#download_firstrecords.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#download_firstrecords.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#download_firstrecords.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "IAS/download_firstrecords.R",
                    "id": "#download_firstrecords.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#download_firstrecords.cwl/scripts_root"
                }
            ],
            "id": "#download_firstrecords.cwl",
            "outputs": [
                {
                    "type": "File",
                    "label": "First Records Cleaned",
                    "doc": "Cleaned first records data for the specified country.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"firstrecords_cleaned\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#download_firstrecords.cwl/firstrecords_cleaned_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#download_firstrecords.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Source taxonomy issues",
                    "doc": "Distinct source taxa with no companion taxonID match or missing kingdom or taxaGroup. Missing kingdom remains NODATA for downstream filtering.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"taxonomy_issues\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#download_firstrecords.cwl/taxonomy_issues_out"
                }
            ]
        },
        {
            "class": "CommandLineTool",
            "label": "Download GRIIS Checklist",
            "doc": [
                "Description:\nDownload the latest national GRIIS checklist for a specified country and its affiliated regions, retain each checklist's ISO3 metadata, and combine the records. Protected-area checklists are excluded.\n",
                "Authors:\nSaxbee Affleck\nSamara Manzin (samara.manzin@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
                        },
                        {
                            "envValue": "$(inputs.condaPackURL)",
                            "envName": "CONDA_PACK_URL"
                        },
                        {
                            "envValue": "/conda-env-yml/pkgs",
                            "envName": "CONDA_PKGS_DIRS"
                        },
                        {
                            "envValue": "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)",
                            "envName": "OUTPUT_LOCATION"
                        },
                        {
                            "envValue": "1",
                            "envName": "PYTHONUNBUFFERED"
                        },
                        {
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
                        },
                        {
                            "envValue": "$(inputs.scriptPath)",
                            "envName": "SCRIPT_PATH"
                        },
                        {
                            "envValue": "/script-stubs",
                            "envName": "SCRIPT_STUBS_LOCATION"
                        },
                        {
                            "envValue": "/userdata",
                            "envName": "USERDATA_LOCATION"
                        }
                    ],
                    "class": "EnvVarRequirement"
                },
                {
                    "listing": "${\n  return [\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.envFolder\n      ? {\n          entry: inputs.envFolder,\n          entryname: \"/conda-envs\",\n          writable: inputs.envFolderWritable\n        }\n      : { // fallback\n          entry: { \"class\": \"Directory\", \"basename\": \"conda-envs\", \"listing\": [] },\n          entryname: \"/conda-envs\",\n          writable: true\n        }\n  ).concat(\n    inputs.environment\n      ? [{ entry: inputs.environment, entryname: \"/runner.env\" }]\n      : []\n  ).concat(\n    inputs.runFolder\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  ).concat( // For debugging, overrides /scripts\n    inputs.scripts_root\n      ? [{ entry: inputs.scripts_root, entryname: \"/scripts\" }]\n      : []\n  );\n}\n",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "expressionLib": [
                        "function extractOutput(outputFiles, key) {\n  if (!outputFiles || outputFiles.length === 0) return null;\n  var value = JSON.parse(outputFiles[0].contents)[key]\n  if (value === undefined) return null\n\n  if(inputs.runFolder != null) {\n    if(Array.isArray(value)) {\n      value = value.map(function (item) {\n        if(typeof item.replace === \"function\")\n          return item.replace(inputs.runFolder.path, runtime.outdir);\n        else return item\n      });\n    } else if(typeof value.replace === \"function\") {\n      value = value.replace(inputs.runFolder.path, runtime.outdir);\n    }\n  }\n  return value;\n}\n"
                    ],
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "inplaceUpdate": true,
                    "class": "InplaceUpdateRequirement"
                },
                {
                    "networkAccess": true,
                    "class": "NetworkAccess"
                },
                {
                    "ramMin": 5120,
                    "class": "ResourceRequirement"
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    country_name: inputs.country_name,\n    compendium_countries: inputs.compendium_countries ? inputs.compendium_countries.path : null,\n    global_invasive_checklist: inputs.global_invasive_checklist ? inputs.global_invasive_checklist.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"IAS__download_griischecklist\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-xml, r-dplyr, r-stringr, r-readr, r-tidyrss, r-tidyr, r-rvest, r-rjson,\n  r-readxl, r-countrycode]\nname: IAS__download_griischecklist\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__download_griischecklist /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Compendium countries",
                    "doc": "List of countries included in the compendium.",
                    "default": "/scripts/IAS/compendiumCountries.xlsx",
                    "id": "#download_griischecklist.cwl/compendium_countries"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#download_griischecklist.cwl/condaPackURL"
                },
                {
                    "label": "Country name",
                    "doc": "Name of the country for which to download the GRIIS checklist.",
                    "type": {
                        "type": "record",
                        "name": "#download_griischecklist.cwl/country_name/country",
                        "fields": [
                            {
                                "name": "#download_griischecklist.cwl/country_name/country/country",
                                "type": {
                                    "name": "#download_griischecklist.cwl/country_name/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#download_griischecklist.cwl/country_name/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#download_griischecklist.cwl/country_name/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#download_griischecklist.cwl/country_name/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#download_griischecklist.cwl/country_name"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#download_griischecklist.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#download_griischecklist.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#download_griischecklist.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Global invasive alien species checklist",
                    "doc": "Global checklist used to identify species that are invasive anywhere.",
                    "default": "/scripts/IAS/species_isInvasiveAnywhere.csv",
                    "id": "#download_griischecklist.cwl/global_invasive_checklist"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#download_griischecklist.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "IAS/download_griischecklist.R",
                    "id": "#download_griischecklist.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#download_griischecklist.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "GRIIS checklist summary (all data)",
                    "doc": "GRIIS checklist summary for all data.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"all_data_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#download_griischecklist.cwl/all_data_summary_out"
                },
                {
                    "type": "File",
                    "label": "GRIIS checklist",
                    "doc": "GRIIS checklist for the specified country.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"griis_checklist\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#download_griischecklist.cwl/griis_checklist_out"
                },
                {
                    "type": "File",
                    "label": "GRIIS directory",
                    "doc": "Directory where the GRIIS checklist is saved.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"griis_directory\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#download_griischecklist.cwl/griis_directory_out"
                },
                {
                    "type": "File",
                    "label": "GRIIS summary",
                    "doc": "Summary of the GRIIS checklist for the specified country.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"griis_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#download_griischecklist.cwl/griis_summary_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#download_griischecklist.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "GRIIS checklist summary (per list)",
                    "doc": "GRIIS checklist summary for each list.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"per_list_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#download_griischecklist.cwl/per_list_summary_out"
                }
            ],
            "id": "#download_griischecklist.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Import National Checklist",
            "doc": [
                "Description:\nImport a country's national checklist and map it to the standardised SInAS columns.\n",
                "Authors:\nSamara Manzin (samara.manzin@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
                        },
                        {
                            "envValue": "$(inputs.condaPackURL)",
                            "envName": "CONDA_PACK_URL"
                        },
                        {
                            "envValue": "/conda-env-yml/pkgs",
                            "envName": "CONDA_PKGS_DIRS"
                        },
                        {
                            "envValue": "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)",
                            "envName": "OUTPUT_LOCATION"
                        },
                        {
                            "envValue": "1",
                            "envName": "PYTHONUNBUFFERED"
                        },
                        {
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
                        },
                        {
                            "envValue": "$(inputs.scriptPath)",
                            "envName": "SCRIPT_PATH"
                        },
                        {
                            "envValue": "/script-stubs",
                            "envName": "SCRIPT_STUBS_LOCATION"
                        },
                        {
                            "envValue": "/userdata",
                            "envName": "USERDATA_LOCATION"
                        }
                    ],
                    "class": "EnvVarRequirement"
                },
                {
                    "listing": "${\n  return [\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.envFolder\n      ? {\n          entry: inputs.envFolder,\n          entryname: \"/conda-envs\",\n          writable: inputs.envFolderWritable\n        }\n      : { // fallback\n          entry: { \"class\": \"Directory\", \"basename\": \"conda-envs\", \"listing\": [] },\n          entryname: \"/conda-envs\",\n          writable: true\n        }\n  ).concat(\n    inputs.environment\n      ? [{ entry: inputs.environment, entryname: \"/runner.env\" }]\n      : []\n  ).concat(\n    inputs.runFolder\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  ).concat( // For debugging, overrides /scripts\n    inputs.scripts_root\n      ? [{ entry: inputs.scripts_root, entryname: \"/scripts\" }]\n      : []\n  );\n}\n",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "expressionLib": [
                        "function extractOutput(outputFiles, key) {\n  if (!outputFiles || outputFiles.length === 0) return null;\n  var value = JSON.parse(outputFiles[0].contents)[key]\n  if (value === undefined) return null\n\n  if(inputs.runFolder != null) {\n    if(Array.isArray(value)) {\n      value = value.map(function (item) {\n        if(typeof item.replace === \"function\")\n          return item.replace(inputs.runFolder.path, runtime.outdir);\n        else return item\n      });\n    } else if(typeof value.replace === \"function\") {\n      value = value.replace(inputs.runFolder.path, runtime.outdir);\n    }\n  }\n  return value;\n}\n"
                    ],
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "inplaceUpdate": true,
                    "class": "InplaceUpdateRequirement"
                },
                {
                    "networkAccess": true,
                    "class": "NetworkAccess"
                },
                {
                    "ramMin": 5120,
                    "class": "ResourceRequirement"
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    country_name: inputs.country_name,\n    national_checklist: inputs.national_checklist ? inputs.national_checklist.path : null,\n    species_column: inputs.species_column,\n    first_record_column: inputs.first_record_column,\n    dataset_citation: inputs.dataset_citation,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"IAS__import_national_checklist\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-base, r-rjson]\nname: IAS__import_national_checklist\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__import_national_checklist /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#import_national_checklist.cwl/condaPackURL"
                },
                {
                    "label": "Country name",
                    "doc": "Country represented by the uploaded national checklist. Required only when a checklist is uploaded.",
                    "type": {
                        "type": "record",
                        "name": "#import_national_checklist.cwl/country_name/country",
                        "fields": [
                            {
                                "name": "#import_national_checklist.cwl/country_name/country/country",
                                "type": {
                                    "name": "#import_national_checklist.cwl/country_name/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#import_national_checklist.cwl/country_name/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#import_national_checklist.cwl/country_name/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#import_national_checklist.cwl/country_name/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#import_national_checklist.cwl/country_name"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Dataset citation",
                    "doc": "Optional dataset citation. Defaults to user_input_data when blank.",
                    "default": "user_input_data",
                    "id": "#import_national_checklist.cwl/dataset_citation"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#import_national_checklist.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#import_national_checklist.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#import_national_checklist.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "First record column",
                    "doc": "Exact column name containing the first documented occurrence year or date in the selected country. Leave blank if not provided. Date standardisation occurs in SInAS preparation.",
                    "id": "#import_national_checklist.cwl/first_record_column"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "National checklist",
                    "doc": "Optional national checklist CSV file. Leave empty to skip this step without producing an output.",
                    "id": "#import_national_checklist.cwl/national_checklist"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#import_national_checklist.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "IAS/import_national_checklist.R",
                    "id": "#import_national_checklist.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#import_national_checklist.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Species column",
                    "doc": "Exact column name containing scientific species names. Required only when a checklist is uploaded.",
                    "default": "species",
                    "id": "#import_national_checklist.cwl/species_column"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#import_national_checklist.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "National checklist",
                    "doc": "Mapped checklist with original species names, original dates and source row numbers. No output is produced when no checklist is uploaded.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"national_checklist\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#import_national_checklist.cwl/national_checklist_out"
                }
            ],
            "id": "#import_national_checklist.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "SInAS Merge Standardised Datasets",
            "doc": [
                "Description:\nMerge one country's standardised sources. An optional national checklist defines membership and supplies preferred first-record years; without it, use the existing GRIIS and First Records merging rules.\n",
                "Authors:\nManuela Gomez-Suarez\nHanno Seebens\nSamara Manzin (samara.manzin@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
                        },
                        {
                            "envValue": "$(inputs.condaPackURL)",
                            "envName": "CONDA_PACK_URL"
                        },
                        {
                            "envValue": "/conda-env-yml/pkgs",
                            "envName": "CONDA_PKGS_DIRS"
                        },
                        {
                            "envValue": "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)",
                            "envName": "OUTPUT_LOCATION"
                        },
                        {
                            "envValue": "1",
                            "envName": "PYTHONUNBUFFERED"
                        },
                        {
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
                        },
                        {
                            "envValue": "$(inputs.scriptPath)",
                            "envName": "SCRIPT_PATH"
                        },
                        {
                            "envValue": "/script-stubs",
                            "envName": "SCRIPT_STUBS_LOCATION"
                        },
                        {
                            "envValue": "/userdata",
                            "envName": "USERDATA_LOCATION"
                        }
                    ],
                    "class": "EnvVarRequirement"
                },
                {
                    "listing": "${\n  return [\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.envFolder\n      ? {\n          entry: inputs.envFolder,\n          entryname: \"/conda-envs\",\n          writable: inputs.envFolderWritable\n        }\n      : { // fallback\n          entry: { \"class\": \"Directory\", \"basename\": \"conda-envs\", \"listing\": [] },\n          entryname: \"/conda-envs\",\n          writable: true\n        }\n  ).concat(\n    inputs.environment\n      ? [{ entry: inputs.environment, entryname: \"/runner.env\" }]\n      : []\n  ).concat(\n    inputs.runFolder\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  ).concat( // For debugging, overrides /scripts\n    inputs.scripts_root\n      ? [{ entry: inputs.scripts_root, entryname: \"/scripts\" }]\n      : []\n  );\n}\n",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "expressionLib": [
                        "function extractOutput(outputFiles, key) {\n  if (!outputFiles || outputFiles.length === 0) return null;\n  var value = JSON.parse(outputFiles[0].contents)[key]\n  if (value === undefined) return null\n\n  if(inputs.runFolder != null) {\n    if(Array.isArray(value)) {\n      value = value.map(function (item) {\n        if(typeof item.replace === \"function\")\n          return item.replace(inputs.runFolder.path, runtime.outdir);\n        else return item\n      });\n    } else if(typeof value.replace === \"function\") {\n      value = value.replace(inputs.runFolder.path, runtime.outdir);\n    }\n  }\n  return value;\n}\n"
                    ],
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "inplaceUpdate": true,
                    "class": "InplaceUpdateRequirement"
                },
                {
                    "networkAccess": true,
                    "class": "NetworkAccess"
                },
                {
                    "ramMin": 5120,
                    "class": "ResourceRequirement"
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    country_name: inputs.country_name,\n    griis_clean: inputs.griis_clean ? inputs.griis_clean.path : null,\n    first_records_clean: inputs.first_records_clean ? inputs.first_records_clean.path : null,\n    national_clean: inputs.national_clean ? inputs.national_clean.path : null,\n    full_taxa_list: inputs.full_taxa_list ? inputs.full_taxa_list.path : null,\n    cleaning_summary: inputs.cleaning_summary ? inputs.cleaning_summary.path : null,\n    qc_status: inputs.qc_status ? inputs.qc_status.path : null,\n    unmatched_values: inputs.unmatched_values ? inputs.unmatched_values.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"IAS__merge_datasets\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-base, r-rjson]\nname: IAS__merge_datasets\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__merge_datasets /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Preparation summary",
                    "doc": "Record counts and unresolved-value counts produced while preparing the supplied source datasets.",
                    "id": "#merge_datasets.cwl/cleaning_summary"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#merge_datasets.cwl/condaPackURL"
                },
                {
                    "label": "Country",
                    "doc": "Country represented by this run.",
                    "type": {
                        "type": "record",
                        "name": "#merge_datasets.cwl/country_name/country",
                        "fields": [
                            {
                                "name": "#merge_datasets.cwl/country_name/country/country",
                                "type": {
                                    "name": "#merge_datasets.cwl/country_name/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#merge_datasets.cwl/country_name/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#merge_datasets.cwl/country_name/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#merge_datasets.cwl/country_name/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#merge_datasets.cwl/country_name"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#merge_datasets.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#merge_datasets.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#merge_datasets.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Cleaned First Records dataset",
                    "doc": "First Records dataset after SInAS terminology, location, taxonomy, and event-date standardisation.",
                    "id": "#merge_datasets.cwl/first_records_clean"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Reviewed full taxonomic list",
                    "doc": "GBIF taxonomic hierarchy and taxon IDs produced by the SInAS preparation step.",
                    "id": "#merge_datasets.cwl/full_taxa_list"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Cleaned GRIIS dataset",
                    "doc": "GRIIS dataset after SInAS terminology, location, taxonomy, and event-date standardisation.",
                    "id": "#merge_datasets.cwl/griis_clean"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Cleaned national checklist",
                    "doc": "Optional SInAS-cleaned national checklist. When supplied, only its taxa and locations are retained; valid national first-record years take precedence over external years. Checklist membership does not imply invasive status.",
                    "id": "#merge_datasets.cwl/national_clean"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Quality-control status",
                    "doc": "Quality-control status produced while preparing the supplied source datasets.",
                    "id": "#merge_datasets.cwl/qc_status"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#merge_datasets.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "IAS/merge_datasets.R",
                    "id": "#merge_datasets.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#merge_datasets.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Unmatched values",
                    "doc": "Values that could not be standardised during preparation and the action taken for each value.",
                    "id": "#merge_datasets.cwl/unmatched_values"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "SInAS data-quality report",
                    "doc": "Combined quality-control status, unmatched-value report, and merge-conflict report.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"data_quality_report\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#merge_datasets.cwl/data_quality_report_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#merge_datasets.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Merge conflicts",
                    "doc": "Fields with multiple values during final SInAS record consolidation.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"merge_conflicts\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#merge_datasets.cwl/merge_conflicts_out"
                },
                {
                    "type": "File",
                    "label": "Merge summary",
                    "doc": "Input and output record counts for the selected country.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"merge_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#merge_datasets.cwl/merge_summary_out"
                },
                {
                    "type": "File",
                    "label": "Merged SInAS dataset",
                    "doc": "One record per standardised taxon-location-establishment combination in the default workflow, or per national taxon-location identity when a national checklist is supplied. National outputs retain membership, date sources, competing date evidence and uploaded values.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"merged_dataset\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#merge_datasets.cwl/merged_dataset_out"
                },
                {
                    "type": "File",
                    "label": "SInAS run summary",
                    "doc": "Preparation and merge record counts, warning counts, exclusions, and overall quality-control status.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"run_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#merge_datasets.cwl/run_summary_out"
                }
            ],
            "id": "#merge_datasets.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "SInAS model IAS introduction rates",
            "doc": [
                "Description:\nSelect and run the IAS introduction-rate modelling approach supported by one country's data. Outputs explain model assumptions, detection and survey-effort limitations, and how far each result can be interpreted.\n",
                "Authors:\nRachel Mason\nSamara Manzin (samara.manzin@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
                        },
                        {
                            "envValue": "$(inputs.condaPackURL)",
                            "envName": "CONDA_PACK_URL"
                        },
                        {
                            "envValue": "/conda-env-yml/pkgs",
                            "envName": "CONDA_PKGS_DIRS"
                        },
                        {
                            "envValue": "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)",
                            "envName": "OUTPUT_LOCATION"
                        },
                        {
                            "envValue": "1",
                            "envName": "PYTHONUNBUFFERED"
                        },
                        {
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
                        },
                        {
                            "envValue": "$(inputs.scriptPath)",
                            "envName": "SCRIPT_PATH"
                        },
                        {
                            "envValue": "/script-stubs",
                            "envName": "SCRIPT_STUBS_LOCATION"
                        },
                        {
                            "envValue": "/userdata",
                            "envName": "USERDATA_LOCATION"
                        }
                    ],
                    "class": "EnvVarRequirement"
                },
                {
                    "listing": "${\n  return [\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.envFolder\n      ? {\n          entry: inputs.envFolder,\n          entryname: \"/conda-envs\",\n          writable: inputs.envFolderWritable\n        }\n      : { // fallback\n          entry: { \"class\": \"Directory\", \"basename\": \"conda-envs\", \"listing\": [] },\n          entryname: \"/conda-envs\",\n          writable: true\n        }\n  ).concat(\n    inputs.environment\n      ? [{ entry: inputs.environment, entryname: \"/runner.env\" }]\n      : []\n  ).concat(\n    inputs.runFolder\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  ).concat( // For debugging, overrides /scripts\n    inputs.scripts_root\n      ? [{ entry: inputs.scripts_root, entryname: \"/scripts\" }]\n      : []\n  );\n}\n",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "expressionLib": [
                        "function extractOutput(outputFiles, key) {\n  if (!outputFiles || outputFiles.length === 0) return null;\n  var value = JSON.parse(outputFiles[0].contents)[key]\n  if (value === undefined) return null\n\n  if(inputs.runFolder != null) {\n    if(Array.isArray(value)) {\n      value = value.map(function (item) {\n        if(typeof item.replace === \"function\")\n          return item.replace(inputs.runFolder.path, runtime.outdir);\n        else return item\n      });\n    } else if(typeof value.replace === \"function\") {\n      value = value.replace(inputs.runFolder.path, runtime.outdir);\n    }\n  }\n  return value;\n}\n"
                    ],
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "inplaceUpdate": true,
                    "class": "InplaceUpdateRequirement"
                },
                {
                    "networkAccess": true,
                    "class": "NetworkAccess"
                },
                {
                    "ramMin": 5120,
                    "class": "ResourceRequirement"
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    country_name: inputs.country_name,\n    integrated_data: inputs.integrated_data ? inputs.integrated_data.path : null,\n    covariate_data: inputs.covariate_data ? inputs.covariate_data.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"IAS__model_data\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-base, r-cli, r-dharma, r-dplyr, r-ggeffects, r-ggplot2, r-mass, r-metrics,\n  r-purrr, r-remotes, r-rjson, r-scales, r-tibble, r-tidyr]\nname: IAS__model_data\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__model_data /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#model_data.cwl/condaPackURL"
                },
                {
                    "label": "Country",
                    "doc": "Country for which IAS rate models will be produced.",
                    "type": {
                        "type": "record",
                        "name": "#model_data.cwl/country_name/country",
                        "fields": [
                            {
                                "name": "#model_data.cwl/country_name/country/country",
                                "type": {
                                    "name": "#model_data.cwl/country_name/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#model_data.cwl/country_name/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#model_data.cwl/country_name/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#model_data.cwl/country_name/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#model_data.cwl/country_name"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "GBIF survey-effort covariate",
                    "doc": "GBIF data containing a year column; may contain individual occurrence rows or annual counts.",
                    "id": "#model_data.cwl/covariate_data"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#model_data.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#model_data.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#model_data.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Integrated IAS data",
                    "doc": "Integrated IAS data produced by the SInAS merge-datasets step.",
                    "id": "#model_data.cwl/integrated_data"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#model_data.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "IAS/model_data.R",
                    "id": "#model_data.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#model_data.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "Modelling data summary",
                    "doc": "Data-adequacy statistics for the selected country. First-record completeness is the percentage of GRIIS taxa flagged invasive anywhere that have a first-record year; it is not overall checklist completeness.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"data_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#model_data.cwl/data_summary_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#model_data.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Modelling decision",
                    "doc": "Selected data scenario, adequacy criteria, supported level of inference, interpretation guidance, shared scope, and references.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"model_decision\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#model_data.cwl/model_decision_out"
                },
                {
                    "type": "File",
                    "label": "Annual model input",
                    "doc": "Annual 1970\u20132020 IAS first-detection counts and GBIF observation counts used as an indirect survey-effort proxy. A zero means no input records for that year, not proof that no introductions occurred.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"model_input\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#model_data.cwl/model_input_out"
                },
                {
                    "type": "File",
                    "label": "Model outputs",
                    "doc": "Model assumptions, parameters, fit statistics, convergence status, estimated trend direction, interpretation, and caveats for every model option. First-record trends are not automatically equivalent to introduction trends.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"model_outputs\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#model_data.cwl/model_outputs_out"
                },
                {
                    "type": "string",
                    "label": "Qualitative model interpretation",
                    "doc": "Interpretation selected from the fitted IAS-observation and survey-effort trend combination. A trend is classified as stable when its fitted time slope is not significant at alpha = 0.05.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"qualitative_interpretation\");\n  return value;\n}\n"
                    },
                    "id": "#model_data.cwl/qualitative_interpretation_out"
                },
                {
                    "type": "File",
                    "label": "Qualitative model plot",
                    "doc": "Descriptive comparison of annual IAS first records with the GBIF observation proxy. The corresponding slope-based interpretation is provided in the Qualitative model interpretation output.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"qualitative_plot\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#model_data.cwl/qualitative_plot_out"
                },
                {
                    "type": "File",
                    "label": "Quantitative model comparison",
                    "doc": "Fitted annual discovery records from models with alternative detection assumptions. Compare fit statistics only among converged models fitted to the same country and time series.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"quantitative_plot\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#model_data.cwl/quantitative_plot_out"
                }
            ],
            "id": "#model_data.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "SInAS Prepare Datasets",
            "doc": [
                "Description:\nRun original P3 Steps 1-5 for one country: prepare and roll up mapped First Records regions to the parent country, standardise columns, terminology, locations, GBIF taxonomy and event dates, and report unmatched or excluded records.\n",
                "Authors:\nManuela Gomez-Suarez\nHanno Seebens\nSaxbee Affleck\nSamara Manzin (samara.manzin@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
                        },
                        {
                            "envValue": "$(inputs.condaPackURL)",
                            "envName": "CONDA_PACK_URL"
                        },
                        {
                            "envValue": "/conda-env-yml/pkgs",
                            "envName": "CONDA_PKGS_DIRS"
                        },
                        {
                            "envValue": "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)",
                            "envName": "OUTPUT_LOCATION"
                        },
                        {
                            "envValue": "1",
                            "envName": "PYTHONUNBUFFERED"
                        },
                        {
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
                        },
                        {
                            "envValue": "$(inputs.scriptPath)",
                            "envName": "SCRIPT_PATH"
                        },
                        {
                            "envValue": "/script-stubs",
                            "envName": "SCRIPT_STUBS_LOCATION"
                        },
                        {
                            "envValue": "/userdata",
                            "envName": "USERDATA_LOCATION"
                        }
                    ],
                    "class": "EnvVarRequirement"
                },
                {
                    "listing": "${\n  return [\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.envFolder\n      ? {\n          entry: inputs.envFolder,\n          entryname: \"/conda-envs\",\n          writable: inputs.envFolderWritable\n        }\n      : { // fallback\n          entry: { \"class\": \"Directory\", \"basename\": \"conda-envs\", \"listing\": [] },\n          entryname: \"/conda-envs\",\n          writable: true\n        }\n  ).concat(\n    inputs.environment\n      ? [{ entry: inputs.environment, entryname: \"/runner.env\" }]\n      : []\n  ).concat(\n    inputs.runFolder\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  ).concat( // For debugging, overrides /scripts\n    inputs.scripts_root\n      ? [{ entry: inputs.scripts_root, entryname: \"/scripts\" }]\n      : []\n  );\n}\n",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "expressionLib": [
                        "function extractOutput(outputFiles, key) {\n  if (!outputFiles || outputFiles.length === 0) return null;\n  var value = JSON.parse(outputFiles[0].contents)[key]\n  if (value === undefined) return null\n\n  if(inputs.runFolder != null) {\n    if(Array.isArray(value)) {\n      value = value.map(function (item) {\n        if(typeof item.replace === \"function\")\n          return item.replace(inputs.runFolder.path, runtime.outdir);\n        else return item\n      });\n    } else if(typeof value.replace === \"function\") {\n      value = value.replace(inputs.runFolder.path, runtime.outdir);\n    }\n  }\n  return value;\n}\n"
                    ],
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "inplaceUpdate": true,
                    "class": "InplaceUpdateRequirement"
                },
                {
                    "networkAccess": true,
                    "class": "NetworkAccess"
                },
                {
                    "ramMin": 5120,
                    "class": "ResourceRequirement"
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    country_name: inputs.country_name,\n    griis_checklist: inputs.griis_checklist ? inputs.griis_checklist.path : null,\n    first_records: inputs.first_records ? inputs.first_records.path : null,\n    global_invasive_checklist: inputs.global_invasive_checklist ? inputs.global_invasive_checklist.path : null,\n    national_checklist: inputs.national_checklist ? inputs.national_checklist.path : null,\n    kingdoms: inputs.kingdoms,\n    habitats: inputs.habitats,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"IAS__prepare_datasets\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-dplyr, r-jsonlite, r-duckdb, r-rjson, r-stringr, r-rgbif, r-tidyr,\n  r-stringi, r-openxlsx]\nname: IAS__prepare_datasets\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__prepare_datasets /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#prepare_datasets.cwl/condaPackURL"
                },
                {
                    "label": "Country",
                    "doc": "Country represented by this cleaning run.",
                    "type": {
                        "type": "record",
                        "name": "#prepare_datasets.cwl/country_name/country",
                        "fields": [
                            {
                                "name": "#prepare_datasets.cwl/country_name/country/country",
                                "type": {
                                    "name": "#prepare_datasets.cwl/country_name/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#prepare_datasets.cwl/country_name/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#prepare_datasets.cwl/country_name/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#prepare_datasets.cwl/country_name/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#prepare_datasets.cwl/country_name"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#prepare_datasets.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#prepare_datasets.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#prepare_datasets.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "First records",
                    "doc": "First records table to include in Step 1 preparation.",
                    "id": "#prepare_datasets.cwl/first_records"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Global invasive alien species checklist",
                    "doc": "Same packaged global checklist used by the download step, rechecked against original and harmonised taxon names while preserving existing positive flags.",
                    "default": "/scripts/IAS/species_isInvasiveAnywhere.csv",
                    "id": "#prepare_datasets.cwl/global_invasive_checklist"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "GRIIS checklist",
                    "doc": "GRIIS checklist table to include in Step 1 preparation.",
                    "id": "#prepare_datasets.cwl/griis_checklist"
                },
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "enum",
                            "symbols": [
                                "#prepare_datasets.cwl/habitats/TERRESTRIAL",
                                "#prepare_datasets.cwl/habitats/FRESHWATER",
                                "#prepare_datasets.cwl/habitats/FRESHWATER|BRACKISH",
                                "#prepare_datasets.cwl/habitats/TERRESTRIAL|FRESHWATER",
                                "#prepare_datasets.cwl/habitats/MARINE|FRESHWATER|BRACKISH",
                                "#prepare_datasets.cwl/habitats/TERRESTRIAL|BRACKISH",
                                "#prepare_datasets.cwl/habitats/TERRESTRIAL|FRESHWATER|BRACKISH",
                                "#prepare_datasets.cwl/habitats/TERRESTRIAL|MARINE|FRESHWATER",
                                "#prepare_datasets.cwl/habitats/TERRESTRIAL|MARINE|BRACKISH",
                                "#prepare_datasets.cwl/habitats/MARINE|FRESHWATER",
                                "#prepare_datasets.cwl/habitats/TERRESTRIAL|MARINE"
                            ]
                        }
                    },
                    "label": "Habitat types",
                    "doc": "Habitat values to retain in both the GRIIS and First Records datasets.",
                    "default": [
                        "TERRESTRIAL",
                        "FRESHWATER",
                        "FRESHWATER|BRACKISH",
                        "TERRESTRIAL|FRESHWATER",
                        "MARINE|FRESHWATER|BRACKISH",
                        "TERRESTRIAL|BRACKISH",
                        "TERRESTRIAL|FRESHWATER|BRACKISH",
                        "TERRESTRIAL|MARINE|FRESHWATER",
                        "TERRESTRIAL|MARINE|BRACKISH",
                        "MARINE|FRESHWATER",
                        "TERRESTRIAL|MARINE"
                    ],
                    "id": "#prepare_datasets.cwl/habitats"
                },
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "enum",
                            "symbols": [
                                "#prepare_datasets.cwl/kingdoms/PLANTAE",
                                "#prepare_datasets.cwl/kingdoms/ANIMALIA"
                            ]
                        }
                    },
                    "label": "Kingdoms",
                    "doc": "Kingdoms to retain in both the GRIIS and First Records datasets.",
                    "default": [
                        "PLANTAE",
                        "ANIMALIA"
                    ],
                    "id": "#prepare_datasets.cwl/kingdoms"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Imported national checklist",
                    "doc": "Optional mapped national checklist from the import step.",
                    "id": "#prepare_datasets.cwl/national_checklist"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#prepare_datasets.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "IAS/prepare_datasets.R",
                    "id": "#prepare_datasets.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#prepare_datasets.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "Cleaning summary",
                    "doc": "Input, output, and unresolved-record counts for both datasets.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"cleaning_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/cleaning_summary_out"
                },
                {
                    "type": "File",
                    "label": "SInAS excluded records",
                    "doc": "Complete records excluded from the merged dataset because their locations could not be standardised to a locationID.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"excluded_records\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/excluded_records_out"
                },
                {
                    "type": "File",
                    "label": "File information",
                    "doc": "Table containing information about the input datasets columns",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"file_info\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/file_info_out"
                },
                {
                    "type": "File",
                    "label": "cleaned First Records dataset",
                    "doc": "Cleaned First Records dataset with standardised column names and values.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"first_records_clean\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/first_records_clean_out"
                },
                {
                    "type": "File",
                    "label": "SInAS taxon matching",
                    "doc": "Complete automatic GBIF taxonomic matching results.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"full_taxa_list\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/full_taxa_list_out"
                },
                {
                    "type": "File",
                    "label": "Additional global invasive matches",
                    "doc": "GRIIS records newly flagged as invasive anywhere after taxonomic harmonisation, with matching name fields and country evidence.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"global_invasive_matches\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/global_invasive_matches_out"
                },
                {
                    "type": "File",
                    "label": "cleaned GRIIS dataset",
                    "doc": "Cleaned GRIIS dataset with standardised column names and values.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"griis_clean\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/griis_clean_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#prepare_datasets.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Cleaned national checklist",
                    "doc": "National checklist after SInAS standardisation. Produced only when a checklist is supplied.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"national_clean\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/national_clean_out"
                },
                {
                    "type": "File",
                    "label": "Quality-control status",
                    "doc": "PASS or WARNING summary for terminology, locations, taxonomy, and event dates. Warnings do not block merging.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"qc_status\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/qc_status_out"
                },
                {
                    "type": "File",
                    "label": "Translated event dates",
                    "doc": "Original and standardised event-date values.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"translated_event_dates\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/translated_event_dates_out"
                },
                {
                    "type": "File",
                    "label": "Translated locations",
                    "doc": "Original and standardised location-name pairs.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"translated_locations\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/translated_locations_out"
                },
                {
                    "type": "File",
                    "label": "Unmatched values",
                    "doc": "Consolidated report of terminology, location, taxon, and event-date values that could not be standardised, including the action taken and whether they can enter the merge.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"unmatched_values\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#prepare_datasets.cwl/unmatched_values_out"
                }
            ],
            "id": "#prepare_datasets.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Summarise IAS data",
            "doc": [
                "Description:\nSummarise national checklist species when supplied, otherwise GRIIS-linked taxa flagged invasive anywhere, alongside annual GBIF observation counts.\n",
                "Authors:\nSaxbee Affleck\nSamara Manzin (samara.manzin@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
                        },
                        {
                            "envValue": "$(inputs.condaPackURL)",
                            "envName": "CONDA_PACK_URL"
                        },
                        {
                            "envValue": "/conda-env-yml/pkgs",
                            "envName": "CONDA_PKGS_DIRS"
                        },
                        {
                            "envValue": "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)",
                            "envName": "OUTPUT_LOCATION"
                        },
                        {
                            "envValue": "1",
                            "envName": "PYTHONUNBUFFERED"
                        },
                        {
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
                        },
                        {
                            "envValue": "$(inputs.scriptPath)",
                            "envName": "SCRIPT_PATH"
                        },
                        {
                            "envValue": "/script-stubs",
                            "envName": "SCRIPT_STUBS_LOCATION"
                        },
                        {
                            "envValue": "/userdata",
                            "envName": "USERDATA_LOCATION"
                        }
                    ],
                    "class": "EnvVarRequirement"
                },
                {
                    "listing": "${\n  return [\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.envFolder\n      ? {\n          entry: inputs.envFolder,\n          entryname: \"/conda-envs\",\n          writable: inputs.envFolderWritable\n        }\n      : { // fallback\n          entry: { \"class\": \"Directory\", \"basename\": \"conda-envs\", \"listing\": [] },\n          entryname: \"/conda-envs\",\n          writable: true\n        }\n  ).concat(\n    inputs.environment\n      ? [{ entry: inputs.environment, entryname: \"/runner.env\" }]\n      : []\n  ).concat(\n    inputs.runFolder\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  ).concat( // For debugging, overrides /scripts\n    inputs.scripts_root\n      ? [{ entry: inputs.scripts_root, entryname: \"/scripts\" }]\n      : []\n  );\n}\n",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "expressionLib": [
                        "function extractOutput(outputFiles, key) {\n  if (!outputFiles || outputFiles.length === 0) return null;\n  var value = JSON.parse(outputFiles[0].contents)[key]\n  if (value === undefined) return null\n\n  if(inputs.runFolder != null) {\n    if(Array.isArray(value)) {\n      value = value.map(function (item) {\n        if(typeof item.replace === \"function\")\n          return item.replace(inputs.runFolder.path, runtime.outdir);\n        else return item\n      });\n    } else if(typeof value.replace === \"function\") {\n      value = value.replace(inputs.runFolder.path, runtime.outdir);\n    }\n  }\n  return value;\n}\n"
                    ],
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "inplaceUpdate": true,
                    "class": "InplaceUpdateRequirement"
                },
                {
                    "networkAccess": true,
                    "class": "NetworkAccess"
                },
                {
                    "ramMin": 5120,
                    "class": "ResourceRequirement"
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    merged_dataset: inputs.merged_dataset ? inputs.merged_dataset.path : null,\n    gbif_country_observations: inputs.gbif_country_observations ? inputs.gbif_country_observations.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"IAS__summarise_ias\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-dplyr, r-gt, r-readr, r-stringr, r-tibble, r-tidyr, r-rjson]\nname: IAS__summarise_ias\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh IAS__summarise_ias /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#summarise_ias.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#summarise_ias.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#summarise_ias.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#summarise_ias.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "GBIF country observations",
                    "doc": "CSV containing GBIF occurrence counts per year for the selected country.",
                    "id": "#summarise_ias.cwl/gbif_country_observations"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Merged IAS dataset",
                    "doc": "Merged IAS dataset produced by the SInAS merge-datasets step.",
                    "id": "#summarise_ias.cwl/merged_dataset"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#summarise_ias.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "IAS/summarise_ias.R",
                    "id": "#summarise_ias.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#summarise_ias.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "IAS annual summary",
                    "doc": "Annual GBIF occurrence counts and first-record counts for national checklist members when supplied, otherwise GRIIS-linked taxa flagged invasive anywhere. Uses the final years selected by the merge step.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"ias_annual_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#summarise_ias.cwl/ias_annual_summary_out"
                },
                {
                    "type": "File",
                    "label": "IAS summary",
                    "doc": "Summary statistics for national checklist members (nationalChecklist column), or GRIIS-linked taxa flagged invasive anywhere (isInvasiveAnywhere column). National membership does not imply confirmed invasive status.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"ias_summary\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#summarise_ias.cwl/ias_summary_out"
                },
                {
                    "type": "File",
                    "label": "IAS summary table",
                    "doc": "HTML summary table labelled with the active national-checklist or GRIIS invasive-anywhere scope.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"ias_summary_table\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#summarise_ias.cwl/ias_summary_table_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#summarise_ias.cwl/logs"
                }
            ],
            "id": "#summarise_ias.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Get GBIF country observations with SQL",
            "doc": [
                "Description:\nGet the number of GBIF occurences for each year within a country using the SQL method.\n",
                "Lifecycle tag: Core.",
                "Authors:\nSaxbee Affleck\nRachel Mason\nSamara Manzin (samara.manzin@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
                        },
                        {
                            "envValue": "$(inputs.condaPackURL)",
                            "envName": "CONDA_PACK_URL"
                        },
                        {
                            "envValue": "/conda-env-yml/pkgs",
                            "envName": "CONDA_PKGS_DIRS"
                        },
                        {
                            "envValue": "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)",
                            "envName": "OUTPUT_LOCATION"
                        },
                        {
                            "envValue": "1",
                            "envName": "PYTHONUNBUFFERED"
                        },
                        {
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
                        },
                        {
                            "envValue": "$(inputs.scriptPath)",
                            "envName": "SCRIPT_PATH"
                        },
                        {
                            "envValue": "/script-stubs",
                            "envName": "SCRIPT_STUBS_LOCATION"
                        },
                        {
                            "envValue": "/userdata",
                            "envName": "USERDATA_LOCATION"
                        }
                    ],
                    "class": "EnvVarRequirement"
                },
                {
                    "listing": "${\n  return [\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.envFolder\n      ? {\n          entry: inputs.envFolder,\n          entryname: \"/conda-envs\",\n          writable: inputs.envFolderWritable\n        }\n      : { // fallback\n          entry: { \"class\": \"Directory\", \"basename\": \"conda-envs\", \"listing\": [] },\n          entryname: \"/conda-envs\",\n          writable: true\n        }\n  ).concat(\n    inputs.environment\n      ? [{ entry: inputs.environment, entryname: \"/runner.env\" }]\n      : []\n  ).concat(\n    inputs.runFolder\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  ).concat( // For debugging, overrides /scripts\n    inputs.scripts_root\n      ? [{ entry: inputs.scripts_root, entryname: \"/scripts\" }]\n      : []\n  );\n}\n",
                    "class": "InitialWorkDirRequirement"
                },
                {
                    "expressionLib": [
                        "function extractOutput(outputFiles, key) {\n  if (!outputFiles || outputFiles.length === 0) return null;\n  var value = JSON.parse(outputFiles[0].contents)[key]\n  if (value === undefined) return null\n\n  if(inputs.runFolder != null) {\n    if(Array.isArray(value)) {\n      value = value.map(function (item) {\n        if(typeof item.replace === \"function\")\n          return item.replace(inputs.runFolder.path, runtime.outdir);\n        else return item\n      });\n    } else if(typeof value.replace === \"function\") {\n      value = value.replace(inputs.runFolder.path, runtime.outdir);\n    }\n  }\n  return value;\n}\n"
                    ],
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "inplaceUpdate": true,
                    "class": "InplaceUpdateRequirement"
                },
                {
                    "networkAccess": true,
                    "class": "NetworkAccess"
                },
                {
                    "ramMin": 5120,
                    "class": "ResourceRequirement"
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    country_name: inputs.country_name,\n    start_year: inputs.start_year,\n    end_year: inputs.end_year,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"data__getGBIFObservations__get_GBIF_country_SQL\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-rgbif, r-countrycode, r-readr, r-rjson]\nname: data__getGBIFObservations__get_GBIF_country_SQL\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__getGBIFObservations__get_GBIF_country_SQL /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#get_GBIF_country_SQL.cwl/condaPackURL"
                },
                {
                    "label": "Country name",
                    "doc": "Name of the country for which to get GBIF observations.",
                    "type": {
                        "type": "record",
                        "name": "#get_GBIF_country_SQL.cwl/country_name/country",
                        "fields": [
                            {
                                "name": "#get_GBIF_country_SQL.cwl/country_name/country/country",
                                "type": {
                                    "name": "#get_GBIF_country_SQL.cwl/country_name/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#get_GBIF_country_SQL.cwl/country_name/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#get_GBIF_country_SQL.cwl/country_name/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#get_GBIF_country_SQL.cwl/country_name/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#get_GBIF_country_SQL.cwl/country_name"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "End year",
                    "doc": "End year for which to get GBIF observations.",
                    "default": 2025,
                    "id": "#get_GBIF_country_SQL.cwl/end_year"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#get_GBIF_country_SQL.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#get_GBIF_country_SQL.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#get_GBIF_country_SQL.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#get_GBIF_country_SQL.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "data/getGBIFObservations/get_GBIF_country_SQL.R",
                    "id": "#get_GBIF_country_SQL.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#get_GBIF_country_SQL.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Start year",
                    "doc": "Start year for which to get GBIF observations.",
                    "default": 1970,
                    "id": "#get_GBIF_country_SQL.cwl/start_year"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "GBIF country observations",
                    "doc": "Number of GBIF occurrences for each year within the specified country.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"gbif_country_observations\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#get_GBIF_country_SQL.cwl/gbif_country_observations_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#get_GBIF_country_SQL.cwl/logs"
                }
            ],
            "id": "#get_GBIF_country_SQL.cwl"
        },
        {
            "class": "Workflow",
            "label": "Invasive alien species",
            "doc": [
                "Description:\n## Introduction \nInvasive alien species are a major threat to biodiversity. Reducing the rates of introduction and establishment of invasive alien species is an important component of Target 6, indicator 6.1 of the Kunming Montreal Global Biodiversity Framework (GBF).\n\nThe pipeline compiles national information on alien and invasive species and evaluates patterns across time from their first documented records. It combines national checklist data from the Global Register of Introduced and Invasive Species (GRIIS) or optionally user input national data with the Alien Species First Records database.\n\nThe pipeline applies the Standardising and Integrating Alien Species data (SInAS) workflow to standardise and merge these source datasets. Species names, locations, habitats, occurrence information and first-record dates are standardised before the GRIIS and First Records data are merged. Species names and taxonomic classifications are checked against the GBIF taxonomic backbone. Records that cannot be fully standardised are documented in the pipeline's data-quality outputs.\nIf users upload their own national data the species list will be used instead of the GRIIS checklist. If a first record column is provided in the national data the national first record data will be used instead of the First Records dataset for those species that have both.\nThe pipeline creates an annual time series of invasive alien species first records for the selected country. A first record represents the first documented detection of a species; it does not necesarrily represent the year that the species was introduced, established, or became invasive.\n\nDepending on first-record completeness and the number of years containing records, the pipeline selects one of four approaches:\n- no modelling when the available data are too sparse;\n- a qualitative comparison of first-record and GBIF observation patterns;\n- a reduced set of quantitative models; or\n- the complete set of quantitative models.\n\nThe quantitative approaches include a naive Poisson model, a constant-detection model, a Solow\u2013Costello model, and a sampling model that uses annual GBIF record volume as an indirect proxy for observation effort. The outputs describe the assumptions, fit, estimated trend, interpretation, and limitations of each model. For more information about estimating introduction rates from first-record data, see McGeoch et al. (2023) and Buba et al. (2024).\n\n## Uses\nThis pipeline can be used to:\n- Compile and standardise national GRIIS and First Records data to produce a taxonomically standardised national dataset of alien and invasive\n  alien species.\n\n- Identify unmatched, excluded, or potentially problematic records for\n  data-quality review.\n\n- Summarize and examine temporal patterns in observed first records.\n- Compare models with different assumptions about detection and observation\n  effort.\n\n- Support national assessment and reporting related to Target 6 of GBF.\n## Pipeline limitations \n* This pipeline cannot currently be run for the following countries because of\n  unresolved source-data, checklist-name, or location-mapping issues: United\n  States of America (USA), Belgium (BEL), Thailand (THA), Eswatini (SWZ),\n  Hungary (HUN), and Norway (NOR).\n\n* Annual GBIF record counts are used as an indirect proxy for changing\n  observation effort. GBIF record volume is not a direct measurement of\n  invasive alien species survey effort.\n\n* Model results must be interpreted with caution, please read the model interpretation outputs and papers listed below for guidance.\n* Automated taxonomic and location standardisation cannot resolve every\n  record. Users should review the data-quality, unmatched-value and\n  excluded-record outputs before interpreting results.\n\n* When a first-record date is supplied as a range, the pipeline uses its mean\n  year. This estimated year does not represent a precisely documented\n  detection date.\n\n* The results depend on the versions and coverage of the underlying GRIIS,\n  First Records, GBIF, and configuration data.\n\n\n## Before you start \nA free GBIF account is required to obtain the GBIF observation data used by this pipeline. Add your GBIF username, password, and account email address to the `runner.env` file using the following environment variables: `GBIF_USER`, `GBIF_PWD`, and `GBIF_EMAIL`.\n\nUsers should note the versions of the source databases and workflow used for an analysis. Any modifications to the workflow, configuration tables, or source data should also be reported to support transparency and reproducibility.\n\nIf a national dataset is being uploaded by the user ensure that the column names match what you include in the input form. Review the unmatched-value, excluded-record, taxonomic-matching, merge-conflict, and other data-quality outputs before interpreting the results.\n",
                "Authors:\nRachel Mason (https://orcid.org/0000-0003-2692-9902)\nSaxbee Affleck (https://orcid.org/0009-0007-4589-887X)\nManuela G\u00f3mez-Su\u00e1rez (https://orcid.org/0000-0002-6100-9207)\nHanno Seebens (https://orcid.org/0000-0001-8993-6419)\nSamara Manzin (samara.manzin@mcgill.ca, https://orcid.org/0009-0005-9134-9981)\nMelodie McGeoch (https://orcid.org/0000-0003-3388-2241)\n",
                "External link: https://doi.org/10.5281/zenodo.17727120",
                "References:\nBuba et al., (2024)\nhttps://doi.org/10.1111/geb.13859\n\nBuba (2024)\nhttps://doi.org/10.32614/CRAN.package.alien\n\nMcGeoch et al., (2023)\nhttps://doi.org/10.1111/conl.12981\n\nSeebens & Gomez-Suarez (2025)\nhttps://doi.org/10.5281/zenodo.17727120\n"
            ],
            "requirements": [
                {
                    "class": "InlineJavascriptRequirement"
                },
                {
                    "class": "MultipleInputFeatureRequirement"
                },
                {
                    "class": "StepInputExpressionRequirement"
                }
            ],
            "inputs": [
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "enum",
                            "symbols": [
                                "#main/IAS>prepare_datasets.yml@80|habitats/TERRESTRIAL",
                                "#main/IAS>prepare_datasets.yml@80|habitats/FRESHWATER",
                                "#main/IAS>prepare_datasets.yml@80|habitats/FRESHWATER|BRACKISH",
                                "#main/IAS>prepare_datasets.yml@80|habitats/TERRESTRIAL|FRESHWATER",
                                "#main/IAS>prepare_datasets.yml@80|habitats/MARINE|FRESHWATER|BRACKISH",
                                "#main/IAS>prepare_datasets.yml@80|habitats/TERRESTRIAL|BRACKISH",
                                "#main/IAS>prepare_datasets.yml@80|habitats/TERRESTRIAL|FRESHWATER|BRACKISH",
                                "#main/IAS>prepare_datasets.yml@80|habitats/TERRESTRIAL|MARINE|FRESHWATER",
                                "#main/IAS>prepare_datasets.yml@80|habitats/TERRESTRIAL|MARINE|BRACKISH",
                                "#main/IAS>prepare_datasets.yml@80|habitats/MARINE|FRESHWATER",
                                "#main/IAS>prepare_datasets.yml@80|habitats/TERRESTRIAL|MARINE"
                            ]
                        }
                    },
                    "label": "Habitat types",
                    "doc": "Habitat values to retain in both the GRIIS and First Records datasets.",
                    "default": [
                        "TERRESTRIAL",
                        "FRESHWATER",
                        "FRESHWATER|BRACKISH",
                        "TERRESTRIAL|FRESHWATER",
                        "MARINE|FRESHWATER|BRACKISH",
                        "TERRESTRIAL|BRACKISH",
                        "TERRESTRIAL|FRESHWATER|BRACKISH",
                        "TERRESTRIAL|MARINE|FRESHWATER",
                        "TERRESTRIAL|MARINE|BRACKISH",
                        "MARINE|FRESHWATER",
                        "TERRESTRIAL|MARINE"
                    ],
                    "id": "#main/IAS>prepare_datasets.yml@80|habitats"
                },
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "enum",
                            "symbols": [
                                "#main/IAS>prepare_datasets.yml@80|kingdoms/PLANTAE",
                                "#main/IAS>prepare_datasets.yml@80|kingdoms/ANIMALIA"
                            ]
                        }
                    },
                    "label": "Kingdoms",
                    "doc": "Kingdoms to retain in both the GRIIS and First Records datasets.",
                    "default": [
                        "PLANTAE",
                        "ANIMALIA"
                    ],
                    "id": "#main/IAS>prepare_datasets.yml@80|kingdoms"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#main/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#main/envFolder"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "doc": "Optional. URL (http/https) or file:// URI pointing to a BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used. Relative paths are not supported.",
                    "id": "#main/environment"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Dataset citation (optional)",
                    "doc": "Include citation for the national dataset. Defaults to user_input_data when blank.",
                    "id": "#main/pipeline@100"
                },
                {
                    "label": "Country name",
                    "doc": "Name of the country for the Invasive Alien Species analysis.\nThis pipeline cannot currently be run for the following countries because of unresolved source-data, checklist-name, or location-mapping issues: United States of America (USA), Belgium (BEL), Thailand (THA), Eswatini (SWZ), Hungary (HUN), and Norway (NOR).\n",
                    "type": {
                        "type": "record",
                        "name": "#main/pipeline@41/country",
                        "fields": [
                            {
                                "name": "#main/pipeline@41/country/country",
                                "type": {
                                    "name": "#main/pipeline@41/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@41/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@41/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@41/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#main/pipeline@41"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Start year",
                    "doc": "Start year for which to get GBIF observations. These will be used as a proxy for sampling effort in the given country.",
                    "default": 1970,
                    "id": "#main/pipeline@73"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "End year",
                    "doc": "End year for which to get GBIF observations. These will be used as a proxy for sampling effort in the given country.",
                    "default": 2025,
                    "id": "#main/pipeline@74"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "National checklist (optional)",
                    "doc": "Optional national checklist CSV file. This file should contain a column containing species scientific names and optionally a column containing associated year of first recorded introduction.\nLeave empty to use the GRIIS and First Records datasets for the selected country.\n",
                    "id": "#main/pipeline@97"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Species column (optional)",
                    "doc": "Exact column name containing scientific species names. \nRequired only when a checklist is uploaded.\n",
                    "id": "#main/pipeline@98"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "First record column (optional)",
                    "doc": "Exact column name containing the first documented occurrence year in the selected country. \nRequired only when a checklist is uploaded; leave blank if not provided. Date standardisation occurs in data preparation step.\n",
                    "id": "#main/pipeline@99"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#main/runFolder"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#main/scripts_root"
                }
            ],
            "steps": [
                {
                    "run": "#download_firstrecords.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/IAS>download_firstrecords.yml@37/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@41",
                            "id": "#main/IAS>download_firstrecords.yml@37/country_name"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__download_firstrecords' } : null)",
                            "id": "#main/IAS>download_firstrecords.yml@37/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/IAS>download_firstrecords.yml@37/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/IAS>download_firstrecords.yml@37/environment"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__download_firstrecords/37' } : null)",
                            "id": "#main/IAS>download_firstrecords.yml@37/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/IAS>download_firstrecords.yml@37/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/IAS>download_firstrecords.yml@37/taxonomy_issues_out",
                        "#main/IAS>download_firstrecords.yml@37/firstrecords_cleaned_out"
                    ],
                    "id": "#main/IAS>download_firstrecords.yml@37"
                },
                {
                    "run": "#download_griischecklist.cwl",
                    "in": [
                        {
                            "default": "/scripts/IAS/compendiumCountries.xlsx",
                            "id": "#main/IAS>download_griischecklist.yml@38/compendium_countries"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/IAS>download_griischecklist.yml@38/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@41",
                            "id": "#main/IAS>download_griischecklist.yml@38/country_name"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__download_griischecklist' } : null)",
                            "id": "#main/IAS>download_griischecklist.yml@38/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/IAS>download_griischecklist.yml@38/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/IAS>download_griischecklist.yml@38/environment"
                        },
                        {
                            "default": "/scripts/IAS/species_isInvasiveAnywhere.csv",
                            "id": "#main/IAS>download_griischecklist.yml@38/global_invasive_checklist"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__download_griischecklist/38' } : null)",
                            "id": "#main/IAS>download_griischecklist.yml@38/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/IAS>download_griischecklist.yml@38/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/IAS>download_griischecklist.yml@38/griis_checklist_out",
                        "#main/IAS>download_griischecklist.yml@38/griis_summary_out",
                        "#main/IAS>download_griischecklist.yml@38/griis_directory_out",
                        "#main/IAS>download_griischecklist.yml@38/all_data_summary_out",
                        "#main/IAS>download_griischecklist.yml@38/per_list_summary_out"
                    ],
                    "id": "#main/IAS>download_griischecklist.yml@38"
                },
                {
                    "run": "#import_national_checklist.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/IAS>import_national_checklist.yml@96/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@41",
                            "id": "#main/IAS>import_national_checklist.yml@96/country_name"
                        },
                        {
                            "source": "#main/pipeline@100",
                            "id": "#main/IAS>import_national_checklist.yml@96/dataset_citation"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__import_national_checklist' } : null)",
                            "id": "#main/IAS>import_national_checklist.yml@96/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/IAS>import_national_checklist.yml@96/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/IAS>import_national_checklist.yml@96/environment"
                        },
                        {
                            "source": "#main/pipeline@99",
                            "id": "#main/IAS>import_national_checklist.yml@96/first_record_column"
                        },
                        {
                            "source": "#main/pipeline@97",
                            "id": "#main/IAS>import_national_checklist.yml@96/national_checklist"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__import_national_checklist/96' } : null)",
                            "id": "#main/IAS>import_national_checklist.yml@96/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/IAS>import_national_checklist.yml@96/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@98",
                            "id": "#main/IAS>import_national_checklist.yml@96/species_column"
                        }
                    ],
                    "out": [
                        "#main/IAS>import_national_checklist.yml@96/national_checklist_out"
                    ],
                    "id": "#main/IAS>import_national_checklist.yml@96"
                },
                {
                    "run": "#merge_datasets.cwl",
                    "in": [
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80/cleaning_summary_out",
                            "id": "#main/IAS>merge_datasets.yml@52/cleaning_summary"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/IAS>merge_datasets.yml@52/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@41",
                            "id": "#main/IAS>merge_datasets.yml@52/country_name"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__merge_datasets' } : null)",
                            "id": "#main/IAS>merge_datasets.yml@52/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/IAS>merge_datasets.yml@52/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/IAS>merge_datasets.yml@52/environment"
                        },
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80/first_records_clean_out",
                            "id": "#main/IAS>merge_datasets.yml@52/first_records_clean"
                        },
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80/full_taxa_list_out",
                            "id": "#main/IAS>merge_datasets.yml@52/full_taxa_list"
                        },
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80/griis_clean_out",
                            "id": "#main/IAS>merge_datasets.yml@52/griis_clean"
                        },
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80/national_clean_out",
                            "id": "#main/IAS>merge_datasets.yml@52/national_clean"
                        },
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80/qc_status_out",
                            "id": "#main/IAS>merge_datasets.yml@52/qc_status"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__merge_datasets/52' } : null)",
                            "id": "#main/IAS>merge_datasets.yml@52/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/IAS>merge_datasets.yml@52/scripts_root"
                        },
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80/unmatched_values_out",
                            "id": "#main/IAS>merge_datasets.yml@52/unmatched_values"
                        }
                    ],
                    "out": [
                        "#main/IAS>merge_datasets.yml@52/merged_dataset_out",
                        "#main/IAS>merge_datasets.yml@52/data_quality_report_out",
                        "#main/IAS>merge_datasets.yml@52/run_summary_out",
                        "#main/IAS>merge_datasets.yml@52/merge_summary_out",
                        "#main/IAS>merge_datasets.yml@52/merge_conflicts_out"
                    ],
                    "id": "#main/IAS>merge_datasets.yml@52"
                },
                {
                    "run": "#model_data.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/IAS>model_data.yml@81/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@41",
                            "id": "#main/IAS>model_data.yml@81/country_name"
                        },
                        {
                            "source": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/gbif_country_observations_out",
                            "id": "#main/IAS>model_data.yml@81/covariate_data"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__model_data' } : null)",
                            "id": "#main/IAS>model_data.yml@81/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/IAS>model_data.yml@81/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/IAS>model_data.yml@81/environment"
                        },
                        {
                            "source": "#main/IAS>merge_datasets.yml@52/merged_dataset_out",
                            "id": "#main/IAS>model_data.yml@81/integrated_data"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__model_data/81' } : null)",
                            "id": "#main/IAS>model_data.yml@81/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/IAS>model_data.yml@81/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/IAS>model_data.yml@81/model_outputs_out",
                        "#main/IAS>model_data.yml@81/model_decision_out",
                        "#main/IAS>model_data.yml@81/data_summary_out",
                        "#main/IAS>model_data.yml@81/model_input_out",
                        "#main/IAS>model_data.yml@81/qualitative_plot_out",
                        "#main/IAS>model_data.yml@81/qualitative_interpretation_out",
                        "#main/IAS>model_data.yml@81/quantitative_plot_out"
                    ],
                    "id": "#main/IAS>model_data.yml@81"
                },
                {
                    "run": "#prepare_datasets.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/IAS>prepare_datasets.yml@80/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@41",
                            "id": "#main/IAS>prepare_datasets.yml@80/country_name"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__prepare_datasets' } : null)",
                            "id": "#main/IAS>prepare_datasets.yml@80/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/IAS>prepare_datasets.yml@80/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/IAS>prepare_datasets.yml@80/environment"
                        },
                        {
                            "source": "#main/IAS>download_firstrecords.yml@37/firstrecords_cleaned_out",
                            "id": "#main/IAS>prepare_datasets.yml@80/first_records"
                        },
                        {
                            "default": "/scripts/IAS/species_isInvasiveAnywhere.csv",
                            "id": "#main/IAS>prepare_datasets.yml@80/global_invasive_checklist"
                        },
                        {
                            "source": "#main/IAS>download_griischecklist.yml@38/griis_checklist_out",
                            "id": "#main/IAS>prepare_datasets.yml@80/griis_checklist"
                        },
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80|habitats",
                            "id": "#main/IAS>prepare_datasets.yml@80/habitats"
                        },
                        {
                            "source": "#main/IAS>prepare_datasets.yml@80|kingdoms",
                            "id": "#main/IAS>prepare_datasets.yml@80/kingdoms"
                        },
                        {
                            "source": "#main/IAS>import_national_checklist.yml@96/national_checklist_out",
                            "id": "#main/IAS>prepare_datasets.yml@80/national_checklist"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__prepare_datasets/80' } : null)",
                            "id": "#main/IAS>prepare_datasets.yml@80/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/IAS>prepare_datasets.yml@80/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/IAS>prepare_datasets.yml@80/global_invasive_matches_out",
                        "#main/IAS>prepare_datasets.yml@80/griis_clean_out",
                        "#main/IAS>prepare_datasets.yml@80/first_records_clean_out",
                        "#main/IAS>prepare_datasets.yml@80/national_clean_out",
                        "#main/IAS>prepare_datasets.yml@80/file_info_out",
                        "#main/IAS>prepare_datasets.yml@80/translated_locations_out",
                        "#main/IAS>prepare_datasets.yml@80/full_taxa_list_out",
                        "#main/IAS>prepare_datasets.yml@80/translated_event_dates_out",
                        "#main/IAS>prepare_datasets.yml@80/cleaning_summary_out",
                        "#main/IAS>prepare_datasets.yml@80/qc_status_out",
                        "#main/IAS>prepare_datasets.yml@80/unmatched_values_out",
                        "#main/IAS>prepare_datasets.yml@80/excluded_records_out"
                    ],
                    "id": "#main/IAS>prepare_datasets.yml@80"
                },
                {
                    "run": "#summarise_ias.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/IAS>summarise_ias.yml@76/condaPackURL"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__summarise_ias' } : null)",
                            "id": "#main/IAS>summarise_ias.yml@76/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/IAS>summarise_ias.yml@76/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/IAS>summarise_ias.yml@76/environment"
                        },
                        {
                            "source": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/gbif_country_observations_out",
                            "id": "#main/IAS>summarise_ias.yml@76/gbif_country_observations"
                        },
                        {
                            "source": "#main/IAS>merge_datasets.yml@52/merged_dataset_out",
                            "id": "#main/IAS>summarise_ias.yml@76/merged_dataset"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/IAS__summarise_ias/76' } : null)",
                            "id": "#main/IAS>summarise_ias.yml@76/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/IAS>summarise_ias.yml@76/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/IAS>summarise_ias.yml@76/ias_summary_out",
                        "#main/IAS>summarise_ias.yml@76/ias_annual_summary_out",
                        "#main/IAS>summarise_ias.yml@76/ias_summary_table_out"
                    ],
                    "id": "#main/IAS>summarise_ias.yml@76"
                },
                {
                    "run": "#get_GBIF_country_SQL.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@41",
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/country_name"
                        },
                        {
                            "source": "#main/pipeline@74",
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/end_year"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__get_GBIF_country_SQL' } : null)",
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/environment"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__get_GBIF_country_SQL/91' } : null)",
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@73",
                            "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/start_year"
                        }
                    ],
                    "out": [
                        "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91/gbif_country_observations_out"
                    ],
                    "id": "#main/data>getGBIFObservations>get_GBIF_country_SQL.yml@91"
                },
                {
                    "when": "$(inputs.envFolderWrite != null)",
                    "run": {
                        "class": "CommandLineTool",
                        "requirements": [
                            {
                                "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-2d34335",
                                "class": "DockerRequirement"
                            },
                            {
                                "envDef": [
                                    {
                                        "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                                        "envName": "CONDA_ENVS_PATH"
                                    },
                                    {
                                        "envValue": "$(inputs.condaPackURL)",
                                        "envName": "CONDA_PACK_URL"
                                    },
                                    {
                                        "envValue": "/conda-env-yml/pkgs",
                                        "envName": "CONDA_PKGS_DIRS"
                                    },
                                    {
                                        "envValue": "$(inputs.runFolderWrite ? inputs.runFolderWrite.path : runtime.outdir)",
                                        "envName": "OUTPUT_LOCATION"
                                    },
                                    {
                                        "envValue": "/script-stubs",
                                        "envName": "SCRIPT_STUBS_LOCATION"
                                    }
                                ],
                                "class": "EnvVarRequirement"
                            },
                            {
                                "listing": "${\n  return [\n    { entry: inputs.envFolderWrite, writable: true },\n    {\n      entry: { \"class\": \"Directory\", \"basename\": \"conda-env-yml\", \"listing\": [] },\n      entryname: \"/conda-env-yml\",\n      writable: true\n    }\n  ].concat(\n    inputs.runFolderWrite\n      ? [{ entry: inputs.runFolder, writable: true }]\n      : []\n  );\n}\n",
                                "class": "InitialWorkDirRequirement"
                            },
                            {
                                "class": "InlineJavascriptRequirement"
                            },
                            {
                                "inplaceUpdate": true,
                                "class": "InplaceUpdateRequirement"
                            },
                            {
                                "networkAccess": true,
                                "class": "NetworkAccess"
                            }
                        ],
                        "baseCommand": [
                            "bash",
                            "-c"
                        ],
                        "arguments": [
                            "echo \"Exporting all environments\"\nmkdir -p \"$OUTPUT_LOCATION\" \"$CONDA_PKGS_DIRS\" /conda-env-yml/envs\n\nfunction getPackedEnv {\n  condaEnvName=$1\n  condaEnvYml=$2\n  # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context\n  dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName\n  mkdir -p \"$dedicatedEnvFolder\"\n  \n  echo \"Exporting $condaEnvName...\"\n  source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh \"$OUTPUT_LOCATION\" \"$condaEnvName\" \\\n    \"$condaEnvYml\" \"$dedicatedEnvFolder\" \"$CONDA_PACK_URL\" --noActivate\n  source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh \"$condaEnvName\" \"$dedicatedEnvFolder\"\n  echo \"Done.\"\n}\nexport -f getPackedEnv\n\nbash -c 'getPackedEnv \"IAS__download_firstrecords\" \"channels: [conda-forge, r]\ndependencies: [r-jsonlite, r-dplyr, r-duckdb, r-rjson, r-stringr, r-openxlsx]\nname: IAS__download_firstrecords\n\"'\n\nbash -c 'getPackedEnv \"IAS__download_griischecklist\" \"channels: [conda-forge, r]\ndependencies: [r-xml, r-dplyr, r-stringr, r-readr, r-tidyrss, r-tidyr, r-rvest, r-rjson,\n  r-readxl, r-countrycode]\nname: IAS__download_griischecklist\n\"'\n\nbash -c 'getPackedEnv \"IAS__merge_datasets\" \"channels: [conda-forge, r]\ndependencies: [r-base, r-rjson]\nname: IAS__merge_datasets\n\"'\n\nbash -c 'getPackedEnv \"IAS__summarise_ias\" \"channels: [conda-forge, r]\ndependencies: [r-dplyr, r-gt, r-readr, r-stringr, r-tibble, r-tidyr, r-rjson]\nname: IAS__summarise_ias\n\"'\n\nbash -c 'getPackedEnv \"IAS__prepare_datasets\" \"channels: [conda-forge, r]\ndependencies: [r-dplyr, r-jsonlite, r-duckdb, r-rjson, r-stringr, r-rgbif, r-tidyr,\n  r-stringi, r-openxlsx]\nname: IAS__prepare_datasets\n\"'\n\nbash -c 'getPackedEnv \"IAS__model_data\" \"channels: [conda-forge, r]\ndependencies: [r-base, r-cli, r-dharma, r-dplyr, r-ggeffects, r-ggplot2, r-mass, r-metrics,\n  r-purrr, r-remotes, r-rjson, r-scales, r-tibble, r-tidyr]\nname: IAS__model_data\n\"'\n\nbash -c 'getPackedEnv \"data__getGBIFObservations__get_GBIF_country_SQL\" \"channels: [conda-forge, r]\ndependencies: [r-rgbif, r-countrycode, r-readr, r-rjson]\nname: data__getGBIFObservations__get_GBIF_country_SQL\n\"'\n\nbash -c 'getPackedEnv \"IAS__import_national_checklist\" \"channels: [conda-forge, r]\ndependencies: [r-base, r-rjson]\nname: IAS__import_national_checklist\n\"'\n"
                        ],
                        "inputs": [
                            {
                                "type": "string",
                                "id": "#main/preparePackedEnvs/run/condaPackURL"
                            },
                            {
                                "type": [
                                    "null",
                                    "Directory"
                                ],
                                "id": "#main/preparePackedEnvs/run/envFolderWrite"
                            },
                            {
                                "type": [
                                    "null",
                                    "Directory"
                                ],
                                "id": "#main/preparePackedEnvs/run/runFolderWrite"
                            }
                        ],
                        "outputs": [
                            {
                                "type": "Directory",
                                "outputBinding": {
                                    "glob": ".",
                                    "outputEval": "$(inputs.envFolderWrite)"
                                },
                                "id": "#main/preparePackedEnvs/run/envFolder"
                            }
                        ]
                    },
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/preparePackedEnvs/condaPackURL"
                        },
                        {
                            "source": "#main/envFolder",
                            "id": "#main/preparePackedEnvs/envFolderWrite"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$({ class: 'Directory', location: (self ? self.location : '/tmp/cwl' ) + '/preparePackedEnvs' })",
                            "id": "#main/preparePackedEnvs/runFolder"
                        }
                    ],
                    "out": [
                        "#main/preparePackedEnvs/envFolder"
                    ],
                    "id": "#main/preparePackedEnvs"
                },
                {
                    "doc": "Copy or download environment file (runner.env) into a CWL output. This step is a patch to go around issue https://github.com/common-workflow-language/cwltool/issues/1842.",
                    "when": "$(inputs.environment != null)",
                    "in": [
                        {
                            "source": "#main/environment",
                            "id": "#main/prepareRunnerEnv/environment"
                        }
                    ],
                    "out": [
                        "#main/prepareRunnerEnv/environmentFile"
                    ],
                    "run": {
                        "class": "CommandLineTool",
                        "requirements": [
                            {
                                "envDef": [
                                    {
                                        "envValue": "$(inputs.environment)",
                                        "envName": "RUNNER_ENV_URI"
                                    }
                                ],
                                "class": "EnvVarRequirement"
                            },
                            {
                                "class": "InlineJavascriptRequirement"
                            },
                            {
                                "networkAccess": true,
                                "class": "NetworkAccess"
                            }
                        ],
                        "baseCommand": [
                            "bash",
                            "-c"
                        ],
                        "arguments": [
                            "echo \"Preparing runner.env...\"\n\nif [[ \"$RUNNER_ENV_URI\" == http://* ||\n        \"$RUNNER_ENV_URI\" == https://* ||\n        \"$RUNNER_ENV_URI\" == file://* ]]; then\n  if ! curl -fsSL \"$RUNNER_ENV_URI\" -o runner.env; then\n    echo \"ERROR: failed to download runner.env from $RUNNER_ENV_URI\" >&2\n    exit 1\n  fi\n  source runner.env\nelse\n  echo \"ERROR: environment file input, BON in a Box's \"runner.env\", was not provided as an URI.\" >&2\n  echo \"Please use the format file:// or https://\" >&2\n  exit 1;\nfi\n"
                        ],
                        "inputs": [
                            {
                                "type": "string",
                                "id": "#main/prepareRunnerEnv/run/environment"
                            }
                        ],
                        "outputs": [
                            {
                                "type": [
                                    "null",
                                    "File"
                                ],
                                "outputBinding": {
                                    "glob": "runner.env"
                                },
                                "id": "#main/prepareRunnerEnv/run/environmentFile"
                            }
                        ]
                    },
                    "id": "#main/prepareRunnerEnv"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "SInAS data-quality report",
                    "doc": "Combined quality-control status, unmatched values, and merge conflicts, including the action taken for each issue.",
                    "outputSource": "#main/IAS>merge_datasets.yml@52/data_quality_report_out",
                    "id": "#main/IAS>merge_datasets.yml@52|data_quality_report_out"
                },
                {
                    "type": "File",
                    "label": "SInAS merged dataset",
                    "doc": "One record per standardised taxon-location-establishment combination.",
                    "outputSource": "#main/IAS>merge_datasets.yml@52/merged_dataset_out",
                    "id": "#main/IAS>merge_datasets.yml@52|merged_dataset_out"
                },
                {
                    "type": "File",
                    "label": "SInAS run summary",
                    "doc": "Preparation and merge record counts, warning counts, exclusions, and overall quality-control status.",
                    "outputSource": "#main/IAS>merge_datasets.yml@52/run_summary_out",
                    "id": "#main/IAS>merge_datasets.yml@52|run_summary_out"
                },
                {
                    "type": "File",
                    "label": "Modelling data summary",
                    "doc": "Data-adequacy statistics for the selected country. First-record completeness is the percentage of GRIIS taxa flagged invasive anywhere that have a first-record year; it is not overall checklist completeness.",
                    "outputSource": "#main/IAS>model_data.yml@81/data_summary_out",
                    "id": "#main/IAS>model_data.yml@81|data_summary_out"
                },
                {
                    "type": "File",
                    "label": "Modelling decision",
                    "doc": "Selected data scenario, adequacy criteria, supported level of inference, interpretation guidance, shared scope, and references.",
                    "outputSource": "#main/IAS>model_data.yml@81/model_decision_out",
                    "id": "#main/IAS>model_data.yml@81|model_decision_out"
                },
                {
                    "type": "File",
                    "label": "Model outputs",
                    "doc": "Model assumptions, parameters, fit statistics, convergence status, estimated trend direction, interpretation, and caveats for every model option. First-record trends are not automatically equivalent to introduction trends.",
                    "outputSource": "#main/IAS>model_data.yml@81/model_outputs_out",
                    "id": "#main/IAS>model_data.yml@81|model_outputs_out"
                },
                {
                    "type": "string",
                    "label": "Qualitative model interpretation",
                    "doc": "Interpretation selected from the fitted IAS-observation and survey-effort trend combination. A trend is classified as stable when its fitted time slope is not significant at alpha = 0.05.",
                    "outputSource": "#main/IAS>model_data.yml@81/qualitative_interpretation_out",
                    "id": "#main/IAS>model_data.yml@81|qualitative_interpretation_out"
                },
                {
                    "type": "File",
                    "label": "Qualitative model plot",
                    "doc": "Descriptive comparison of annual IAS first records with the GBIF observation proxy. Similar patterns may indicate an observation-effort effect; this plot is not a corrected introduction-rate estimate.",
                    "outputSource": "#main/IAS>model_data.yml@81/qualitative_plot_out",
                    "id": "#main/IAS>model_data.yml@81|qualitative_plot_out"
                },
                {
                    "type": "File",
                    "label": "Quantitative model comparison",
                    "doc": "Fitted annual discovery records from models with alternative detection assumptions. Compare fit statistics only among converged models fitted to the same country and time series.",
                    "outputSource": "#main/IAS>model_data.yml@81/quantitative_plot_out",
                    "id": "#main/IAS>model_data.yml@81|quantitative_plot_out"
                },
                {
                    "type": "File",
                    "label": "SInAS excluded records",
                    "doc": "Complete source records excluded from the merge because their locations could not be standardised.",
                    "outputSource": "#main/IAS>prepare_datasets.yml@80/excluded_records_out",
                    "id": "#main/IAS>prepare_datasets.yml@80|excluded_records_out"
                },
                {
                    "label": "Country name",
                    "doc": "Name of the country for the Invasive Alien Species analysis.",
                    "type": {
                        "type": "record",
                        "name": "#main/pipeline@41|default_output_out/country",
                        "fields": [
                            {
                                "name": "#main/pipeline@41|default_output_out/country/country",
                                "type": {
                                    "name": "#main/pipeline@41|default_output_out/country/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@41|default_output_out/country/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@41|default_output_out/country/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@41|default_output_out/country/country/countryDefinition/bboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#main/pipeline@41|default_output_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
