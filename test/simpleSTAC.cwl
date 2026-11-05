{
    "$graph": [
        {
            "class": "CommandLineTool",
            "label": "TIFF to STAC Collection",
            "doc": [
                "Description:\nConverts GeoTIFF files into a STAC collection. A STAC collection is JSON file aggregating spatial temporal data in the form of geospatial files and their metadata.\n",
                "Lifecycle tag: Core.",
                "Authors:\nLaetitia Tremblay (laetitia.tremblay@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:latest",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    tiff_files: (inputs.tiff_files || []).map(function(file) { return file.path; }),\n    collection_name: inputs.collection_name,\n    collection_description: inputs.collection_description,\n    collection_license: inputs.collection_license,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"STAC__createCollection\" \\\n\"channels: [conda-forge]\ndependencies: [pystac, gdal, jsonschema, rasterio, shapely, pyproj, geopandas, rasterstats,\n  numpy]\nname: STAC__createCollection\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\npython3 \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.py \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh STAC__createCollection /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Collection Description",
                    "doc": "Description of the STAC collection to be created.",
                    "default": "A STAC collection created from GeoTIFF files.",
                    "id": "#createCollection.cwl/collection_description"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Collection License",
                    "doc": "License for the STAC collection to be created. Default is \"CC-BY\".",
                    "default": "CC-BY",
                    "id": "#createCollection.cwl/collection_license"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Collection Name",
                    "doc": "Name of the STAC collection to be created. The collection name should be unique, using lowercase letters and hyphens only. Default is \"biab-collection\".",
                    "default": "biab-collection",
                    "id": "#createCollection.cwl/collection_name"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#createCollection.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#createCollection.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#createCollection.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#createCollection.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#createCollection.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "STAC/createCollection.py",
                    "id": "#createCollection.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#createCollection.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "GeoTIFF files",
                    "doc": "GeoTIFFs to be added to the collection",
                    "id": "#createCollection.cwl/tiff_files"
                }
            ],
            "id": "#createCollection.cwl",
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#createCollection.cwl/logs"
                },
                {
                    "type": "Directory",
                    "label": "STAC Collection",
                    "doc": "JSON file representing a STAC collection containing the provided GeoTIFFs The official MIME type is application/json however, we use application/stac+json to indicate that this is a STAC catalog and differentiate from other json files.\n",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"stac_collection\");\n  if (value === null) return null;\n  value = value.substring(0, value.lastIndexOf('/'));\n  return { class: \"Directory\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#createCollection.cwl/stac_collection_out"
                }
            ]
        },
        {
            "class": "CommandLineTool",
            "label": "STAC Collection to Catalog",
            "doc": [
                "Description:\nConverts STAC collection(s) into a STAC catalog. A STAC catalog is an aggregation of STAC collections.\n",
                "Lifecycle tag: Core.",
                "Authors:\nLaetitia Tremblay (laetitia.tremblay@mcgill.ca)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:latest",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    stac_collections: (inputs.stac_collections || []).map(function(file) { return file.path; }),\n    stac_name: inputs.stac_name,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"STAC__createSTAC\" \\\n\"channels: [conda-forge]\ndependencies: [pystac, jsonschema]\nname: STAC__createSTAC\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\npython3 \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.py \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh STAC__createSTAC /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#createSTAC.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#createSTAC.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#createSTAC.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#createSTAC.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#createSTAC.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "STAC/createSTAC.py",
                    "id": "#createSTAC.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#createSTAC.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "Directory"
                        }
                    ],
                    "label": "STAC collections",
                    "doc": "Input STAC collection(s) to convert to a STAC catalog. Can be a single collection or a list of collections.",
                    "id": "#createSTAC.cwl/stac_collections"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "STAC Name",
                    "doc": "Name of the STAC catalog to be created, using lowercase letters and hyphens only. Default is \"biab-stac\".",
                    "default": "biab-stac",
                    "id": "#createSTAC.cwl/stac_name"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#createSTAC.cwl/logs"
                },
                {
                    "type": "Directory",
                    "label": "STAC Catalog",
                    "doc": "STAC Catalog linking to the provided collections.\nThe official MIME type is application/json however, we use application/stac+json to indicate that this is a STAC catalog and differentiate from other json files.\n",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"stac_catalog\");\n  if (value === null) return null;\n  value = value.substring(0, value.lastIndexOf('/'));\n  return { class: \"Directory\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#createSTAC.cwl/stac_catalog_out"
                }
            ],
            "id": "#createSTAC.cwl"
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
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:latest",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\ntouch \"$log\"\ntail -f \"$log\" &\ntailPid=$!\ncleanupTail() {\n  kill \"$tailPid\" 2>/dev/null\n  wait \"$tailPid\" 2>/dev/null\n}\ntrap cleanupTail EXIT\n\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    bbox_crs: inputs.bbox_crs,\n    stac_url: inputs.stac_url,\n    collections_items: inputs.collections_items,\n    t0: inputs.t0,\n    t1: inputs.t1,\n    temporal_res: inputs.temporal_res,\n    spatial_res: inputs.spatial_res,\n    resampling: inputs.resampling,\n    aggregation: inputs.aggregation,\n    study_area: inputs.study_area ? inputs.study_area.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" >> \"$log\"\necho \"Inputs:\" >> \"$log\"\ncat \"$OUTPUT_LOCATION/input.json\" >> \"$log\"\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"data__loadFromStac\" \\\n\"channels: [conda-forge, r]\ndependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,\n  r-rcurl, r-rjson, r-sf, r-stars, r-terra]\nname: data__loadFromStac\n\" /conda-envs \"$CONDA_PACK_URL\" >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  \"$SCRIPT_LOCATION/$SCRIPT_PATH\" \\\n  >> \"$log\" 2>&1\nscriptExitCode=$?\necho \"Script exited with code $scriptExitCode\" >> \"$log\"\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" >> \"$log\"\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__loadFromStac /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
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
            "class": "Workflow",
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
                        "string"
                    ],
                    "label": "Collection Description",
                    "doc": "Description of the STAC collection to be created.",
                    "default": "A STAC collection created from GeoTIFF files.",
                    "id": "#main/STAC>createCollection.yml@156|collection_description"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Collection License",
                    "doc": "License for the STAC collection to be created. Default is \"CC-BY\".",
                    "default": "CC-BY",
                    "id": "#main/STAC>createCollection.yml@156|collection_license"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Collection Name",
                    "doc": "Name of the STAC collection to be created. The collection name should be unique, using lowercase letters and hyphens only. Default is \"biab-collection\".",
                    "default": "biab-collection",
                    "id": "#main/STAC>createCollection.yml@156|collection_name"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "STAC Name",
                    "doc": "Name of the STAC catalog to be created, using lowercase letters and hyphens only. Default is \"biab-stac\".",
                    "default": "biab-stac",
                    "id": "#main/STAC>createSTAC.yml@158|stac_name"
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
                            "#main/data>loadFromStac.yml@155|aggregation/first",
                            "#main/data>loadFromStac.yml@155|aggregation/min",
                            "#main/data>loadFromStac.yml@155|aggregation/max",
                            "#main/data>loadFromStac.yml@155|aggregation/mean",
                            "#main/data>loadFromStac.yml@155|aggregation/median"
                        ]
                    },
                    "label": "Aggregation method",
                    "doc": "Method used to aggregate items when layers combining over time. Will be ignored if no aggregation occurs.",
                    "default": "first",
                    "id": "#main/data>loadFromStac.yml@155|aggregation"
                },
                {
                    "label": "Bounding box and CRS",
                    "doc": "Object containing the chosen bounding box and CRS.",
                    "type": {
                        "type": "record",
                        "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox",
                        "fields": [
                            {
                                "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS",
                                "type": {
                                    "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#main/data>loadFromStac.yml@155|bbox_crs/crsBBox/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            }
                        ]
                    },
                    "id": "#main/data>loadFromStac.yml@155|bbox_crs"
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
                    "id": "#main/data>loadFromStac.yml@155|collections_items"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#main/data>loadFromStac.yml@155|resampling/near",
                            "#main/data>loadFromStac.yml@155|resampling/bilinear",
                            "#main/data>loadFromStac.yml@155|resampling/average",
                            "#main/data>loadFromStac.yml@155|resampling/mode",
                            "#main/data>loadFromStac.yml@155|resampling/cubic",
                            "#main/data>loadFromStac.yml@155|resampling/cubicspline",
                            "#main/data>loadFromStac.yml@155|resampling/lanczos",
                            "#main/data>loadFromStac.yml@155|resampling/rms",
                            "#main/data>loadFromStac.yml@155|resampling/min",
                            "#main/data>loadFromStac.yml@155|resampling/max",
                            "#main/data>loadFromStac.yml@155|resampling/sum",
                            "#main/data>loadFromStac.yml@155|resampling/med",
                            "#main/data>loadFromStac.yml@155|resampling/q1",
                            "#main/data>loadFromStac.yml@155|resampling/q3"
                        ]
                    },
                    "label": "Resampling method",
                    "doc": "Resampling method used when rescaling and/or reprojecting the raster layers. Will be ignored if no resampling occurs. See [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) for description.",
                    "default": "near",
                    "id": "#main/data>loadFromStac.yml@155|resampling"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Spatial resolution",
                    "doc": "Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). If this is left blank it will attempt to use the native resolution of the rasters, however the input CRS units must match the units of the native resolution. If the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled with the resampling method chosen below.",
                    "default": 0.00833,
                    "id": "#main/data>loadFromStac.yml@155|spatial_res"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "STAC URL",
                    "doc": "URL of the STAC catalog.",
                    "default": "https://stac.geobon.org/",
                    "id": "#main/data>loadFromStac.yml@155|stac_url"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Study area",
                    "doc": "Polygon of study area used to mask output layers, in geopackage format.",
                    "id": "#main/data>loadFromStac.yml@155|study_area"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Start date",
                    "doc": "Start date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if extracting items by name or to extract layers from all available dates.",
                    "id": "#main/data>loadFromStac.yml@155|t0"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "End date",
                    "doc": "End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if extracting items by name or to extract layers from all available dates.",
                    "id": "#main/data>loadFromStac.yml@155|t1"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Temporal resolution",
                    "doc": "Temporal resolution to use when querying STAC items by date, in the format (\"P\", time interval, and time unit, e.g. \"P1Y\" is yearly, \"P1M\" is montly, and \"P1D\" is daily). Leave blank if not querying by date or if extracting layers from all available dates. If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below.",
                    "id": "#main/data>loadFromStac.yml@155|temporal_res"
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
                    "run": "#createCollection.cwl",
                    "in": [
                        {
                            "source": "#main/STAC>createCollection.yml@156|collection_description",
                            "id": "#main/STAC>createCollection.yml@156/collection_description"
                        },
                        {
                            "source": "#main/STAC>createCollection.yml@156|collection_license",
                            "id": "#main/STAC>createCollection.yml@156/collection_license"
                        },
                        {
                            "source": "#main/STAC>createCollection.yml@156|collection_name",
                            "id": "#main/STAC>createCollection.yml@156/collection_name"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/STAC>createCollection.yml@156/condaPackURL"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/STAC__createCollection' } : null)",
                            "id": "#main/STAC>createCollection.yml@156/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/STAC>createCollection.yml@156/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/STAC>createCollection.yml@156/environment"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/STAC__createCollection/156' } : null)",
                            "id": "#main/STAC>createCollection.yml@156/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/STAC>createCollection.yml@156/scripts_root"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155/rasters_out",
                            "id": "#main/STAC>createCollection.yml@156/tiff_files"
                        }
                    ],
                    "out": [
                        "#main/STAC>createCollection.yml@156/stac_collection_out"
                    ],
                    "id": "#main/STAC>createCollection.yml@156"
                },
                {
                    "run": "#createSTAC.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/STAC>createSTAC.yml@158/condaPackURL"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/STAC__createSTAC' } : null)",
                            "id": "#main/STAC>createSTAC.yml@158/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/STAC>createSTAC.yml@158/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/STAC>createSTAC.yml@158/environment"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/STAC__createSTAC/158' } : null)",
                            "id": "#main/STAC>createSTAC.yml@158/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/STAC>createSTAC.yml@158/scripts_root"
                        },
                        {
                            "source": [
                                "#main/STAC>createCollection.yml@156/stac_collection_out"
                            ],
                            "linkMerge": "merge_flattened",
                            "id": "#main/STAC>createSTAC.yml@158/stac_collections"
                        },
                        {
                            "source": "#main/STAC>createSTAC.yml@158|stac_name",
                            "id": "#main/STAC>createSTAC.yml@158/stac_name"
                        }
                    ],
                    "out": [
                        "#main/STAC>createSTAC.yml@158/stac_catalog_out"
                    ],
                    "id": "#main/STAC>createSTAC.yml@158"
                },
                {
                    "run": "#loadFromStac.cwl",
                    "in": [
                        {
                            "source": "#main/data>loadFromStac.yml@155|aggregation",
                            "id": "#main/data>loadFromStac.yml@155/aggregation"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|bbox_crs",
                            "id": "#main/data>loadFromStac.yml@155/bbox_crs"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|collections_items",
                            "id": "#main/data>loadFromStac.yml@155/collections_items"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>loadFromStac.yml@155/condaPackURL"
                        },
                        {
                            "source": "#main/preparePackedEnvs/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)",
                            "id": "#main/data>loadFromStac.yml@155/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>loadFromStac.yml@155/envFolderWritable"
                        },
                        {
                            "source": "#main/prepareRunnerEnv/environmentFile",
                            "id": "#main/data>loadFromStac.yml@155/environment"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|resampling",
                            "id": "#main/data>loadFromStac.yml@155/resampling"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/155' } : null)",
                            "id": "#main/data>loadFromStac.yml@155/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>loadFromStac.yml@155/scripts_root"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|spatial_res",
                            "id": "#main/data>loadFromStac.yml@155/spatial_res"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|stac_url",
                            "id": "#main/data>loadFromStac.yml@155/stac_url"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|study_area",
                            "id": "#main/data>loadFromStac.yml@155/study_area"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|t0",
                            "id": "#main/data>loadFromStac.yml@155/t0"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|t1",
                            "id": "#main/data>loadFromStac.yml@155/t1"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@155|temporal_res",
                            "id": "#main/data>loadFromStac.yml@155/temporal_res"
                        }
                    ],
                    "out": [
                        "#main/data>loadFromStac.yml@155/rasters_out"
                    ],
                    "id": "#main/data>loadFromStac.yml@155"
                },
                {
                    "when": "$(inputs.envFolderWrite != null)",
                    "run": {
                        "class": "CommandLineTool",
                        "requirements": [
                            {
                                "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:latest",
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
                            "echo \"Exporting all environments\"\nmkdir -p \"$OUTPUT_LOCATION\" \"$CONDA_PKGS_DIRS\" /conda-env-yml/envs\n\nfunction getPackedEnv {\n  condaEnvName=$1\n  condaEnvYml=$2\n  # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context\n  dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName\n  mkdir -p \"$dedicatedEnvFolder\"\n\n  echo \"Exporting $condaEnvName...\"\n  source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh \"$OUTPUT_LOCATION\" \"$condaEnvName\" \\\n    \"$condaEnvYml\" \"$dedicatedEnvFolder\" \"$CONDA_PACK_URL\" --noActivate\n  source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh \"$condaEnvName\" \"$dedicatedEnvFolder\"\n  echo \"Done.\"\n}\nexport -f getPackedEnv\n\nbash -c 'getPackedEnv \"data__loadFromStac\" \"channels: [conda-forge, r]\ndependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,\n  r-rcurl, r-rjson, r-sf, r-stars, r-terra]\nname: data__loadFromStac\n\"'\n\nbash -c 'getPackedEnv \"STAC__createCollection\" \"channels: [conda-forge]\ndependencies: [pystac, gdal, jsonschema, rasterio, shapely, pyproj, geopandas, rasterstats,\n  numpy]\nname: STAC__createCollection\n\"'\n\nbash -c 'getPackedEnv \"STAC__createSTAC\" \"channels: [conda-forge]\ndependencies: [pystac, jsonschema]\nname: STAC__createSTAC\n\"'\n"
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
                            "sh",
                            "-c"
                        ],
                        "arguments": [
                            "echo \"Preparing runner.env...\"\n\ncase \"$RUNNER_ENV_URI\" in\n  http://*|https://*|file://*)\n    if ! curl -fsSL \"$RUNNER_ENV_URI\" -o runner.env; then\n      echo \"ERROR: failed to download runner.env from $RUNNER_ENV_URI\" >&2\n      exit 1\n    fi\n\n    if ! . ./runner.env; then\n      echo \"ERROR: failed to source runner.env\" >&2\n      exit 1\n    fi\n    ;;\n  *)\n    echo \"ERROR: environment file input, BON in a Box's \"runner.env\", was not provided as an URI.\" >&2\n    echo \"Please use the format file:// or https://\" >&2\n    exit 1\n    ;;\nesac\n"
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
                    "type": "Directory",
                    "label": "STAC Catalog",
                    "doc": "STAC Catalog linking to the provided collections.\nThe official MIME type is application/json however, we use application/stac+json to indicate that this is a STAC catalog and differentiate from other json files.\n",
                    "outputSource": "#main/STAC>createSTAC.yml@158/stac_catalog_out",
                    "id": "#main/STAC>createSTAC.yml@158|stac_catalog_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
