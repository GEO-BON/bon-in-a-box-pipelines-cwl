{
    "$graph": [
        {
            "class": "CommandLineTool",
            "label": "Range of Predictions",
            "doc": [
                "Description:\nThis script computes the range of a 95% confidence interval of a set of predictions rasters (from different models or from bootstrap/cross-validation procedures).\n",
                "Authors:\nSarah Valentin (https://orcid.org/0000-0002-9028-681X)\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    predictions: (inputs.predictions || []).map(function(file) { return file.path; }),\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"SDM__rangePredictions\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-terra, r-rjson, r-raster, r-dplyr]\nname: SDM__rangePredictions\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SDM__rangePredictions /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#rangePredictions.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#rangePredictions.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#rangePredictions.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#rangePredictions.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "predictions",
                    "doc": "predictions rasters",
                    "default": "/output/runSDM/modRunSDM_R/a2cb00aa7fb8278599666812601a9c76/sdm_pred.tif",
                    "id": "#rangePredictions.cwl/predictions"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#rangePredictions.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "SDM/rangePredictions.R",
                    "id": "#rangePredictions.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#rangePredictions.cwl/scripts_root"
                }
            ],
            "id": "#rangePredictions.cwl",
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#rangePredictions.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "range of predictions",
                    "doc": "range of a 95% confidence interval of a set of predictions",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"range_predictions\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#rangePredictions.cwl/range_predictions_out"
                }
            ]
        },
        {
            "class": "CommandLineTool",
            "label": "Remove Collinearity",
            "doc": [
                "Description:\nRemove collinearity between a series of predictor rasters with the exact same extent CRS and resolution\n",
                "Authors:\nSarah Valentin (https://orcid.org/0000-0002-9028-681X)\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    rasters: (inputs.rasters || []).map(function(file) { return file.path; }),\n    method: inputs.method,\n    method_cor_vif: inputs.method_cor_vif,\n    nb_sample: inputs.nb_sample,\n    cutoff_cor: inputs.cutoff_cor,\n    cutoff_vif: inputs.cutoff_vif,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"SDM__removeCollinearity\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-terra, r-rjson, r-dplyr, r-gdalcubes]\nname: SDM__removeCollinearity\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SDM__removeCollinearity /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#removeCollinearity.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "cutoff correlation",
                    "doc": "Float, correlation cutoff (used with vif.cor, pearson spearman and kendall method)",
                    "default": 0.75,
                    "id": "#removeCollinearity.cwl/cutoff_cor"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "VIF correlation",
                    "doc": "Integer, VIF correlation cutoff (used with vif.step method)",
                    "default": 8,
                    "id": "#removeCollinearity.cwl/cutoff_vif"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#removeCollinearity.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#removeCollinearity.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#removeCollinearity.cwl/environment"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#removeCollinearity.cwl/method/vif.cor",
                            "#removeCollinearity.cwl/method/vif.step",
                            "#removeCollinearity.cwl/method/pearson",
                            "#removeCollinearity.cwl/method/spearman",
                            "#removeCollinearity.cwl/method/kendall"
                        ]
                    },
                    "label": "method",
                    "doc": "Method used to compute collinearity between variables. Use `vif.cor` to remove variables using pairwise correlation followed by variance inflation factor checks, or `vif.step` to remove variables iteratively using only VIF. If your variables are skewed or have outliers you should favour the Spearman or Kendall methods. See the [`usdm` VIF documentation](https://babaknaimi.r-universe.dev/usdm/doc/manual.html) and this overview of [Pearson, Spearman, and Kendall correlations](https://library.virginia.edu/data/articles/correlation-pearson-spearman-and-kendalls-tau).",
                    "default": "vif.cor",
                    "id": "#removeCollinearity.cwl/method"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#removeCollinearity.cwl/method_cor_vif/pearson",
                            "#removeCollinearity.cwl/method_cor_vif/spearman",
                            "#removeCollinearity.cwl/method_cor_vif/kendall"
                        ]
                    },
                    "label": "correlation coefficient for vif.cor method",
                    "doc": "Option, method to calculate the coefficient of collinearity, only used if method == vif.cor.",
                    "default": "pearson",
                    "id": "#removeCollinearity.cwl/method_cor_vif"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "nb sample",
                    "doc": "Integer, number of points to select to calculate collinearity",
                    "default": 5000,
                    "id": "#removeCollinearity.cwl/nb_sample"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "rasters",
                    "doc": "Array of input raster paths. Environmental predictor rasters to screen for collinearity. Choose rasters that describe candidate environmental variables for the model",
                    "default": [],
                    "id": "#removeCollinearity.cwl/rasters"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#removeCollinearity.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "SDM/removeCollinearity.R",
                    "id": "#removeCollinearity.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#removeCollinearity.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#removeCollinearity.cwl/logs"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "rasters_selected",
                    "doc": "Array of output raster paths. Subset of input raster paths retained after removing highly collinear predictors. These rasters represent the environmental variables selected for downstream modeling.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"rasters_selected\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return { class: \"File\", location: \"file://\" + value };\n  });\n}\n"
                    },
                    "id": "#removeCollinearity.cwl/rasters_selected_out"
                }
            ],
            "id": "#removeCollinearity.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "MaxEnt",
            "doc": [
                "Description:\nThis script runs MaxEnt algorithm based on ENMeval package.\n",
                "Authors:\nSarah Valentin (https://orcid.org/0000-0002-9028-681X)\n",
                "External link: https://github.com/jamiemkass/ENMeval",
                "References:\nENMeval 2.0 Redesigned for customizable and reproducible modeling of species\u2019 niches and distributions\nhttps://doi.org/10.1111/2041-210X.13628\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    presence_background: inputs.presence_background ? inputs.presence_background.path : null,\n    predictors: (inputs.predictors || []).map(function(file) { return file.path; }),\n    fc: inputs.fc,\n    rm: inputs.rm,\n    partition_type: inputs.partition_type,\n    orientation_block: inputs.orientation_block,\n    crs: inputs.crs,\n    n_folds: inputs.n_folds,\n    method_select_params: inputs.method_select_params,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"SDM__runMaxent\" \\\n\"channels: [conda-forge, r]\ndependencies: [libgdal, r-abind, r-base, r-curl, r-dismo, r-downloader, r-dplyr, r-enmeval=2.0.3,\n  r-ecospat, r-essentials, r-geojsonsf, r-ggsci, r-jpeg, r-landscapemetrics, r-magrittr,\n  r-png, r-purrr, r-rcurl, r-rgbif, r-remotes, r-rjava, r-rjson, r-sf, r-stars, r-stringr,\n  r-terra, r-this.path, r-tidyselect, r-tidyverse, r-stringr]\nname: SDM__runMaxent\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SDM__runMaxent /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#runMaxent.cwl/condaPackURL"
                },
                {
                    "label": "CRS",
                    "doc": "Object containing CRS.",
                    "type": {
                        "type": "record",
                        "name": "#runMaxent.cwl/crs/CRS",
                        "fields": [
                            {
                                "name": "#runMaxent.cwl/crs/CRS/CRS",
                                "type": {
                                    "name": "#runMaxent.cwl/crs/CRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#runMaxent.cwl/crs/CRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#runMaxent.cwl/crs/CRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#runMaxent.cwl/crs/CRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#runMaxent.cwl/crs/CRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#runMaxent.cwl/crs/CRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#runMaxent.cwl/crs/CRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#runMaxent.cwl/crs/CRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    },
                    "id": "#runMaxent.cwl/crs"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#runMaxent.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#runMaxent.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#runMaxent.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "feature classes",
                    "doc": "Vector of strings, feature classes for MaxEnt algorithm. Accepted values are combinations of L (linear), Q (quadratic), P (product), H (hinge) or T (threshold).",
                    "default": [
                        "L",
                        "LQ",
                        "LQHP"
                    ],
                    "id": "#runMaxent.cwl/fc"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#runMaxent.cwl/method_select_params/p10",
                            "#runMaxent.cwl/method_select_params/AIC",
                            "#runMaxent.cwl/method_select_params/AUC"
                        ]
                    },
                    "label": "params selection method",
                    "doc": "String, method to select the best combination of MaxEnt parameters.",
                    "default": "p10",
                    "id": "#runMaxent.cwl/method_select_params"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "number of folds",
                    "doc": "Integer, number of random k-folds for randomkfold technique.",
                    "default": 5,
                    "id": "#runMaxent.cwl/n_folds"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#runMaxent.cwl/orientation_block/lat_lon",
                            "#runMaxent.cwl/orientation_block/lon_lat",
                            "#runMaxent.cwl/orientation_block/lon_lon",
                            "#runMaxent.cwl/orientation_block/lat_lat"
                        ]
                    },
                    "label": "orientation block",
                    "doc": "String, order of spatial partitioning for block technique..",
                    "default": "lat_lon",
                    "id": "#runMaxent.cwl/orientation_block"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#runMaxent.cwl/partition_type/randomkfold",
                            "#runMaxent.cwl/partition_type/jackknife",
                            "#runMaxent.cwl/partition_type/block",
                            "#runMaxent.cwl/partition_type/checkerboard1",
                            "#runMaxent.cwl/partition_type/checkerboard2"
                        ]
                    },
                    "label": "partition type",
                    "doc": "String, name of partitioning technique.",
                    "default": "block",
                    "id": "#runMaxent.cwl/partition_type"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "predictors",
                    "doc": "layer names (predictors) as a list, or path to a list",
                    "default": [
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio141981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio151981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio181981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio21981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio31981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio81981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio91981-01-01.tif"
                    ],
                    "id": "#runMaxent.cwl/predictors"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "presence background",
                    "doc": "presence",
                    "default": "/scripts/SDM/runModel_presence_background.tsv",
                    "id": "#runMaxent.cwl/presence_background"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "float"
                        }
                    ],
                    "label": "regularization multiplier",
                    "doc": "Vector of numbers, regularization multipliers for MaxEnt algorithm.",
                    "default": [
                        0.5,
                        1,
                        2
                    ],
                    "id": "#runMaxent.cwl/rm"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#runMaxent.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "SDM/runMaxent.R",
                    "id": "#runMaxent.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#runMaxent.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#runMaxent.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "predictions",
                    "doc": "model predictions while trained on the whole dataset",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"sdm_pred\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#runMaxent.cwl/sdm_pred_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "runs predictions",
                    "doc": "model predictions among the several runs (if boostrapping or kfolds performed)",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"sdm_runs\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return { class: \"File\", location: \"file://\" + value };\n  });\n}\n"
                    },
                    "id": "#runMaxent.cwl/sdm_runs_out"
                }
            ],
            "id": "#runMaxent.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Background Points",
            "doc": [
                "Description:\nThis script creates a set of pseudo-absences/background points.\n",
                "Authors:\nSarah Valentin (https://orcid.org/0000-0002-9028-681X)\nDat Nguyen\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    presence: inputs.presence ? inputs.presence.path : null,\n    extent: inputs.extent ? inputs.extent.path : null,\n    method_background: inputs.method_background,\n    n_background: inputs.n_background,\n    predictors: (inputs.predictors || []).map(function(file) { return file.path; }),\n    raster: inputs.raster ? inputs.raster.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"SDM__selectBackground\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-rjson, r-terra, r-dplyr, r-raster, r-CoordinateCleaner, r-stars,\n  r-rstac, r-gdalcubes]\nname: SDM__selectBackground\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SDM__selectBackground /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#selectBackground.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#selectBackground.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#selectBackground.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#selectBackground.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "extent",
                    "doc": "Geopackage, representing a study extent",
                    "default": "/scripts/SDM/extentToBbox_extent.gpkg",
                    "id": "#selectBackground.cwl/extent"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#selectBackground.cwl/method_background/random",
                            "#selectBackground.cwl/method_background/inclusion_buffer",
                            "#selectBackground.cwl/method_background/weighted_raster",
                            "#selectBackground.cwl/method_background/unweighted_raster",
                            "#selectBackground.cwl/method_background/thickening"
                        ]
                    },
                    "label": "method background",
                    "doc": "Generates background points using any of the five available methods. - `random`: background points are randomly sampled throughout the whole study extent. - `weighted_raster`: background points are sampled in proportion to the number of observations of a target group in an observation density raster. - `unweighted_raster`: background points are sampled only in cells where there are observations from a target group. - `inclusion_buffer`: background points are sampled within a buffer around observations. - `thickening`: background points are sampled in proportion to the local density of observations by sampling in a buffer around each observation.\n",
                    "default": "random",
                    "id": "#selectBackground.cwl/method_background"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "number of background points",
                    "doc": "number of background points",
                    "default": 10000,
                    "id": "#selectBackground.cwl/n_background"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "predictors",
                    "doc": "raster, predictors variables",
                    "default": "/scripts/filtering/cleanCoordinates_predictors.tif",
                    "id": "#selectBackground.cwl/predictors"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "presence",
                    "doc": "Dataframe, presence data.",
                    "default": "/scripts/SDM/selectBackground_presence.tsv",
                    "id": "#selectBackground.cwl/presence"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "raster file",
                    "doc": "taxa-specific raster of sampling, used in weighted_raster and unweighted_raster methods",
                    "default": "/scripts/data/heatmapGBIF-reptiles.tif",
                    "id": "#selectBackground.cwl/raster"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#selectBackground.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "SDM/selectBackground.R",
                    "id": "#selectBackground.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#selectBackground.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "background",
                    "doc": "TSV file containing a table with background points.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"background\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#selectBackground.cwl/background_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#selectBackground.cwl/logs"
                },
                {
                    "type": "int",
                    "label": "nb background",
                    "doc": "number of background points selected",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"n_background\");\n  if (value === null) return null;\n  return parseInt(value);\n}\n"
                    },
                    "id": "#selectBackground.cwl/n_background_out"
                }
            ],
            "id": "#selectBackground.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Setup SDM Data",
            "doc": [
                "Description:\nThis script creates a dataset ready to feed any SDM model.\n",
                "Authors:\nSarah Valentin (https://orcid.org/0000-0002-9028-681X)\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    presence: inputs.presence ? inputs.presence.path : null,\n    background: inputs.background ? inputs.background.path : null,\n    predictors: (inputs.predictors || []).map(function(file) { return file.path; }),\n    partition_type: inputs.partition_type,\n    runs_n: inputs.runs_n,\n    boot_proportion: inputs.boot_proportion,\n    cv_partitions: inputs.cv_partitions,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"SDM__setupDataSdm\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-gdalcubes, r-terra, r-rjson, r-raster, r-dplyr, r-ENMeval, r-devtools]\nname: SDM__setupDataSdm\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh SDM__setupDataSdm /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "background",
                    "doc": "Dataframe, background data.",
                    "default": "/scripts/SDM/setupDataSdm_background.tsv",
                    "id": "#setupDataSdm.cwl/background"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "bootstrap proportion",
                    "doc": "proportion of presences and absences in the dataset that will be used as training data with bootstrap method.",
                    "default": 0.7,
                    "id": "#setupDataSdm.cwl/boot_proportion"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#setupDataSdm.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "number of crossvalidation partitions",
                    "doc": "number of partitions for each run with crossvalidation method.",
                    "default": 5,
                    "id": "#setupDataSdm.cwl/cv_partitions"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#setupDataSdm.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#setupDataSdm.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#setupDataSdm.cwl/environment"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#setupDataSdm.cwl/partition_type/bootstrap",
                            "#setupDataSdm.cwl/partition_type/crossvalidation",
                            "#setupDataSdm.cwl/partition_type/none"
                        ]
                    },
                    "label": "partition type",
                    "doc": "method to partition into test and training sets to perform model fitting and validation.",
                    "default": "none",
                    "id": "#setupDataSdm.cwl/partition_type"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "predictors",
                    "doc": "Raster, predictors.",
                    "default": [
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio141981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio151981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio181981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio21981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio31981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio81981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio91981-01-01.tif"
                    ],
                    "id": "#setupDataSdm.cwl/predictors"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "presence",
                    "doc": "Dataframe, presence data.",
                    "default": "/scripts/SDM/selectBackground_presence.tsv",
                    "id": "#setupDataSdm.cwl/presence"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#setupDataSdm.cwl/runFolder"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "number of runs",
                    "doc": "number of runs (in bootstrap or crossvalidation method)",
                    "default": 2,
                    "id": "#setupDataSdm.cwl/runs_n"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "SDM/setupDataSdm.R",
                    "id": "#setupDataSdm.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#setupDataSdm.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#setupDataSdm.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "background presence",
                    "doc": "Presence-background points with covariates values",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"presence_background\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#setupDataSdm.cwl/presence_background_out"
                }
            ],
            "id": "#setupDataSdm.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Study Extent",
            "doc": [
                "Description:\nThis script computes a study area around presence points.\n",
                "Authors:\nSarah Valentin (https://orcid.org/0000-0002-9028-681X)\nGuillaume Larocque (https://orcid.org/0000-0002-5967-9156)\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    presence: inputs.presence ? inputs.presence.path : null,\n    bbox_crs: inputs.bbox_crs,\n    method: inputs.method,\n    width_buffer: inputs.width_buffer,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"rbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "label": "Bounding box and CRS",
                    "doc": "Select a bounding box and CRS",
                    "type": {
                        "type": "record",
                        "name": "#studyExtent.cwl/bbox_crs/crsBBox",
                        "fields": [
                            {
                                "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS",
                                "type": {
                                    "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#studyExtent.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#studyExtent.cwl/bbox_crs/crsBBox/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            }
                        ]
                    },
                    "id": "#studyExtent.cwl/bbox_crs"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#studyExtent.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#studyExtent.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#studyExtent.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#studyExtent.cwl/environment"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#studyExtent.cwl/method/box",
                            "#studyExtent.cwl/method/mcp",
                            "#studyExtent.cwl/method/buffer",
                            "#studyExtent.cwl/method/bbox"
                        ]
                    },
                    "label": "study extent method",
                    "doc": "Option, method to create the study extent.",
                    "default": "mcp",
                    "id": "#studyExtent.cwl/method"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "clean presence",
                    "doc": "Table, cleaned presence points",
                    "default": "/output/cleanCoordinates/modCleanCoordinates_R/bb4400dd0e2bfec94745f1ab67e5a4a0/clean_presence.tsv",
                    "id": "#studyExtent.cwl/presence"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#studyExtent.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "SDM/studyExtent.R",
                    "id": "#studyExtent.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#studyExtent.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "buffer width",
                    "doc": "Integer, buffer width (applied around the box, mcp or points depending on the method used)",
                    "default": 0,
                    "id": "#studyExtent.cwl/width_buffer"
                }
            ],
            "outputs": [
                {
                    "type": "float",
                    "label": "study extent area",
                    "doc": "Area of the study extent",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"area_study_extent\");\n  if (value === null) return null;\n  return parseFloat(value);\n}\n"
                    },
                    "id": "#studyExtent.cwl/area_study_extent_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#studyExtent.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "study extent",
                    "doc": "Geopackage representing the study extent",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"study_extent\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#studyExtent.cwl/study_extent_out"
                }
            ],
            "id": "#studyExtent.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "GBIF Heatmap",
            "doc": [
                "Description:\nDownload raster representing the number of observations in GBIF for each pixel for specific taxonomic groups.\nSource layer can be found on the [GEO BON STAC catalog](https://stac.geobon.org/viewer/).\n",
                "Lifecycle tag: Core.",
                "Authors:\nGuillaume Larocque (https://orcid.org/0000-0002-5967-9156)\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    taxa: inputs.taxa,\n    bbox_crs: inputs.bbox_crs,\n    spatial_res: inputs.spatial_res,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"rbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "label": "Bounding box and CRS",
                    "doc": "Select a bounding box and CRS",
                    "type": {
                        "type": "record",
                        "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox",
                        "fields": [
                            {
                                "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS",
                                "type": {
                                    "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#GBIFHeatmapFromSTAC.cwl/bbox_crs/crsBBox/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            }
                        ]
                    },
                    "id": "#GBIFHeatmapFromSTAC.cwl/bbox_crs"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#GBIFHeatmapFromSTAC.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#GBIFHeatmapFromSTAC.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#GBIFHeatmapFromSTAC.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#GBIFHeatmapFromSTAC.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#GBIFHeatmapFromSTAC.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "data/loadFromStac.R",
                    "id": "#GBIFHeatmapFromSTAC.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#GBIFHeatmapFromSTAC.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Spatial resolution",
                    "doc": "Integer, spatial resolution of the rasters",
                    "default": 1000.0,
                    "id": "#GBIFHeatmapFromSTAC.cwl/spatial_res"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#GBIFHeatmapFromSTAC.cwl/taxa/reptiles",
                            "#GBIFHeatmapFromSTAC.cwl/taxa/plants",
                            "#GBIFHeatmapFromSTAC.cwl/taxa/mammals",
                            "#GBIFHeatmapFromSTAC.cwl/taxa/birds",
                            "#GBIFHeatmapFromSTAC.cwl/taxa/arthropods",
                            "#GBIFHeatmapFromSTAC.cwl/taxa/amphibians",
                            "#GBIFHeatmapFromSTAC.cwl/taxa/all"
                        ]
                    },
                    "label": "Taxa",
                    "doc": "taxonomic group for which to retrieve GBIF heatmap",
                    "default": "plants",
                    "id": "#GBIFHeatmapFromSTAC.cwl/taxa"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#GBIFHeatmapFromSTAC.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Density raster",
                    "doc": "Array with output raster path",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"rasters\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#GBIFHeatmapFromSTAC.cwl/rasters_out"
                }
            ],
            "id": "#GBIFHeatmapFromSTAC.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "GBIF Observations from Download API",
            "doc": [
                "Description:\nLoad complete GBIF data from GBIF download API\n",
                "Lifecycle tag: Core.",
                "Authors:\nGuillaume Larocque (https://orcid.org/0000-0002-5967-9156)\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    taxa: inputs.taxa,\n    bbox_crs: inputs.bbox_crs,\n    min_year: inputs.min_year,\n    max_year: inputs.max_year,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"data__getGBIFObservations__getGBIFObservations\" \\\n\"channels: [conda-forge]\ndependencies: [pygbif, pandas, pyproj]\nname: data__getGBIFObservations__getGBIFObservations\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\npython3 \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.py \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__getGBIFObservations__getGBIFObservations /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "label": "Bounding box and CRS",
                    "doc": "Select a bounding box and CRS. This defines the geographic extent of the analysis as a bounding box, along with its coordinate reference system (CRS). A larger extent increases computation time.",
                    "type": {
                        "type": "record",
                        "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox",
                        "fields": [
                            {
                                "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS",
                                "type": {
                                    "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#getGBIFObservations.cwl/bbox_crs/crsBBox/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            }
                        ]
                    },
                    "id": "#getGBIFObservations.cwl/bbox_crs"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#getGBIFObservations.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#getGBIFObservations.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#getGBIFObservations.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#getGBIFObservations.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Maximum year or end date",
                    "doc": "Latest year for GBIF records. Accepts YYYY or YYYY-MM-DD; if a full date is supplied, only the year is used.",
                    "default": "2024",
                    "id": "#getGBIFObservations.cwl/max_year"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Minimum year or start date",
                    "doc": "Earliest year for GBIF records. Accepts YYYY or YYYY-MM-DD; if a full date is supplied, only the year is used.",
                    "default": "2010",
                    "id": "#getGBIFObservations.cwl/min_year"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#getGBIFObservations.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "data/getGBIFObservations/getGBIFObservations.py",
                    "id": "#getGBIFObservations.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#getGBIFObservations.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "Taxa list",
                    "doc": "Comma-separated list of [taxa](https://en.wikipedia.org/wiki/Taxon). Each value could be a species name, order, class, genus, kingdom or family, as long as it is an exact match with the GBIF taxonomic backbone. Individual species can be looked up [on the GBIF website](https://www.gbif.org/species/).",
                    "default": [
                        "Acer saccharum",
                        "Acer nigrum"
                    ],
                    "id": "#getGBIFObservations.cwl/taxa"
                }
            ],
            "outputs": [
                {
                    "type": "string",
                    "label": "DOI of GBIF download",
                    "doc": "A permanent DOI assigned to this specific GBIF data download. Must be cited in any publication using these data \u2014 see [GBIF's citation guidelines](https://www.gbif.org/citation-guidelines).",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"gbif_doi\");\n  return value;\n}\n"
                    },
                    "id": "#getGBIFObservations.cwl/gbif_doi_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#getGBIFObservations.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Observations",
                    "doc": "Tab-separated file containing all GBIF occurrence records retrieved for the specified taxa, bounding box, and time range. Each row represents one observation. Used as input to subsequent modeling steps.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"observations_file\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#getGBIFObservations.cwl/observations_file_out"
                },
                {
                    "type": "int",
                    "label": "Total number of occurrences",
                    "doc": "Count of occurrence records returned by the GBIF query. Use this to gauge data availability before running the model \u2014 very low counts (e.g. <20) may produce unreliable results.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"total_records\");\n  if (value === null) return null;\n  return parseInt(value);\n}\n"
                    },
                    "id": "#getGBIFObservations.cwl/total_records_out"
                }
            ],
            "id": "#getGBIFObservations.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Load from STAC",
            "doc": [
                "Description:\nExtract individual unprocessed items from various collections on the GEO BON STAC catalog.\n",
                "Lifecycle tag: Core.",
                "Authors:\nGuillaume Larocque (https://orcid.org/0000-0002-5967-9156)\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    bbox_crs: inputs.bbox_crs,\n    stac_url: inputs.stac_url,\n    collections_items: inputs.collections_items,\n    t0: inputs.t0,\n    t1: inputs.t1,\n    temporal_res: inputs.temporal_res,\n    spatial_res: inputs.spatial_res,\n    resampling: inputs.resampling,\n    aggregation: inputs.aggregation,\n    study_area: inputs.study_area ? inputs.study_area.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"data__loadFromStac\" \\\n\"channels: [conda-forge, r]\ndependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,\n  r-rcurl, r-rjson, r-sf, r-stars, r-terra]\nname: data__loadFromStac\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__loadFromStac /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#loadFromStac.cwl/aggregation/first",
                            "#loadFromStac.cwl/aggregation/min",
                            "#loadFromStac.cwl/aggregation/max",
                            "#loadFromStac.cwl/aggregation/mean",
                            "#loadFromStac.cwl/aggregation/median"
                        ]
                    },
                    "label": "Aggregation method",
                    "doc": "Method used to aggregate items when layers combining over time. Will be ignored if no aggregation occurs.",
                    "default": "first",
                    "id": "#loadFromStac.cwl/aggregation"
                },
                {
                    "label": "Bounding box and CRS",
                    "doc": "Object containing the chosen bounding box and CRS.",
                    "type": {
                        "type": "record",
                        "name": "#loadFromStac.cwl/bbox_crs/crsBBox",
                        "fields": [
                            {
                                "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS",
                                "type": {
                                    "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#loadFromStac.cwl/bbox_crs/crsBBox/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#loadFromStac.cwl/bbox_crs/crsBBox/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            }
                        ]
                    },
                    "id": "#loadFromStac.cwl/bbox_crs"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "STAC collection items",
                    "doc": "Vector of strings. To pull specific collection items, input the collection name followed by '|' followed by item id (e.g. \"chelsa-clim|bio1\"). To extract a whole collection, type the collection name only (e.g. \"chelsa-clim\"). To pull collection items by date, write the collection name and provide a start date, end date, and temporal resolution. If pulling a layer that is tiled (e.g. https://stac.geobon.org/viewer/gfw-lossyear/_80N_180W), enter the collection name (e.g. gfw-lossyear), bounding box and time range if the layer is a time series, and the script will assemble the tiles into a continuous layer automatically.)",
                    "default": [
                        "chelsa-clim|bio1",
                        "chelsa-clim|bio2"
                    ],
                    "id": "#loadFromStac.cwl/collections_items"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#loadFromStac.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#loadFromStac.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#loadFromStac.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#loadFromStac.cwl/environment"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#loadFromStac.cwl/resampling/near",
                            "#loadFromStac.cwl/resampling/bilinear",
                            "#loadFromStac.cwl/resampling/average",
                            "#loadFromStac.cwl/resampling/mode",
                            "#loadFromStac.cwl/resampling/cubic",
                            "#loadFromStac.cwl/resampling/cubicspline",
                            "#loadFromStac.cwl/resampling/lanczos",
                            "#loadFromStac.cwl/resampling/rms",
                            "#loadFromStac.cwl/resampling/min",
                            "#loadFromStac.cwl/resampling/max",
                            "#loadFromStac.cwl/resampling/sum",
                            "#loadFromStac.cwl/resampling/med",
                            "#loadFromStac.cwl/resampling/q1",
                            "#loadFromStac.cwl/resampling/q3"
                        ]
                    },
                    "label": "Resampling method",
                    "doc": "Resampling method used when rescaling and/or reprojecting the raster layers. Will be ignored if no resampling occurs. See [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) for description.",
                    "default": "near",
                    "id": "#loadFromStac.cwl/resampling"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#loadFromStac.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "data/loadFromStac.R",
                    "id": "#loadFromStac.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#loadFromStac.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Spatial resolution",
                    "doc": "Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). If this is left blank it will attempt to use the native resolution of the rasters, however the input CRS units must match the units of the native resolution. If the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled with the resampling method chosen below.",
                    "default": 0.00833,
                    "id": "#loadFromStac.cwl/spatial_res"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "STAC URL",
                    "doc": "URL of the STAC catalog.",
                    "default": "https://stac.geobon.org/",
                    "id": "#loadFromStac.cwl/stac_url"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Study area",
                    "doc": "Polygon of study area used to mask output layers, in geopackage format.",
                    "id": "#loadFromStac.cwl/study_area"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Start date",
                    "doc": "Start date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if extracting items by name or to extract layers from all available dates.",
                    "id": "#loadFromStac.cwl/t0"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "End date",
                    "doc": "End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if extracting items by name or to extract layers from all available dates.",
                    "id": "#loadFromStac.cwl/t1"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Temporal resolution",
                    "doc": "Temporal resolution to use when querying STAC items by date, in the format (\"P\", time interval, and time unit, e.g. \"P1Y\" is yearly, \"P1M\" is montly, and \"P1D\" is daily). Leave blank if not querying by date or if extracting layers from all available dates. If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below.",
                    "id": "#loadFromStac.cwl/temporal_res"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#loadFromStac.cwl/logs"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "Rasters",
                    "doc": "Output raster files in geotiff format.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"rasters\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return { class: \"File\", location: \"file://\" + value };\n  });\n}\n"
                    },
                    "id": "#loadFromStac.cwl/rasters_out"
                }
            ],
            "id": "#loadFromStac.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Clean Coordinates",
            "doc": [
                "Description:\nThis script enables to apply several cleaning filters to the observations. The tests equal, zeros, duplicates, same_pixel, capitals, centroids, seas, urban, gbif and institutions are wrappers around CoordinateCleaner functions. Test same_pixel remove points inside the same pixel, based on a provided raster or from a STAC catalogue. Test env allows removing environmental outliers using the the Reverse Jackknife procedure as described by Chapman (2005) and adapted from the package biogeo.\n",
                "Lifecycle tag: Core.",
                "Authors:\nSarah Valentin (https://orcid.org/0000-0002-9028-681X)\n",
                "External link: https://github.com/ropensci/CoordinateCleaner",
                "References:\nChapman, A.D. (2005) Principles and Methods of Data Cleaning - Primary Species and Species- Occurrence Data, version 1.0. Report for the Global Biodiversity Information Facility, Copenhagen.\nnull\n\nZizka A, Silvestro D, Andermann T, Azevedo J, Duarte Ritter C, Edler D, Farooq H, Herdean A, Ariza M, Scharn R, Svanteson S, Wengtrom N, Zizka V & Antonelli A (2019) CoordinateCleaner, standardized cleaning of occurrence records from biological collection databases. Methods in Ecology and Evolution, 10(5):744-751\nhttps://doi.org/10.1111/2041-210X.13152\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    presence: inputs.presence ? inputs.presence.path : null,\n    predictors: (inputs.predictors || []).map(function(file) { return file.path; }),\n    tests: inputs.tests,\n    env_threshold: inputs.env_threshold,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"filtering__cleanCoordinates\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-terra, r-rjson, r-raster, r-dplyr, r-CoordinateCleaner, r-gdalcubes]\nname: filtering__cleanCoordinates\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh filtering__cleanCoordinates /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#cleanCoordinates.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#cleanCoordinates.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#cleanCoordinates.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "env threshold",
                    "doc": "Float, proportion of predictors to consider the observation as an outlier.",
                    "default": 0.8,
                    "id": "#cleanCoordinates.cwl/env_threshold"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#cleanCoordinates.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "predictors",
                    "doc": "Stack of environmental predictor rasters in GeoTIFF format. Used for the 'env' cleaning test to identify environmental outliers.",
                    "default": [
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio141981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio151981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio181981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio21981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio31981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio81981-01-01.tif",
                        "/output/SDM/loadPredictors_R/e09acd85debd23c991652771b1d771b2/bio91981-01-01.tif"
                    ],
                    "id": "#cleanCoordinates.cwl/predictors"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "presence",
                    "doc": "Tab-separated occurrence records to be cleaned, typically the output of a GBIF download step. Each row should represent one observation with at minimum latitude, longitude, and species columns.",
                    "default": "/scripts/filtering/cleanCoordinates_presence.tsv",
                    "id": "#cleanCoordinates.cwl/presence"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#cleanCoordinates.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "filtering/cleanCoordinates.R",
                    "id": "#cleanCoordinates.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#cleanCoordinates.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "cleaning tests",
                    "doc": "Vector of strings, tests to run from all tests available - capitals, centroids, same_pixel, equal, gbif, institutions, duplicates, urban, seas, zeros, env",
                    "default": [
                        "equal",
                        "zeros",
                        "duplicates",
                        "same_pixel",
                        "capitals",
                        "centroids",
                        "seas",
                        "urban",
                        "gbif",
                        "institutions",
                        "env"
                    ],
                    "id": "#cleanCoordinates.cwl/tests"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "clean presences",
                    "doc": "Tab-separated table of occurrence records that passed all selected cleaning tests. This is the recommended input for downstream species distribution modeling steps.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"clean_presence\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#cleanCoordinates.cwl/clean_presence_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#cleanCoordinates.cwl/logs"
                },
                {
                    "type": "int",
                    "label": "n clean presence",
                    "doc": "Number of occurrence records remaining after all selected cleaning tests have been applied. A large drop relative to `n_presence` may indicate overly aggressive settings or systematic issues in the input data. Very low counts (<20) may produce unreliable SDM results.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"n_clean\");\n  if (value === null) return null;\n  return parseInt(value);\n}\n"
                    },
                    "id": "#cleanCoordinates.cwl/n_clean_out"
                },
                {
                    "type": "int",
                    "label": "n presence",
                    "doc": "Number of occurrence records entering the cleaning pipeline. Compare with `n_clean` to assess how many records were removed and whether the cleaning settings are appropriate for your dataset.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"n_presence\");\n  if (value === null) return null;\n  return parseInt(value);\n}\n"
                    },
                    "id": "#cleanCoordinates.cwl/n_presence_out"
                }
            ],
            "id": "#cleanCoordinates.cwl"
        },
        {
            "class": "Workflow",
            "label": "Species distribution modeling with Maxent",
            "doc": [
                "Description:\n## Introduction \nSpecies distributions are an important [Essential Biodiversity Variable (EBV)](https://geobon.org/ebvs/what-are-ebvs/) in the species populations class. Knowing where species are likely to occur is essential for understanding biodiversity patterns, identifying conservation priorities, assessing potential impacts of environmental change, and supporting biodiversity indicators. However, species occurrence data are often sparse, unevenly distributed, and affected by spatial and taxonomic sampling bias. Species distribution models (SDMs) help fill these gaps by estimating where suitable environmental conditions occur for a species based on known observations and environmental predictors (Peterson, 2001; Elith and Leathwick, 2009).  \n\nThe MaxEnt pipeline builds a species distribution model using occurrence records from the [Global Biodiversity Information Facility (GBIF)](https://www.gbif.org/) and environmental raster layers from the [GEO BON STAC catalog](https://stac.geobon.org/). The pipeline retrieves GBIF observations for the selected taxon or taxa, cleans occurrence coordinates, removes highly collinear environmental predictors, generates background points, and fits a MaxEnt model using the ENMeval R package (Kass et al. 2021). MaxEnt is a presence-background modeling approach, meaning it compares known species presences with background environmental conditions across the study area. The MaxEnt SDM is run by 1\\) partitioning occurrence and background points into subsets for training and evaluation, 2\\) building the model with different algorithmic settings (model tuning), and 3\\) evaluating their performance ([see package vignette](https://jamiemkass.github.io/ENMeval/articles/ENMeval-2.0-vignette.html#partition)). Lastly, the pipeline computes the 95% confidence interval using bootstrapping and cross validation techniques.  \n\nThe pipeline evaluates different MaxEnt settings, including feature classes and regularization multipliers, and selects a tuned model based on model performance. It produces a habitat suitability prediction raster, cleaned occurrence records, selected environmental predictors, a GBIF download DOI, and a raster summarizing variability among model runs.  \n## Uses\nThe MaxEnt pipeline can be used to estimate the potential distribution or relative habitat suitability of one or more species within a selected study area. Outputs can support conservation planning, sampling prioritization, identification of biodiversity hotspots, protected area planning, risk assessment for species of conservation concern, and environmental impact assessments.  \n\nThe results can also be used as inputs to other biodiversity analyses and indicators, such as identifying areas where species are likely to occur, mapping speciesrichness,comparing predicted habitat suitability across regions, or highlighting areas where additional occurrence sampling may be needed. Because the pipeline retrieves both GBIF observations and environmental predictor layers, it provides a reproducible workflow for generating species distribution maps from public biodiversity and environmental data. \n## Pipeline limitations\n* MaxEnt uses presence-background data, not confirmed absence data. Predictions should be interpreted as relative habitat suitability or relative occurrence potential, not confirmed species presence or absence.\n* GBIF records may contain spatial, taxonomic, and temporal biases. The pipeline applies coordinate-cleaning steps, but users should still inspect the cleaned presences and interpret results cautiously, especially for poorly sampled taxa or regions.\n* Model quality depends strongly on the number and quality of occurrence records. Very small numbers of cleaned presences may produce unreliable predictions.\n* The choice of environmental predictors, background sampling method, feature classes, regularization multipliers, and partitioning method can affect model outputs. Users should treat the model as sensitive to these settings, especially for final analyses.\n* Environmental predictors must be ecologically relevant to the species being modeled. Including many correlated or irrelevant predictors can reduce interpretability and increase overfitting risk.\n* The pipeline estimates suitability based on the predictor layers supplied by the user. It does not directly account for dispersal limits, biotic interactions, land-use barriers, species detectability, or future environmental change unless those factors are represented in the input data.\n* Larger study areas, finer spatial resolutions, more environmental predictors, and more model runs increase computation time and memory use.\n## Before you start\nA GBIF API key is required to run this pipeline and can be added into the runner.env file.  \n\nBefore running the pipeline, choose the taxon or taxa you want to model and make sure the names match the GBIF taxonomic backbone. Species names can be checked on the [GBIF website](https://www.gbif.org/).  \n\nSelect a study area using the bounding box and CRS input. The CRS and spatial resolution determine the scale of the analysis, so choose a CRS appropriate for the region and make sure the spatial resolution is in the units of that CRS.  \n\nChoose environmental predictor layers from the [STAC catalog](https://stac.geobon.org/) that are ecologically relevant to the species being modeled. For example, climate, vegetation, elevation, land cover, or habitat-related predictors may be appropriate depending on the species. Avoid including many predictors that represent the same underlying environmental gradient.\n",
                "Authors:\nSarah Valentin (Pipeline development, https://orcid.org/0000-0002-9028-681X)\nGuillaume Larocque (Pipeline development, guillaume.larocque@mcgill.ca, https://orcid.org/0000-0002-5967-9156)\nFran\u00e7ois Rousseu (Pipeline development, https://orcid.org/0000-0002-2400-2479)\n",
                "External link: https://github.com/GEO-BON/biab-2.0/blob/main/scripts/SDM/runMaxent.R",
                "References:\nVollering et al. 2019\nhttps://doi.org/10.1111/ecog.04503\n\nPhillips et al. 2009\nhttps://doi.org/10.1890/07-2153.1\n\nBastion 2023\nhttps://doi.org/10.32614/CRAN.package.exactextractr\n\nKass et al. 2021\nhttps://doi.org/10.1111/2041-210X.13628\n\nElith and Leathwick, 2009\nhttps://doi.org/10.1146/annurev.ecolsys.110308.120159\n\nPeterson, 2001\nhttps://doi.org/10.1641/0006-3568%282001%29051%5B0363%3APSIUEN%5D2.0.CO%3B2\n"
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
                            "items": "string"
                        }
                    ],
                    "label": "Feature classes",
                    "doc": "MaxEnt feature classes control the shapes of relationships the model can learn between species occurrence and environmental predictors. Simpler classes, such as L or LQ, fit smoother, more constrained responses and are often safer for small datasets. More complex combinations, such as LQH or LQHP, can capture more flexible ecological responses but may overfit when occurrence records are limited. This pipeline tests all values provided here and selects the best-performing combination using the parameter selection method configured in the MaxEnt step. Accepted values are combinations of L (linear), Q (quadratic), P (product), H (hinge) or T (threshold).",
                    "default": [
                        "L",
                        "LQ",
                        "LQHP"
                    ],
                    "id": "#main/SDM>runMaxent.yml@108|fc"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#main/SDM>runMaxent.yml@108|partition_type/randomkfold",
                            "#main/SDM>runMaxent.yml@108|partition_type/jackknife",
                            "#main/SDM>runMaxent.yml@108|partition_type/block",
                            "#main/SDM>runMaxent.yml@108|partition_type/checkerboard1",
                            "#main/SDM>runMaxent.yml@108|partition_type/checkerboard2"
                        ]
                    },
                    "label": "Partition type",
                    "doc": "This option controls how ENMeval partitions presence and background data while tuning MaxEnt parameters.\nIt is recommended to start with random k-fold. If you suspect overfitting or spatial autocorrelation, switch to block or checkerboard because these partition data geographically rather than randomly, which makes evaluation more robust to spatial autocorrelation between nearby points. If you don't have enough occurrence points for spatial partitioning, use jackknife.\n\n   - Random k-fold \\- partitions groups randomly into a user-specified (K) number of bins, and runs the model k times, with each bin used once as testing. Recommended to start with 10 folds.\n  - Block \\- partitions the bounding box into four equally sized quadrants and assigns groups by quadrant. Because each fold is a large, contiguous geographic region, this tests how well the model transfers to broad, spatially distinct areas. This is a stricter test of spatial autocorrelation than checkerboard.\n  - Checkerboard 1 \\- generates a checkerboard grid from the study area and assigns groups based on which square the points fall in. Folds are smaller and spatially interspersed (alternating across the study area) rather than large contiguous blocks, so it tests spatial independence at a finer scale than block.\n  - Checkerboard 2 \\- Similar to checkerboard 1 but performs this separately for occurrence and background points\n  - Jackknife \\- Does not partition the background points into testing and training (uses them all), performs leave one out cross validation. Recommended for small datasets only.\n",
                    "default": "randomkfold",
                    "id": "#main/SDM>runMaxent.yml@108|partition_type"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "float"
                        }
                    ],
                    "label": "Regularization multiplier",
                    "doc": "Regularization multiplier values to evaluate for MaxEnt model tuning. The regularization multiplier controls how strongly MaxEnt penalizes model complexity. Lower values allow a more flexible model that may fit local patterns closely. Higher values produce smoother, more generalized predictions and reduce overfitting risk.",
                    "default": [
                        0.5,
                        1,
                        2
                    ],
                    "id": "#main/SDM>runMaxent.yml@108|rm"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#main/SDM>selectBackground.yml@40|method_background/random",
                            "#main/SDM>selectBackground.yml@40|method_background/inclusion_buffer",
                            "#main/SDM>selectBackground.yml@40|method_background/weighted_raster",
                            "#main/SDM>selectBackground.yml@40|method_background/unweighted_raster",
                            "#main/SDM>selectBackground.yml@40|method_background/thickening"
                        ]
                    },
                    "label": "Method background",
                    "doc": "Background points are generated using one of the five available methods. Choosing the right method can help correct for sampling bias in the GBIF data. - `random`: background points are randomly sampled throughout the whole study extent. Good choice if your occurrence data has little spatial bias toward human activity/accessibility (e.g., roads, cities, well-surveyed areas). - `weighted_raster`: background points are sampled in proportion to the number of observations in the observation-density heatmap of the selected taxonomic group. Recommended for heavily biased data, or when occurrences are missing due to gaps in survey/study coverage. This is the more extreme correction of the two raster-based methods (weighted and unweighted). - `unweighted_raster`: background points are sampled only in cells where there are observations from a target group. Also addresses sampling bias and survey gaps, but more conservatively than weighted_raster. Recommended as the default of the two (weighted and unweighted). - `inclusion_buffer`: background points are sampled within a buffer around observations. Useful if you don't think your species is well represented by the target taxonomic group.  - `thickening`: background points are sampled in proportion to the local density of observations, within a buffer around each observation. Also useful when the target taxon group doesn't represent your species well, as an alternative to inclusion_buffer.\n",
                    "default": "random",
                    "id": "#main/SDM>selectBackground.yml@40|method_background"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Number of background points",
                    "doc": "Target number of background points to generate within the study extent. These points are used to represent the available environment.\nTypically it is recommended to start with 10000 points. If you have a very large study area you can increase this amount to fully capture the available environmental space. If you have a very small study area (i.e. fewer than 10000 pixels) you can reduce the number of background points.\n",
                    "default": 10000,
                    "id": "#main/SDM>selectBackground.yml@40|n_background"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#main/condaPackURL"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa/reptiles",
                            "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa/plants",
                            "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa/mammals",
                            "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa/birds",
                            "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa/arthropods",
                            "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa/amphibians",
                            "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa/all"
                        ]
                    },
                    "label": "Taxonomic group",
                    "doc": "Broad taxonomic group used to retrieve the GBIF observation-density heatmap for background-point sampling. Choose the group that best matches the modeled taxa, or all for all GBIF observations.",
                    "default": "plants",
                    "id": "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "STAC collection items",
                    "doc": "To pull a specific collection item, input the collection name followed by | followed by the item ID (e.g. \"chelsa-clim|bio1\").\nTo extract a whole collection, type the collection name only (e.g. \"chelsa-clim\").\nIf pulling a layer that is tiled (e.g. https://stac.geobon.org/viewer/gfw-lossyear/_80N_180W), enter the collection name (e.g. gfw-lossyear) and a bounding box, and the script will assemble the tiles into a continuous layer automatically.\n",
                    "default": [
                        "chelsa-clim|bio1",
                        "chelsa-clim|bio2"
                    ],
                    "id": "#main/data>loadFromStac.yml@144|collections_items"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "STAC URL",
                    "doc": "URL of the STAC catalog used to retrieve environmental predictor layers.",
                    "default": "https://stac.geobon.org/",
                    "id": "#main/data>loadFromStac.yml@144|stac_url"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Study area",
                    "doc": "Polygon of the study area, in geopackage format. To use a custom study area, input the path to the file in userdata (e.g. /userdata/study_area_polygon.gpkg) and it will crop the area to the shape of the polygon. Leave blank to use bounding box and CRS chosen above.",
                    "id": "#main/data>loadFromStac.yml@144|study_area"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Temporal resolution",
                    "doc": "Temporal resolution to use when querying STAC items by date, in the format (\"P\", time interval, and time unit, e.g. \"P1Y\" is yearly, \"P1M\" is monthly, and \"P1D\" is daily). \nIf there is no temporal option all items will be extracted. If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated using the 'first' method.\n",
                    "default": "P1Y",
                    "id": "#main/data>loadFromStac.yml@144|temporal_res"
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
                        {
                            "type": "array",
                            "items": "string"
                        }
                    ],
                    "label": "Taxa list",
                    "doc": "Comma-separated list of [taxa](https://en.wikipedia.org/wiki/Taxon). Each value could be a species name, order, class, genus, kingdom or family, as long as it is an exact match with the GBIF taxonomic backbone. Individual species can be looked up [on the GBIF website](https://www.gbif.org/species/).",
                    "default": [
                        "Acer saccharum"
                    ],
                    "id": "#main/pipeline@121"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Spatial resolution",
                    "doc": "Target spatial resolution for the predictor rasters and GBIF heatmap. Units must match the selected CRS, for example meters for projected CRS or degrees for latitude-longitude CRS.\nChoosing a coarser resolution reduces computation time, but at the cost of fine-scale predictor detail. Variables like land cover and elevation may lose relevance at coarse scales, while broader-scale variables such as climate become comparatively more informative.\n",
                    "default": 1000,
                    "id": "#main/pipeline@128"
                },
                {
                    "label": "Bounding box and CRS",
                    "doc": "Bounding box and coordinate reference system defining the analysis extent. This extent is used to retrieve GBIF occurrences, environmental predictor rasters, the GBIF sampling-effort heatmap, and the study extent for modelling.\nThe extent you choose affects how results should be interpreted and may change which predictors emerge as important. * Larger than the species' range: results lean toward occurrence/accessibility. Predictors tied to broad-scale distributional limits (climate, biogeography) may dominate. * Similar to or smaller than the species' range: results lean toward habitat suitability. Predictors tied to local habitat structure (vegetation, soil) may matter more.\n",
                    "type": {
                        "type": "record",
                        "name": "#main/pipeline@140/crsBBox",
                        "fields": [
                            {
                                "name": "#main/pipeline@140/crsBBox/CRS",
                                "type": {
                                    "name": "#main/pipeline@140/crsBBox/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@140/crsBBox/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@140/crsBBox/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@140/crsBBox/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@140/crsBBox/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@140/crsBBox/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@140/crsBBox/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@140/crsBBox/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#main/pipeline@140/crsBBox/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            }
                        ]
                    },
                    "id": "#main/pipeline@140"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Minimum year or start date",
                    "doc": "Earliest year for GBIF records. Accepts YYYY or YYYY-MM-DD; if a full date is supplied, only the year is used.\nIt is recommended to use an early start date (e.g. 1980) to maximize the number of occurrence records for a given species.\n",
                    "default": "1980",
                    "id": "#main/pipeline@145"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Maximum year or end date",
                    "doc": "Latest year for GBIF records. Accepts YYYY or YYYY-MM-DD; if a full date is supplied, only the year is used.",
                    "default": "2024",
                    "id": "#main/pipeline@146"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Number of folds",
                    "doc": "Number of folds for random k-fold MaxEnt partitioning when partition type = random k-fold. Can be left blank when another method is chosen.",
                    "default": 10,
                    "id": "#main/pipeline@147"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Number of runs",
                    "doc": "Number of bootstrap or cross-validation runs used when preparing SDM training and testing data.",
                    "default": 2,
                    "id": "#main/pipeline@46"
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
                    "run": "#rangePredictions.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/SDM>rangePredictions.yml@68/condaPackURL"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__rangePredictions' } : null)",
                            "id": "#main/SDM>rangePredictions.yml@68/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/SDM>rangePredictions.yml@68/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/SDM>rangePredictions.yml@68/environment"
                        },
                        {
                            "source": "#main/SDM>runMaxent.yml@108/sdm_runs_out",
                            "id": "#main/SDM>rangePredictions.yml@68/predictions"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__rangePredictions/68' } : null)",
                            "id": "#main/SDM>rangePredictions.yml@68/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/SDM>rangePredictions.yml@68/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/SDM>rangePredictions.yml@68/range_predictions_out"
                    ],
                    "id": "#main/SDM>rangePredictions.yml@68"
                },
                {
                    "run": "#removeCollinearity.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/SDM>removeCollinearity.yml@97/condaPackURL"
                        },
                        {
                            "default": 0.75,
                            "id": "#main/SDM>removeCollinearity.yml@97/cutoff_cor"
                        },
                        {
                            "default": 8,
                            "id": "#main/SDM>removeCollinearity.yml@97/cutoff_vif"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__removeCollinearity' } : null)",
                            "id": "#main/SDM>removeCollinearity.yml@97/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/SDM>removeCollinearity.yml@97/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/SDM>removeCollinearity.yml@97/environment"
                        },
                        {
                            "default": "vif.cor",
                            "id": "#main/SDM>removeCollinearity.yml@97/method"
                        },
                        {
                            "default": "pearson",
                            "id": "#main/SDM>removeCollinearity.yml@97/method_cor_vif"
                        },
                        {
                            "default": 5000,
                            "id": "#main/SDM>removeCollinearity.yml@97/nb_sample"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@144/rasters_out",
                            "id": "#main/SDM>removeCollinearity.yml@97/rasters"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__removeCollinearity/97' } : null)",
                            "id": "#main/SDM>removeCollinearity.yml@97/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/SDM>removeCollinearity.yml@97/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/SDM>removeCollinearity.yml@97/rasters_selected_out"
                    ],
                    "id": "#main/SDM>removeCollinearity.yml@97"
                },
                {
                    "run": "#runMaxent.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/SDM>runMaxent.yml@108/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@140",
                            "id": "#main/SDM>runMaxent.yml@108/crs"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__runMaxent' } : null)",
                            "id": "#main/SDM>runMaxent.yml@108/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/SDM>runMaxent.yml@108/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/SDM>runMaxent.yml@108/environment"
                        },
                        {
                            "source": "#main/SDM>runMaxent.yml@108|fc",
                            "id": "#main/SDM>runMaxent.yml@108/fc"
                        },
                        {
                            "default": "AUC",
                            "id": "#main/SDM>runMaxent.yml@108/method_select_params"
                        },
                        {
                            "source": "#main/pipeline@147",
                            "id": "#main/SDM>runMaxent.yml@108/n_folds"
                        },
                        {
                            "default": "lat_lon",
                            "id": "#main/SDM>runMaxent.yml@108/orientation_block"
                        },
                        {
                            "source": "#main/SDM>runMaxent.yml@108|partition_type",
                            "id": "#main/SDM>runMaxent.yml@108/partition_type"
                        },
                        {
                            "source": "#main/SDM>removeCollinearity.yml@97/rasters_selected_out",
                            "id": "#main/SDM>runMaxent.yml@108/predictors"
                        },
                        {
                            "source": "#main/SDM>setupDataSdm.yml@44/presence_background_out",
                            "id": "#main/SDM>runMaxent.yml@108/presence_background"
                        },
                        {
                            "source": "#main/SDM>runMaxent.yml@108|rm",
                            "id": "#main/SDM>runMaxent.yml@108/rm"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__runMaxent/108' } : null)",
                            "id": "#main/SDM>runMaxent.yml@108/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/SDM>runMaxent.yml@108/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/SDM>runMaxent.yml@108/sdm_pred_out",
                        "#main/SDM>runMaxent.yml@108/sdm_runs_out"
                    ],
                    "id": "#main/SDM>runMaxent.yml@108"
                },
                {
                    "run": "#selectBackground.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/SDM>selectBackground.yml@40/condaPackURL"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__selectBackground' } : null)",
                            "id": "#main/SDM>selectBackground.yml@40/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/SDM>selectBackground.yml@40/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/SDM>selectBackground.yml@40/environment"
                        },
                        {
                            "source": "#main/SDM>studyExtent.yml@104/study_extent_out",
                            "id": "#main/SDM>selectBackground.yml@40/extent"
                        },
                        {
                            "source": "#main/SDM>selectBackground.yml@40|method_background",
                            "id": "#main/SDM>selectBackground.yml@40/method_background"
                        },
                        {
                            "source": "#main/SDM>selectBackground.yml@40|n_background",
                            "id": "#main/SDM>selectBackground.yml@40/n_background"
                        },
                        {
                            "source": "#main/SDM>removeCollinearity.yml@97/rasters_selected_out",
                            "id": "#main/SDM>selectBackground.yml@40/predictors"
                        },
                        {
                            "source": "#main/filtering>cleanCoordinates.yml@34/clean_presence_out",
                            "id": "#main/SDM>selectBackground.yml@40/presence"
                        },
                        {
                            "source": "#main/data>GBIFHeatmapFromSTAC.yml@139/rasters_out",
                            "id": "#main/SDM>selectBackground.yml@40/raster"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__selectBackground/40' } : null)",
                            "id": "#main/SDM>selectBackground.yml@40/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/SDM>selectBackground.yml@40/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/SDM>selectBackground.yml@40/n_background_out",
                        "#main/SDM>selectBackground.yml@40/background_out"
                    ],
                    "id": "#main/SDM>selectBackground.yml@40"
                },
                {
                    "run": "#setupDataSdm.cwl",
                    "in": [
                        {
                            "source": "#main/SDM>selectBackground.yml@40/background_out",
                            "id": "#main/SDM>setupDataSdm.yml@44/background"
                        },
                        {
                            "default": 0.7,
                            "id": "#main/SDM>setupDataSdm.yml@44/boot_proportion"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/SDM>setupDataSdm.yml@44/condaPackURL"
                        },
                        {
                            "default": 5,
                            "id": "#main/SDM>setupDataSdm.yml@44/cv_partitions"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__setupDataSdm' } : null)",
                            "id": "#main/SDM>setupDataSdm.yml@44/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/SDM>setupDataSdm.yml@44/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/SDM>setupDataSdm.yml@44/environment"
                        },
                        {
                            "default": "bootstrap",
                            "id": "#main/SDM>setupDataSdm.yml@44/partition_type"
                        },
                        {
                            "source": "#main/SDM>removeCollinearity.yml@97/rasters_selected_out",
                            "id": "#main/SDM>setupDataSdm.yml@44/predictors"
                        },
                        {
                            "source": "#main/filtering>cleanCoordinates.yml@34/clean_presence_out",
                            "id": "#main/SDM>setupDataSdm.yml@44/presence"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__setupDataSdm/44' } : null)",
                            "id": "#main/SDM>setupDataSdm.yml@44/runFolder"
                        },
                        {
                            "source": "#main/pipeline@46",
                            "id": "#main/SDM>setupDataSdm.yml@44/runs_n"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/SDM>setupDataSdm.yml@44/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/SDM>setupDataSdm.yml@44/presence_background_out"
                    ],
                    "id": "#main/SDM>setupDataSdm.yml@44"
                },
                {
                    "run": "#studyExtent.cwl",
                    "in": [
                        {
                            "source": "#main/pipeline@140",
                            "id": "#main/SDM>studyExtent.yml@104/bbox_crs"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/SDM>studyExtent.yml@104/condaPackURL"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/SDM>studyExtent.yml@104/environment"
                        },
                        {
                            "default": "bbox",
                            "id": "#main/SDM>studyExtent.yml@104/method"
                        },
                        {
                            "source": "#main/filtering>cleanCoordinates.yml@34/clean_presence_out",
                            "id": "#main/SDM>studyExtent.yml@104/presence"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/SDM__studyExtent/104' } : null)",
                            "id": "#main/SDM>studyExtent.yml@104/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/SDM>studyExtent.yml@104/scripts_root"
                        },
                        {
                            "default": 0,
                            "id": "#main/SDM>studyExtent.yml@104/width_buffer"
                        }
                    ],
                    "out": [
                        "#main/SDM>studyExtent.yml@104/area_study_extent_out",
                        "#main/SDM>studyExtent.yml@104/study_extent_out"
                    ],
                    "id": "#main/SDM>studyExtent.yml@104"
                },
                {
                    "run": "#GBIFHeatmapFromSTAC.cwl",
                    "in": [
                        {
                            "source": "#main/pipeline@140",
                            "id": "#main/data>GBIFHeatmapFromSTAC.yml@139/bbox_crs"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>GBIFHeatmapFromSTAC.yml@139/condaPackURL"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>GBIFHeatmapFromSTAC.yml@139/environment"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__GBIFHeatmapFromSTAC/139' } : null)",
                            "id": "#main/data>GBIFHeatmapFromSTAC.yml@139/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>GBIFHeatmapFromSTAC.yml@139/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@128",
                            "id": "#main/data>GBIFHeatmapFromSTAC.yml@139/spatial_res"
                        },
                        {
                            "source": "#main/data>GBIFHeatmapFromSTAC.yml@139|taxa",
                            "id": "#main/data>GBIFHeatmapFromSTAC.yml@139/taxa"
                        }
                    ],
                    "out": [
                        "#main/data>GBIFHeatmapFromSTAC.yml@139/rasters_out"
                    ],
                    "id": "#main/data>GBIFHeatmapFromSTAC.yml@139"
                },
                {
                    "run": "#getGBIFObservations.cwl",
                    "in": [
                        {
                            "source": "#main/pipeline@140",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/bbox_crs"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/condaPackURL"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__getGBIFObservations' } : null)",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/environment"
                        },
                        {
                            "source": "#main/pipeline@146",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/max_year"
                        },
                        {
                            "source": "#main/pipeline@145",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/min_year"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__getGBIFObservations__getGBIFObservations/142' } : null)",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@121",
                            "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/taxa"
                        }
                    ],
                    "out": [
                        "#main/data>getGBIFObservations>getGBIFObservations.yml@142/observations_file_out",
                        "#main/data>getGBIFObservations>getGBIFObservations.yml@142/total_records_out",
                        "#main/data>getGBIFObservations>getGBIFObservations.yml@142/gbif_doi_out"
                    ],
                    "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142"
                },
                {
                    "run": "#loadFromStac.cwl",
                    "in": [
                        {
                            "default": "first",
                            "id": "#main/data>loadFromStac.yml@144/aggregation"
                        },
                        {
                            "source": "#main/pipeline@140",
                            "id": "#main/data>loadFromStac.yml@144/bbox_crs"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@144|collections_items",
                            "id": "#main/data>loadFromStac.yml@144/collections_items"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>loadFromStac.yml@144/condaPackURL"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)",
                            "id": "#main/data>loadFromStac.yml@144/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>loadFromStac.yml@144/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>loadFromStac.yml@144/environment"
                        },
                        {
                            "default": "near",
                            "id": "#main/data>loadFromStac.yml@144/resampling"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/144' } : null)",
                            "id": "#main/data>loadFromStac.yml@144/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>loadFromStac.yml@144/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@128",
                            "id": "#main/data>loadFromStac.yml@144/spatial_res"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@144|stac_url",
                            "id": "#main/data>loadFromStac.yml@144/stac_url"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@144|study_area",
                            "id": "#main/data>loadFromStac.yml@144/study_area"
                        },
                        {
                            "default": null,
                            "id": "#main/data>loadFromStac.yml@144/t0"
                        },
                        {
                            "default": null,
                            "id": "#main/data>loadFromStac.yml@144/t1"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@144|temporal_res",
                            "id": "#main/data>loadFromStac.yml@144/temporal_res"
                        }
                    ],
                    "out": [
                        "#main/data>loadFromStac.yml@144/rasters_out"
                    ],
                    "id": "#main/data>loadFromStac.yml@144"
                },
                {
                    "run": "#cleanCoordinates.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/filtering>cleanCoordinates.yml@34/condaPackURL"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/filtering__cleanCoordinates' } : null)",
                            "id": "#main/filtering>cleanCoordinates.yml@34/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/filtering>cleanCoordinates.yml@34/envFolderWritable"
                        },
                        {
                            "default": 0.8,
                            "id": "#main/filtering>cleanCoordinates.yml@34/env_threshold"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/filtering>cleanCoordinates.yml@34/environment"
                        },
                        {
                            "source": "#main/SDM>removeCollinearity.yml@97/rasters_selected_out",
                            "id": "#main/filtering>cleanCoordinates.yml@34/predictors"
                        },
                        {
                            "source": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/observations_file_out",
                            "id": "#main/filtering>cleanCoordinates.yml@34/presence"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/filtering__cleanCoordinates/34' } : null)",
                            "id": "#main/filtering>cleanCoordinates.yml@34/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/filtering>cleanCoordinates.yml@34/scripts_root"
                        },
                        {
                            "default": [
                                "equal",
                                "zeros",
                                "duplicates",
                                "same_pixel",
                                "capitals",
                                "centroids",
                                "gbif",
                                "institutions"
                            ],
                            "id": "#main/filtering>cleanCoordinates.yml@34/tests"
                        }
                    ],
                    "out": [
                        "#main/filtering>cleanCoordinates.yml@34/n_presence_out",
                        "#main/filtering>cleanCoordinates.yml@34/n_clean_out",
                        "#main/filtering>cleanCoordinates.yml@34/clean_presence_out"
                    ],
                    "id": "#main/filtering>cleanCoordinates.yml@34"
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
                            "echo \"Exporting all environments\"\nmkdir -p \"$OUTPUT_LOCATION\" \"$CONDA_PKGS_DIRS\" /conda-env-yml/envs\n\nfunction getPackedEnv {\n  condaEnvName=$1\n  condaEnvYml=$2\n  # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context\n  dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName\n  mkdir -p \"$dedicatedEnvFolder\"\n  \n  echo \"Exporting $condaEnvName...\"\n  source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh \"$OUTPUT_LOCATION\" \"$condaEnvName\" \\\n    \"$condaEnvYml\" \"$dedicatedEnvFolder\" \"$(inputs.condaPackURL)\" --noActivate\n  source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh \"$condaEnvName\" \"$dedicatedEnvFolder\"\n  echo \"Done.\"\n}\nexport -f getPackedEnv\n\nbash -c 'getPackedEnv \"filtering__cleanCoordinates\" \"channels: [conda-forge, r]\ndependencies: [r-terra, r-rjson, r-raster, r-dplyr, r-CoordinateCleaner, r-gdalcubes]\nname: filtering__cleanCoordinates\n\"'\n\nbash -c 'getPackedEnv \"SDM__selectBackground\" \"channels: [conda-forge, r]\ndependencies: [r-rjson, r-terra, r-dplyr, r-raster, r-CoordinateCleaner, r-stars,\n  r-rstac, r-gdalcubes]\nname: SDM__selectBackground\n\"'\n\nbash -c 'getPackedEnv \"SDM__setupDataSdm\" \"channels: [conda-forge, r]\ndependencies: [r-gdalcubes, r-terra, r-rjson, r-raster, r-dplyr, r-ENMeval, r-devtools]\nname: SDM__setupDataSdm\n\"'\n\nbash -c 'getPackedEnv \"SDM__rangePredictions\" \"channels: [conda-forge, r]\ndependencies: [r-terra, r-rjson, r-raster, r-dplyr]\nname: SDM__rangePredictions\n\"'\n\nbash -c 'getPackedEnv \"SDM__removeCollinearity\" \"channels: [conda-forge, r]\ndependencies: [r-terra, r-rjson, r-dplyr, r-gdalcubes]\nname: SDM__removeCollinearity\n\"'\n\nbash -c 'getPackedEnv \"SDM__runMaxent\" \"channels: [conda-forge, r]\ndependencies: [libgdal, r-abind, r-base, r-curl, r-dismo, r-downloader, r-dplyr, r-enmeval=2.0.3,\n  r-ecospat, r-essentials, r-geojsonsf, r-ggsci, r-jpeg, r-landscapemetrics, r-magrittr,\n  r-png, r-purrr, r-rcurl, r-rgbif, r-remotes, r-rjava, r-rjson, r-sf, r-stars, r-stringr,\n  r-terra, r-this.path, r-tidyselect, r-tidyverse, r-stringr]\nname: SDM__runMaxent\n\"'\n\nbash -c 'getPackedEnv \"data__getGBIFObservations__getGBIFObservations\" \"channels: [conda-forge]\ndependencies: [pygbif, pandas, pyproj]\nname: data__getGBIFObservations__getGBIFObservations\n\"'\n\nbash -c 'getPackedEnv \"data__loadFromStac\" \"channels: [conda-forge, r]\ndependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,\n  r-rcurl, r-rjson, r-sf, r-stars, r-terra]\nname: data__loadFromStac\n\"'\n"
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
                    "label": "Variability of predictions",
                    "doc": "The variability of the 95% confidence of each prediction can be viewed on a map to show uncertainty.",
                    "outputSource": "#main/SDM>rangePredictions.yml@68/range_predictions_out",
                    "id": "#main/SDM>rangePredictions.yml@68|range_predictions_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "Environmental predictors",
                    "doc": "GeoTIFF predictor rasters retained after collinearity filtering. These are the environmental variables used to fit and project the MaxEnt model.",
                    "outputSource": "#main/SDM>removeCollinearity.yml@97/rasters_selected_out",
                    "id": "#main/SDM>removeCollinearity.yml@97|rasters_selected_out"
                },
                {
                    "type": "File",
                    "label": "Predictions",
                    "doc": "MaxEnt habitat suitability prediction raster fitted using the selected model settings.",
                    "outputSource": "#main/SDM>runMaxent.yml@108/sdm_pred_out",
                    "id": "#main/SDM>runMaxent.yml@108|sdm_pred_out"
                },
                {
                    "type": "string",
                    "label": "DOI of GBIF download",
                    "doc": "A permanent DOI assigned to this specific GBIF data download. Must be cited in any publication using these data \u2014 see [GBIF's citation guidelines](https://www.gbif.org/citation-guidelines).",
                    "outputSource": "#main/data>getGBIFObservations>getGBIFObservations.yml@142/gbif_doi_out",
                    "id": "#main/data>getGBIFObservations>getGBIFObservations.yml@142|gbif_doi_out"
                },
                {
                    "type": "File",
                    "label": "Presences",
                    "doc": "Cleaned GBIF occurrence records that passed the selected coordinate-cleaning tests. These records are used as presence points in the SDM workflow.",
                    "outputSource": "#main/filtering>cleanCoordinates.yml@34/clean_presence_out",
                    "id": "#main/filtering>cleanCoordinates.yml@34|clean_presence_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "string"
                    },
                    "label": "Taxa list",
                    "doc": "Taxa supplied to the pipeline and used for GBIF occurrence retrieval and model fitting.",
                    "outputSource": "#main/pipeline@121",
                    "id": "#main/pipeline@121|default_output_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
