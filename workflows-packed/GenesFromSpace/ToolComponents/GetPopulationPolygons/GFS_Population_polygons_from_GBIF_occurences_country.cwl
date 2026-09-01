{
    "$graph": [
        {
            "class": "CommandLineTool",
            "label": "Get bbox",
            "doc": [
                "Description:\nThis script returns the bounding box of the study area.\n",
                "Authors:\nSimon Pahls\nOliver Selmoni\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-eee5c95",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
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
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
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
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    countries: inputs.countries,\n    proj: inputs.proj,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"rbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#get_bbox.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "Countries list",
                    "doc": "countries of interest, will be used to look for GBIF observations.",
                    "default": [
                        "Mexico",
                        "Guatemala"
                    ],
                    "id": "#get_bbox.cwl/countries"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#get_bbox.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#get_bbox.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#get_bbox.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "projection system",
                    "doc": "Integer, projection system",
                    "default": 4326,
                    "id": "#get_bbox.cwl/proj"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#get_bbox.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "GFS_IndicatorsTool/get_bbox.R",
                    "id": "#get_bbox.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#get_bbox.cwl/scripts_root"
                }
            ],
            "id": "#get_bbox.cwl",
            "outputs": [
                {
                    "type": {
                        "type": "array",
                        "items": "float"
                    },
                    "label": "bbox",
                    "doc": "boundary box around area of interest",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"bbox\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return parseFloat(value);\n  });\n}\n"
                    },
                    "id": "#get_bbox.cwl/bbox_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#get_bbox.cwl/logs"
                }
            ]
        },
        {
            "class": "CommandLineTool",
            "label": "Get population polygons",
            "doc": [
                "Description:\nGiven the coordinates of species occurrence, the scripts returns polygons describing spatial distribution of species popualtions.\n",
                "Authors:\nSimon Pahls\nOliver Selmoni\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-eee5c95",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
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
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
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
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    species_obs: inputs.species_obs ? inputs.species_obs.path : null,\n    buffer_size: inputs.buffer_size,\n    pop_distance: inputs.pop_distance,\n    countries: inputs.countries,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"rbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Size of buffer",
                    "doc": "Radius size [in km] to determine population presence around the coordinates of species observations.",
                    "default": 10,
                    "id": "#get_pop_poly.cwl/buffer_size"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#get_pop_poly.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "Countries of interest",
                    "doc": "Optional list of countries to restrict the population polygons calculations.",
                    "default": [
                        "Mexico",
                        "Guatemala"
                    ],
                    "id": "#get_pop_poly.cwl/countries"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#get_pop_poly.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#get_pop_poly.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#get_pop_poly.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Distance between populations",
                    "doc": "Distance [in km] to separate species observations in different populations.",
                    "default": 50,
                    "id": "#get_pop_poly.cwl/pop_distance"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#get_pop_poly.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "GFS_IndicatorsTool/get_pop_poly.R",
                    "id": "#get_pop_poly.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#get_pop_poly.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Coordinates of species occurrence",
                    "doc": "Path to the table storing the species observation coordinates. The table must incude header with \"decimal_longitude\" and \"decimal_latitude\" columns, indicating the coordinates of every observation.",
                    "default": "/userdata/obs_data.tsv",
                    "id": "#get_pop_poly.cwl/species_obs"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#get_pop_poly.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Polygons of populations",
                    "doc": "Path to geojson file storing polygons of populations.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"population_polygons\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#get_pop_poly.cwl/population_polygons_out"
                }
            ],
            "id": "#get_pop_poly.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "GBIF Observations < 100 000",
            "doc": [
                "Description:\nThis script gets observations from GBIF database, using the package RGIF.\n",
                "Lifecycle tag: Deprecated. Please use script \"GBIF Observations from Download API\" (getGBIFObservations) instead\n",
                "Authors:\nSarah Valentin (https://orcid.org/0000-0002-9028-681X)\n",
                "External link: https://github.com/ropensci/rgbif"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-eee5c95",
                    "class": "DockerRequirement"
                },
                {
                    "envDef": [
                        {
                            "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                            "envName": "CONDA_ENVS_PATH"
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
                            "envValue": "/scripts",
                            "envName": "SCRIPT_LOCATION"
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
                }
            ],
            "baseCommand": [
                "bash",
                "-c"
            ],
            "arguments": [
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    species: inputs.species,\n    country: inputs.country,\n    year_start: inputs.year_start,\n    year_end: inputs.year_end,\n    bbox: inputs.bbox,\n    proj: inputs.proj,\n    occurrence_status: inputs.occurrence_status,\n    limit: inputs.limit,\n    bbox_buffer: inputs.bbox_buffer,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"rbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "float"
                        }
                    ],
                    "label": "bbox",
                    "doc": "Vector of float, bbox coordinates of the bbox in the order xmin, ymin, xmax, ymax",
                    "default": [
                        -2316297,
                        -1971146,
                        1015207,
                        1511916
                    ],
                    "id": "#getObservations.cwl/bbox"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "bbox buffer",
                    "doc": "Interger, width of the buffer around the bbox containing the presence points.",
                    "default": 0,
                    "id": "#getObservations.cwl/bbox_buffer"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#getObservations.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "country",
                    "doc": "Optional string, country to retrieve the occurrences from. Leave blank to ignore administrative boundaries.",
                    "id": "#getObservations.cwl/country"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#getObservations.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#getObservations.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#getObservations.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "limit",
                    "doc": "Integer, maximum number of observations to retrieve from GBIF database (upper limit 100000)",
                    "default": 2000,
                    "id": "#getObservations.cwl/limit"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#getObservations.cwl/occurrence_status/present",
                            "#getObservations.cwl/occurrence_status/absent",
                            "#getObservations.cwl/occurrence_status/present absent"
                        ]
                    },
                    "label": "occurrence status",
                    "doc": "String, type of occurrence status (corresponds to the occurrenceStatus GBIF column)",
                    "default": "present",
                    "id": "#getObservations.cwl/occurrence_status"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "projection system",
                    "doc": "String, projection system of the coordinates in bbox",
                    "default": "EPSG:6623",
                    "id": "#getObservations.cwl/proj"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#getObservations.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "data/getObservations.R",
                    "id": "#getObservations.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#getObservations.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "species names",
                    "doc": "Scientific name of the species",
                    "default": "Glyptemys insculpta",
                    "id": "#getObservations.cwl/species"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "end year",
                    "doc": "Integer, 4 digit year, end date to retrieve occurrences",
                    "default": 2020,
                    "id": "#getObservations.cwl/year_end"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "start year",
                    "doc": "Integer, 4 digit year, start date to retrieve occurrences",
                    "default": 1990,
                    "id": "#getObservations.cwl/year_start"
                }
            ],
            "outputs": [
                {
                    "type": {
                        "type": "array",
                        "items": "float"
                    },
                    "label": "bbox",
                    "doc": "Vector of float, bbox coordinates of the extent in the order xmin, ymin, xmax, ymax",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"bbox\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return parseFloat(value);\n  });\n}\n"
                    },
                    "id": "#getObservations.cwl/bbox_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#getObservations.cwl/logs"
                },
                {
                    "type": "int",
                    "label": "number of presence points",
                    "doc": "Integer, number of presence points retrieved",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"n_presence\");\n  if (value === null) return null;\n  return parseInt(value);\n}\n"
                    },
                    "id": "#getObservations.cwl/n_presence_out"
                },
                {
                    "type": "File",
                    "label": "presence",
                    "doc": "Table, observations retrieved from GBIF database",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"presence\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#getObservations.cwl/presence_out"
                }
            ],
            "id": "#getObservations.cwl"
        },
        {
            "class": "Workflow",
            "label": "Get population polygons for country list",
            "doc": [
                "Description:\nComponent of the Genes from Space tool. Given a list of countries, a species of interest, and a time window, the tool retrives the occurrences of the species from GBIF, and then calculates population polygons based on geographical proximity. \n",
                "Authors:\nOliver Selmoni (oliver.selmoni@gmail.com)\n",
                "External link: https://teams.issibern.ch/genesfromspace/",
                "References:\nSchuman et al., EcoEvoRxiv.\nnull\n"
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
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Size of buffer",
                    "doc": "Radius size [in km] to determine population presence around the coordinates of species observations.",
                    "default": 10,
                    "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5|buffer_size"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Distance between populations",
                    "doc": "Distance [in km] to separate species observations in different populations.",
                    "default": 50,
                    "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5|pop_distance"
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
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#main/environment"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Species names",
                    "doc": "Scientific name of the species, used to look for occurrences in GBIF.",
                    "default": "Quercus sartorii",
                    "id": "#main/pipeline@12"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Start year",
                    "doc": "Integer, 4 digit year, start date to retrieve occurrences",
                    "default": 1980,
                    "id": "#main/pipeline@14"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "End year",
                    "doc": "Integer, 4 digit year, end date to retrieve occurrences",
                    "default": 2000,
                    "id": "#main/pipeline@15"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "projection system",
                    "doc": "String, projection system of the coordinates in bbox",
                    "default": "EPSG:4326",
                    "id": "#main/pipeline@16"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "Countries list",
                    "doc": "countries of interest, will be used to look for GBIF observations.",
                    "default": [
                        "Mexico",
                        "Guatemala"
                    ],
                    "id": "#main/pipeline@22"
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
                    "run": "#get_bbox.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/GFS_IndicatorsTool>get_bbox.yml@21/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@22",
                            "id": "#main/GFS_IndicatorsTool>get_bbox.yml@21/countries"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/GFS_IndicatorsTool>get_bbox.yml@21/environment"
                        },
                        {
                            "source": "#main/pipeline@16",
                            "id": "#main/GFS_IndicatorsTool>get_bbox.yml@21/proj"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_bbox/21' } : null)",
                            "id": "#main/GFS_IndicatorsTool>get_bbox.yml@21/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/GFS_IndicatorsTool>get_bbox.yml@21/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/GFS_IndicatorsTool>get_bbox.yml@21/bbox_out"
                    ],
                    "id": "#main/GFS_IndicatorsTool>get_bbox.yml@21"
                },
                {
                    "run": "#get_pop_poly.cwl",
                    "in": [
                        {
                            "source": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5|buffer_size",
                            "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/buffer_size"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@22",
                            "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/countries"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/environment"
                        },
                        {
                            "source": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5|pop_distance",
                            "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/pop_distance"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_pop_poly/5' } : null)",
                            "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/scripts_root"
                        },
                        {
                            "source": "#main/data>getObservations.yml@10/presence_out",
                            "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/species_obs"
                        }
                    ],
                    "out": [
                        "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/population_polygons_out"
                    ],
                    "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5"
                },
                {
                    "run": "#getObservations.cwl",
                    "in": [
                        {
                            "source": "#main/GFS_IndicatorsTool>get_bbox.yml@21/bbox_out",
                            "id": "#main/data>getObservations.yml@10/bbox"
                        },
                        {
                            "default": 0,
                            "id": "#main/data>getObservations.yml@10/bbox_buffer"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>getObservations.yml@10/condaPackURL"
                        },
                        {
                            "default": null,
                            "id": "#main/data>getObservations.yml@10/country"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>getObservations.yml@10/environment"
                        },
                        {
                            "default": 2000,
                            "id": "#main/data>getObservations.yml@10/limit"
                        },
                        {
                            "default": "present",
                            "id": "#main/data>getObservations.yml@10/occurrence_status"
                        },
                        {
                            "source": "#main/pipeline@16",
                            "id": "#main/data>getObservations.yml@10/proj"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__getObservations/10' } : null)",
                            "id": "#main/data>getObservations.yml@10/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>getObservations.yml@10/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@12",
                            "id": "#main/data>getObservations.yml@10/species"
                        },
                        {
                            "source": "#main/pipeline@15",
                            "id": "#main/data>getObservations.yml@10/year_end"
                        },
                        {
                            "source": "#main/pipeline@14",
                            "id": "#main/data>getObservations.yml@10/year_start"
                        }
                    ],
                    "out": [
                        "#main/data>getObservations.yml@10/n_presence_out",
                        "#main/data>getObservations.yml@10/presence_out",
                        "#main/data>getObservations.yml@10/bbox_out"
                    ],
                    "id": "#main/data>getObservations.yml@10"
                },
                {
                    "when": "$(inputs.envFolderWrite != null)",
                    "run": {
                        "class": "CommandLineTool",
                        "requirements": [
                            {
                                "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-eee5c95",
                                "class": "DockerRequirement"
                            },
                            {
                                "envDef": [
                                    {
                                        "envValue": "/opt/conda/envs:/conda-env-yml/envs",
                                        "envName": "CONDA_ENVS_PATH"
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
                            "echo \"Exporting all environments\"\nmkdir -p \"$OUTPUT_LOCATION\" \"$CONDA_PKGS_DIRS\" /conda-env-yml/envs\n\nfunction getPackedEnv {\n  condaEnvName=$1\n  condaEnvYml=$2\n  # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context\n  dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName\n  mkdir -p \"$dedicatedEnvFolder\"\n  \n  echo \"Exporting $condaEnvName...\"\n  source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh \"$OUTPUT_LOCATION\" \"$condaEnvName\" \\\n    \"$condaEnvYml\" \"$dedicatedEnvFolder\" \"$(inputs.condaPackURL)\" --noActivate\n  source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh \"$condaEnvName\" \"$dedicatedEnvFolder\"\n  echo \"Done.\"\n}\nexport -f getPackedEnv\n"
                        ],
                        "inputs": [
                            {
                                "type": "string",
                                "id": "#main/prepareEnvironments/run/condaPackURL"
                            },
                            {
                                "type": [
                                    "null",
                                    "Directory"
                                ],
                                "id": "#main/prepareEnvironments/run/envFolderWrite"
                            },
                            {
                                "type": [
                                    "null",
                                    "Directory"
                                ],
                                "id": "#main/prepareEnvironments/run/runFolderWrite"
                            }
                        ],
                        "outputs": [
                            {
                                "type": "Directory",
                                "outputBinding": {
                                    "glob": ".",
                                    "outputEval": "$(inputs.envFolderWrite)"
                                },
                                "id": "#main/prepareEnvironments/run/envFolder"
                            }
                        ]
                    },
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/prepareEnvironments/condaPackURL"
                        },
                        {
                            "source": "#main/envFolder",
                            "id": "#main/prepareEnvironments/envFolderWrite"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$({ class: 'Directory', location: (self ? self.location : '/tmp/cwl' ) + '/prepareEnvironments' })",
                            "id": "#main/prepareEnvironments/runFolder"
                        }
                    ],
                    "out": [
                        "#main/prepareEnvironments/envFolder"
                    ],
                    "id": "#main/prepareEnvironments"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "Polygons of populations",
                    "doc": "Path to geojson file storing polygons of populations.",
                    "outputSource": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5/population_polygons_out",
                    "id": "#main/GFS_IndicatorsTool>get_pop_poly.yml@5|population_polygons_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
