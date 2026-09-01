{
    "$graph": [
        {
            "class": "CommandLineTool",
            "label": "Get tree canopy cover over time",
            "doc": [
                "Description:\nThis Script loads Tree Canopy Cover and forest Cover loss from STAC, crops rasters to the study area, and returns a stack of rasters describing forest presence/absence over time.\n",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    population_polygons: inputs.population_polygons ? inputs.population_polygons.path : null,\n    res: inputs.res,\n    yoi: inputs.yoi,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"rbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#get_TCY.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#get_TCY.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#get_TCY.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#get_TCY.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Polygons of populations",
                    "doc": "Path to geojson file storing polygons of populations.",
                    "default": "/userdata/population_polygons.geojson",
                    "id": "#get_TCY.cwl/population_polygons"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Resolution of tree cover map",
                    "doc": "Desired resolution for tree cover map, will be obtained via resampling. To be specified in decimal degrees (0.01 ~ 1 km). Minimal value 0.001 (~100m).",
                    "default": 0.01,
                    "id": "#get_TCY.cwl/res"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#get_TCY.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "GFS_IndicatorsTool/get_TCY.R",
                    "id": "#get_TCY.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#get_TCY.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "int"
                        }
                    ],
                    "label": "Years of interest",
                    "doc": "List of years for which tree cover should be extracted (maximum range 2000 - 2023).",
                    "default": [
                        2000,
                        2005,
                        2010,
                        2015,
                        2020
                    ],
                    "id": "#get_TCY.cwl/yoi"
                }
            ],
            "id": "#get_TCY.cwl",
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#get_TCY.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Tree cover year-by-year",
                    "doc": "Tif file of year-by-year tree cover, cropped to bbox extent",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"tcyy\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#get_TCY.cwl/tcyy_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "string"
                    },
                    "label": "Years with tree cover information",
                    "doc": "List of years for which tree cover information is available.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"time_points\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    return value;\n  });\n}\n"
                    },
                    "id": "#get_TCY.cwl/time_points_out"
                }
            ]
        },
        {
            "class": "Workflow",
            "label": "Get GFW forest cover change 2000-2023",
            "doc": [
                "Description:\nComponent of the Genes from Space tool. Given an area of interest, the tool creates a raster stack describing forest habitat presence for the years of interest (maximum range: from 2000 to 2023). Forest habitat presence made available by the Global Forest Watch (https://www.globalforestwatch.org/)\n",
                "Authors:\nOliver Selmoni (oliver.selmoni@gmail.com)\n",
                "External link: https://teams.issibern.ch/genesfromspace/",
                "References:\nSchuman et al., EcoEvoRxiv.\nnull\n\nHansen et al., Science (2013)\nnull\n"
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
                        "File"
                    ],
                    "label": "Polygons of populations",
                    "doc": "Path to geojson file storing polygons of populations.",
                    "default": "/userdata/populations.geojson",
                    "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23|population_polygons"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Resolution of tree cover map",
                    "doc": "Desired resolution for tree cover map, will be obtained via resampling. To be specified in decimal degrees (0.01 ~ 1 km). Minimal value 0.001 (~100m).",
                    "default": 0.01,
                    "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23|res"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "int"
                        }
                    ],
                    "label": "Years of interest",
                    "doc": "List of years for which tree cover should be extracted (maximum range 2000 - 2023).",
                    "default": [
                        2000,
                        2005,
                        2010,
                        2015,
                        2020
                    ],
                    "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23|yoi"
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
                    "run": "#get_TCY.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23/condaPackURL"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23/environment"
                        },
                        {
                            "source": "#main/GFS_IndicatorsTool>get_TCY.yml@23|population_polygons",
                            "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23/population_polygons"
                        },
                        {
                            "source": "#main/GFS_IndicatorsTool>get_TCY.yml@23|res",
                            "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23/res"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/GFS_IndicatorsTool__get_TCY/23' } : null)",
                            "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23/scripts_root"
                        },
                        {
                            "source": "#main/GFS_IndicatorsTool>get_TCY.yml@23|yoi",
                            "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23/yoi"
                        }
                    ],
                    "out": [
                        "#main/GFS_IndicatorsTool>get_TCY.yml@23/tcyy_out",
                        "#main/GFS_IndicatorsTool>get_TCY.yml@23/time_points_out"
                    ],
                    "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23"
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
                    "label": "Tree cover year-by-year",
                    "doc": "Tif file of year-by-year tree cover, cropped to bbox extent",
                    "outputSource": "#main/GFS_IndicatorsTool>get_TCY.yml@23/tcyy_out",
                    "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23|tcyy_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "string"
                    },
                    "label": "Years with tree cover information",
                    "doc": "List of years for which tree cover information is available.",
                    "outputSource": "#main/GFS_IndicatorsTool>get_TCY.yml@23/time_points_out",
                    "id": "#main/GFS_IndicatorsTool>get_TCY.yml@23|time_points_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
