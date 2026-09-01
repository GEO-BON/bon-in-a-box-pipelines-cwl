{
    "$graph": [
        {
            "class": "CommandLineTool",
            "label": "Python Example",
            "doc": [
                "Description:\nSample python script that increments a number.\n",
                "Lifecycle tag: Example.",
                "Authors:\nJean-Michel Lord (https://orcid.org/0009-0007-3826-1125)\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    some_int: inputs.some_int,\n    study_area_bbox: inputs.study_area_bbox,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"pythonbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\npython3 \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.py \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh pythonbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#helloPython.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#helloPython.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#helloPython.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#helloPython.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#helloPython.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "helloWorld/helloPython.py",
                    "id": "#helloPython.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#helloPython.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Some int",
                    "doc": "A number that we will increment",
                    "default": 3,
                    "id": "#helloPython.cwl/some_int"
                },
                {
                    "label": "Bounding box",
                    "doc": "Bounding box and CRS of study area",
                    "type": {
                        "type": "record",
                        "name": "#helloPython.cwl/study_area_bbox/bboxCRS",
                        "fields": [
                            {
                                "name": "#helloPython.cwl/study_area_bbox/bboxCRS/country",
                                "type": {
                                    "name": "#helloPython.cwl/study_area_bbox/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/country/countryDefinition/bboxWGS84",
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
                            },
                            {
                                "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS",
                                "type": {
                                    "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#helloPython.cwl/study_area_bbox/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#helloPython.cwl/study_area_bbox/bboxCRS/region",
                                "type": {
                                    "name": "#helloPython.cwl/study_area_bbox/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#helloPython.cwl/study_area_bbox/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#helloPython.cwl/study_area_bbox"
                }
            ],
            "id": "#helloPython.cwl",
            "outputs": [
                {
                    "type": "string",
                    "label": "CRS ID",
                    "doc": "ID of CRS obtained from bounding box selector",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"crs_id\");\n  return value;\n}\n"
                    },
                    "id": "#helloPython.cwl/crs_id_out"
                },
                {
                    "type": "int",
                    "label": "A number (input++)",
                    "doc": "bla bla",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"increment\");\n  if (value === null) return null;\n  return parseInt(value);\n}\n"
                    },
                    "id": "#helloPython.cwl/increment_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#helloPython.cwl/logs"
                }
            ]
        },
        {
            "class": "Workflow",
            "label": "Hello World pipeline",
            "doc": [
                "Description:\nThis very simple pipeline shows how to connect a single script to a single output.\nThe input of the script is left blank, thus becoming a pipeline input.\n",
                "Lifecycle tag: Example.",
                "Authors:\nJean-Michel Lord (https://orcid.org/0009-0007-3826-1125)\n",
                "External link: https://github.com/GEO-BON/biab-2.0"
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
                        "int"
                    ],
                    "label": "Some int",
                    "doc": "A number that we will increment",
                    "default": 3,
                    "id": "#main/helloWorld>helloPython.yml@0|some_int"
                },
                {
                    "label": "Bounding box",
                    "doc": "Bounding box and CRS of study area",
                    "type": {
                        "type": "record",
                        "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS",
                        "fields": [
                            {
                                "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/country",
                                "type": {
                                    "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/country/countryDefinition/bboxWGS84",
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
                            },
                            {
                                "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS",
                                "type": {
                                    "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/region",
                                "type": {
                                    "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/helloWorld>helloPython.yml@0|study_area_bbox/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#main/helloWorld>helloPython.yml@0|study_area_bbox"
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
                    "run": "#helloPython.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/helloWorld>helloPython.yml@0/condaPackURL"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/helloWorld>helloPython.yml@0/environment"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/helloWorld__helloPython/0' } : null)",
                            "id": "#main/helloWorld>helloPython.yml@0/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/helloWorld>helloPython.yml@0/scripts_root"
                        },
                        {
                            "source": "#main/helloWorld>helloPython.yml@0|some_int",
                            "id": "#main/helloWorld>helloPython.yml@0/some_int"
                        },
                        {
                            "source": "#main/helloWorld>helloPython.yml@0|study_area_bbox",
                            "id": "#main/helloWorld>helloPython.yml@0/study_area_bbox"
                        }
                    ],
                    "out": [
                        "#main/helloWorld>helloPython.yml@0/increment_out",
                        "#main/helloWorld>helloPython.yml@0/crs_id_out"
                    ],
                    "id": "#main/helloWorld>helloPython.yml@0"
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
                    "type": "int",
                    "label": "A number (input++)",
                    "doc": "bla bla",
                    "outputSource": "#main/helloWorld>helloPython.yml@0/increment_out",
                    "id": "#main/helloWorld>helloPython.yml@0|increment_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
