{
    "$graph": [
        {
            "class": "CommandLineTool",
            "label": "Get genetic diversity indicators",
            "doc": [
                "Description:\nThis script takes the population habitat size information, and use it to compute genetic diversity indicators.\n",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    population_polygons: inputs.population_polygons ? inputs.population_polygons.path : null,\n    habitat_map: inputs.habitat_map ? inputs.habitat_map.path : null,\n    pop_area: inputs.pop_area ? inputs.pop_area.path : null,\n    ne_nc: inputs.ne_nc,\n    pop_density: inputs.pop_density,\n    runtitle: inputs.runtitle,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"GFS_IndicatorsTool__get_Indicators\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-devtools, r-rjson, r-terra, r-sf, r-rnaturalearth, r-teachingdemos,\n  r-dplyr, r-plotly, r-geojsonsf, r-colorspace, r-lwgeom]\nname: GFS_IndicatorsTool__get_Indicators\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh GFS_IndicatorsTool__get_Indicators /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#get_Indicators.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#get_Indicators.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#get_Indicators.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#get_Indicators.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Binary map of habitat presence/absence",
                    "doc": "Tif file of maps of presence (1) or absence (0) of suitable habitat. Multiple layers can stacked and used to describe habitat availability at different time points.",
                    "default": "/userdata/tcyy.tif",
                    "id": "#get_Indicators.cwl/habitat_map"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "float"
                        }
                    ],
                    "label": "Ne:Nc ratio estimate",
                    "doc": "Estimated Ne:Nc ratio for the studied species. Multiple values can be provided, separated by a comma.",
                    "default": [
                        0.1,
                        0.2
                    ],
                    "id": "#get_Indicators.cwl/ne_nc"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Table of habitat area by population",
                    "doc": "Table of estimated habitat area by population (rows). If provided, time points are displayed as columns.",
                    "default": "/userdata/pop_habitat_area.tsv",
                    "id": "#get_Indicators.cwl/pop_area"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "float"
                        }
                    ],
                    "label": "Population density",
                    "doc": "Estimated density of the population [number of individuals per km2]. Multiple values can be provided, separated by a comma.",
                    "default": [
                        50,
                        100,
                        1000
                    ],
                    "id": "#get_Indicators.cwl/pop_density"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Polygons of populations",
                    "doc": "Path to geojson file storing polygons of populations.",
                    "default": "/userdata/population_polygons.geojson",
                    "id": "#get_Indicators.cwl/population_polygons"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#get_Indicators.cwl/runFolder"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Title of the run",
                    "doc": "Set a name for the pipeline run.",
                    "default": "Quercus sartorii, Mexico, Habitat decline by tree cover loss, 2000-2023",
                    "id": "#get_Indicators.cwl/runtitle"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "GFS_IndicatorsTool/get_Indicators.R",
                    "id": "#get_Indicators.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#get_Indicators.cwl/scripts_root"
                }
            ],
            "id": "#get_Indicators.cwl",
            "outputs": [
                {
                    "type": "File",
                    "label": "Interactive plot",
                    "doc": "An interactive interface to explore indicators trends across geographical space and time.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"interactive_plot\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#get_Indicators.cwl/interactive_plot_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#get_Indicators.cwl/logs"
                },
                {
                    "type": "float",
                    "label": "Ne>500 indicator",
                    "doc": "Estimated proportion of populations with Ne>500 at latest time point.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"ne500\");\n  if (value === null) return null;\n  return parseFloat(value);\n}\n"
                    },
                    "id": "#get_Indicators.cwl/ne500_out"
                },
                {
                    "type": "File",
                    "label": "Effective population size",
                    "doc": "Estimated effective size of every population, based on the latest time point of the habitat cover map.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"ne_table\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#get_Indicators.cwl/ne_table_out"
                },
                {
                    "type": "float",
                    "label": "Population maintained indicator",
                    "doc": "Estimated proportion of mantained populations, comparing earliest and latest time point. A value of 1 means that no populations went extinct over the time frame.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"pm\");\n  if (value === null) return null;\n  return parseFloat(value);\n}\n"
                    },
                    "id": "#get_Indicators.cwl/pm_out"
                }
            ]
        },
        {
            "class": "CommandLineTool",
            "label": "Get populations habitat area",
            "doc": [
                "Description:\nThis Script loads the populations polygons, one or more binary maps describing the presence/absence of a habitat, and calculates the area of habitat per population.\n",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    population_polygons: inputs.population_polygons ? inputs.population_polygons.path : null,\n    habitat_map: inputs.habitat_map ? inputs.habitat_map.path : null,\n    time_points: inputs.time_points,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"rbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#pop_area_by_habitat.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#pop_area_by_habitat.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#pop_area_by_habitat.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#pop_area_by_habitat.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Binary map of habitat presence/absence",
                    "doc": "Tif file describing presence (1) or absence (0) of suitable habitat. Multiple layers can be used to describe habitat availability at different time points.",
                    "default": "/userdata/tcyy.tif",
                    "id": "#pop_area_by_habitat.cwl/habitat_map"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Polygons of populations",
                    "doc": "Path to geojson file storing polygons of populations.",
                    "default": "/userdata/population_polygons.geojson",
                    "id": "#pop_area_by_habitat.cwl/population_polygons"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#pop_area_by_habitat.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "GFS_IndicatorsTool/pop_area_by_habitat.R",
                    "id": "#pop_area_by_habitat.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#pop_area_by_habitat.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "Time points of habitat map",
                    "doc": "List of time points corresponding to habitat map layers.",
                    "default": [
                        "y2000",
                        "y2001",
                        "y2002",
                        "y2003",
                        "y2004",
                        "y2005",
                        "y2006",
                        "y2007",
                        "y2008",
                        "y2009",
                        "y2010",
                        "y2011",
                        "y2012",
                        "y2013",
                        "y2014",
                        "y2015",
                        "y2016",
                        "y2017",
                        "y2018",
                        "y2019",
                        "y2020",
                        "y2021",
                        "y2022",
                        "y2023"
                    ],
                    "id": "#pop_area_by_habitat.cwl/time_points"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#pop_area_by_habitat.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Table of habitat area by population",
                    "doc": "Table of estimated habitat area by population (rows). If available, time points are displayed as columns.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"pop_area\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#pop_area_by_habitat.cwl/pop_area_out"
                }
            ],
            "id": "#pop_area_by_habitat.cwl"
        },
        {
            "class": "Workflow",
            "label": "Calculate genetic diversity indicators",
            "doc": [
                "Description:\nComponent of the Genes from Space tool. Given poylgons of population distribution (geojson format) and a raster stack describing habitat availability over time (geotiff format), the pipeline returns genetic diversity loss indicators (Ne500 and Populations Maintained indicator), displayed through an interactive interface. \n",
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
                        {
                            "type": "array",
                            "items": "float"
                        }
                    ],
                    "label": "Ne:Nc ratio estimate",
                    "doc": "Estimated Ne:Nc ratio for the studied species. Multiple values can be provided, separated by a comma.",
                    "default": [
                        0.1,
                        0.2
                    ],
                    "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|ne_nc"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "float"
                        }
                    ],
                    "label": "Population density",
                    "doc": "Estimated density of the population [number of individuals per km2]. Multiple values can be provided, separated by a comma.",
                    "default": [
                        50,
                        100,
                        1000
                    ],
                    "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|pop_density"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Title of the run",
                    "doc": "Set a name for the pipeline run.",
                    "default": "Quercus sartorii, Mexico, Habitat decline by tree cover loss, 2000-2023",
                    "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|runtitle"
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
                        "File"
                    ],
                    "label": "Polygons of populations",
                    "doc": "Path to geojson file storing polygons of populations.",
                    "default": "/userdata/population_polygons.geojson",
                    "id": "#main/pipeline@100"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Binary map of habitat presence/absence",
                    "doc": "Tif file describing presence (1) or absence (0) of suitable habitat. Multiple layers can be used to describe habitat availability at different time points.",
                    "default": "/userdata/tcyy.tif",
                    "id": "#main/pipeline@101"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "Time points of habitat map",
                    "doc": "List of time points corresponding to habitat map layers.",
                    "default": [
                        "y2000",
                        "y2001",
                        "y2002",
                        "y2003",
                        "y2004",
                        "y2005",
                        "y2006",
                        "y2007",
                        "y2008",
                        "y2009",
                        "y2010",
                        "y2011",
                        "y2012",
                        "y2013",
                        "y2014",
                        "y2015",
                        "y2016",
                        "y2017",
                        "y2018",
                        "y2019",
                        "y2020",
                        "y2021",
                        "y2022",
                        "y2023"
                    ],
                    "id": "#main/pipeline@102"
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
                    "run": "#get_Indicators.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/condaPackURL"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_Indicators' } : null)",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/environment"
                        },
                        {
                            "source": "#main/pipeline@101",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/habitat_map"
                        },
                        {
                            "source": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|ne_nc",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/ne_nc"
                        },
                        {
                            "source": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/pop_area_out",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/pop_area"
                        },
                        {
                            "source": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|pop_density",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/pop_density"
                        },
                        {
                            "source": "#main/pipeline@100",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/population_polygons"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_Indicators/127' } : null)",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/runFolder"
                        },
                        {
                            "source": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|runtitle",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/runtitle"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/GFS_IndicatorsTool>get_Indicators.yml@127/ne_table_out",
                        "#main/GFS_IndicatorsTool>get_Indicators.yml@127/pm_out",
                        "#main/GFS_IndicatorsTool>get_Indicators.yml@127/interactive_plot_out",
                        "#main/GFS_IndicatorsTool>get_Indicators.yml@127/ne500_out"
                    ],
                    "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127"
                },
                {
                    "run": "#pop_area_by_habitat.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/condaPackURL"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/environment"
                        },
                        {
                            "source": "#main/pipeline@101",
                            "id": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/habitat_map"
                        },
                        {
                            "source": "#main/pipeline@100",
                            "id": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/population_polygons"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__pop_area_by_habitat/99' } : null)",
                            "id": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@102",
                            "id": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/time_points"
                        }
                    ],
                    "out": [
                        "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99/pop_area_out"
                    ],
                    "id": "#main/GFS_IndicatorsTool>pop_area_by_habitat.yml@99"
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
                            "echo \"Exporting all environments\"\nmkdir -p \"$OUTPUT_LOCATION\" \"$CONDA_PKGS_DIRS\" /conda-env-yml/envs\n\nfunction getPackedEnv {\n  condaEnvName=$1\n  condaEnvYml=$2\n  # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context\n  dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName\n  mkdir -p \"$dedicatedEnvFolder\"\n  \n  echo \"Exporting $condaEnvName...\"\n  source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh \"$OUTPUT_LOCATION\" \"$condaEnvName\" \\\n    \"$condaEnvYml\" \"$dedicatedEnvFolder\" \"$(inputs.condaPackURL)\" --noActivate\n  source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh \"$condaEnvName\" \"$dedicatedEnvFolder\"\n  echo \"Done.\"\n}\nexport -f getPackedEnv\n\nbash -c 'getPackedEnv \"GFS_IndicatorsTool__get_Indicators\" \"channels: [conda-forge, r]\ndependencies: [r-devtools, r-rjson, r-terra, r-sf, r-rnaturalearth, r-teachingdemos,\n  r-dplyr, r-plotly, r-geojsonsf, r-colorspace, r-lwgeom]\nname: GFS_IndicatorsTool__get_Indicators\n\"'\n"
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
                    "label": "Interactive plot",
                    "doc": "An interactive interface to explore indicators trends across geographical space and time.",
                    "outputSource": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/interactive_plot_out",
                    "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|interactive_plot_out"
                },
                {
                    "type": "float",
                    "label": "Ne>500 indicator",
                    "doc": "Estimated proportion of populations with Ne>500 at latest time point.",
                    "outputSource": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/ne500_out",
                    "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|ne500_out"
                },
                {
                    "type": "File",
                    "label": "Effective population size",
                    "doc": "Estimated effective size of every population, based on the latest time point of the habitat cover map.",
                    "outputSource": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/ne_table_out",
                    "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|ne_table_out"
                },
                {
                    "type": "float",
                    "label": "Population maintained indicator",
                    "doc": "Estimated proportion of mantained populations, comparing earliest and latest time point.",
                    "outputSource": "#main/GFS_IndicatorsTool>get_Indicators.yml@127/pm_out",
                    "id": "#main/GFS_IndicatorsTool>get_Indicators.yml@127|pm_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
