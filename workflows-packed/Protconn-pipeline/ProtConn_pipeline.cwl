{
    "$graph": [
        {
            "class": "CommandLineTool",
            "label": "Clean protected areas from WDPA API",
            "doc": [
                "Description:\nThis script cleans geometry issues in WDPA data and allows the user to filter based on the following criteria:\n- protected area legal status types (designated, inscribed, established)\n- inclusion of UNESCO Biosphere reserves\n- inclusion of marine protected areas\n- inclusion of areas with other effective area-based conservation measures (OECMs)\n- inclusion of protected areas represented as points\n- study area of interest\n",
                "Lifecycle tag: Core.",
                "Authors:\nJory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-b02f235",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    study_area_polygon: inputs.study_area_polygon ? inputs.study_area_polygon.path : null,\n    protected_area_file: inputs.protected_area_file ? inputs.protected_area_file.path : null,\n    crs: inputs.crs,\n    status_type: inputs.status_type,\n    include_unesco: inputs.include_unesco,\n    buffer_points: inputs.buffer_points,\n    include_marine: inputs.include_marine,\n    include_oecm: inputs.include_oecm,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"data__cleanWDPA\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-rjson=0.2.23, r-sf=1.1-0, r-lwgeom, r-remotes, r-lubridate=1.9.5,\n  r-tidyverse=2.0.0]\nname: data__cleanWDPA\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__cleanWDPA /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include protected area points",
                    "doc": "Check to include protected area represented by points. These protected areas are reported as a single point rather than a polygon. If checked, this will create a circular protected area around the reported point that is equal to the reported area. If left unchecked, all protected areas represented as points will be removed.\nProtected area points with no reported area will be removed in all cases.\n",
                    "default": true,
                    "id": "#cleanWDPA.cwl/buffer_points"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#cleanWDPA.cwl/condaPackURL"
                },
                {
                    "label": "CRS",
                    "doc": "Object containing CRS.",
                    "type": {
                        "type": "record",
                        "name": "#cleanWDPA.cwl/crs/bboxCRS",
                        "fields": [
                            {
                                "name": "#cleanWDPA.cwl/crs/bboxCRS/country",
                                "type": {
                                    "name": "#cleanWDPA.cwl/crs/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/country/countryDefinition/bboxWGS84",
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
                                "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS",
                                "type": {
                                    "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#cleanWDPA.cwl/crs/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#cleanWDPA.cwl/crs/bboxCRS/region",
                                "type": {
                                    "name": "#cleanWDPA.cwl/crs/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#cleanWDPA.cwl/crs/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#cleanWDPA.cwl/crs"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#cleanWDPA.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#cleanWDPA.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#cleanWDPA.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include marine and coastal protected areas",
                    "doc": "Check to include marine and coastal protected areas.\nNote that the analysis is still limited to the bounds of the study area polygon. The chosen polygon needs to exceed the country land boundaries in order to really include marine protected areas.\n",
                    "default": false,
                    "id": "#cleanWDPA.cwl/include_marine"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include OECMs",
                    "doc": "Check to include areas with other effective area-based conservation measures (OECMs). These are not officially designated protected areas but are still achieving conservation outcomes.\n",
                    "default": true,
                    "id": "#cleanWDPA.cwl/include_oecm"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include UNESCO Biosphere reserves",
                    "doc": "Check to include UNESCO Biosphere reserves. These serve as learning sites for sustainable development and combine biodiversity conservation with the sustainable use of natural resources and sustainable development. They may not be legally protected and may not be fully conserved, because they are often used for development or human settlement.\nExcluding these will limit the dataset to meeting stricter conservation standards.\n",
                    "default": true,
                    "id": "#cleanWDPA.cwl/include_unesco"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Protected areas file",
                    "doc": "Optional, additionnal user-provided protected areas in GeoPackage format. When left blank, the script will only use the protected areas from WDPA.\n",
                    "id": "#cleanWDPA.cwl/protected_area_file"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#cleanWDPA.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "data/cleanWDPA.R",
                    "id": "#cleanWDPA.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#cleanWDPA.cwl/scripts_root"
                },
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "enum",
                            "symbols": [
                                "#cleanWDPA.cwl/status_type/Proposed",
                                "#cleanWDPA.cwl/status_type/Inscribed",
                                "#cleanWDPA.cwl/status_type/Adopted",
                                "#cleanWDPA.cwl/status_type/Designated",
                                "#cleanWDPA.cwl/status_type/Established"
                            ]
                        }
                    },
                    "label": "PA legal status types to include",
                    "doc": "Legal status types of protected areas to include.\n**Proposed:** The site is in the process of gaining recognition through legal or other effective means. It may still be managed as a protected area during this process.\n**Inscribed:** Protected areas designated under the UNESCO World Heritage Convention.\n**Adopted:** Specially protected areas of marine importance (SPAMI) created under the Barcelona convention, focusing on the protection of the marine environment and coastal region of the mediterranean.\n**Designated:** The site is legally recognized as a protected area. This implies specific binding commitment to conservation in the long term.\n**Established:** The site is recognized as protected area through other effective means. This implies long-term commitment to conservation, but without legal recognition.\n",
                    "default": [
                        "Proposed",
                        "Inscribed",
                        "Adopted",
                        "Designated",
                        "Established"
                    ],
                    "id": "#cleanWDPA.cwl/status_type"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Study area polygon",
                    "doc": "Study area of interest in a GeoPackage file.\n",
                    "id": "#cleanWDPA.cwl/study_area_polygon"
                }
            ],
            "id": "#cleanWDPA.cwl",
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#cleanWDPA.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Polygon of protected areas",
                    "doc": "Map of the protected areas in GeoPackage format, cleaned and filtered according to the input criteria.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"protected_areas_clean\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#cleanWDPA.cwl/protected_areas_clean_out"
                },
                {
                    "type": "File",
                    "label": "Study area",
                    "doc": "Study area with fixed geometry",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"study_area_clean\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#cleanWDPA.cwl/study_area_clean_out"
                }
            ]
        },
        {
            "class": "CommandLineTool",
            "label": "Load country, region, WDPA or EEZ polygons",
            "doc": [
                "Description:\nLoad polygons stored as geoparquet files. Load polygons for countries or regions, polygons from the World Database of Protected Areas,\nor polygons of Exclusive Economic Zones (EEZs). This script utilizes remote files stored as Geoparquet.\n",
                "Lifecycle tag: Core.",
                "Authors:\nJory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-b02f235",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    polygon_type: inputs.polygon_type,\n    country_region_bbox: inputs.country_region_bbox,\n    buffer: inputs.buffer,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"data__load_polygons\" \\\n\"channels: [conda-forge]\ndependencies: [r-rjson, r-dbplyr=2.5.2, r-dplyr=1.2.1, r-duckdb=1.4.4, r-fs=2.1.0,\n  r-arrow=24.0.0, r-nanoarrow=0.8.0, r-geoarrow=0.4.2, r-sf=1.1-0, r-stringi=1.8.7,\n  r-stringr=1.6.0, r-tidyr=1.3.2, r-uuid=1.2_2, r-remotes=2.5.0]\nname: data__load_polygons\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__load_polygons /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Transboundary buffer",
                    "doc": "Buffer for pulling transboundary protected areas (WDPA data only). The buffer will pull protected areas within that distance of the country border or bounding box in the unit of the coordinate reference system (meters or degrees). If pulling WDPA data with a custom bounding box, the buffer will not be applied.",
                    "default": 0,
                    "id": "#load_polygons.cwl/buffer"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#load_polygons.cwl/condaPackURL"
                },
                {
                    "label": "Country, region, or bounding box",
                    "doc": "Use the chooser to select a country/ region or create a custom bounding box (region selections will be ignored for EEZs since they are national).",
                    "type": {
                        "type": "record",
                        "name": "#load_polygons.cwl/country_region_bbox/bboxCRS",
                        "fields": [
                            {
                                "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/country",
                                "type": {
                                    "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/country/countryDefinition/bboxWGS84",
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
                                "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS",
                                "type": {
                                    "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/region",
                                "type": {
                                    "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/country_region_bbox/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#load_polygons.cwl/country_region_bbox"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#load_polygons.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#load_polygons.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#load_polygons.cwl/environment"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#load_polygons.cwl/polygon_type/Country or region",
                            "#load_polygons.cwl/polygon_type/WDPA",
                            "#load_polygons.cwl/polygon_type/EEZ",
                            "#load_polygons.cwl/polygon_type/Polygon of bounding box"
                        ]
                    },
                    "label": "Polygon type",
                    "doc": "Type of polygon to load. Country or region polygons, World database of Protected Areas (WDPA), Exclusive Economic Zones (EEZs), or a custom polygon of a bounding box.",
                    "default": "Country or region",
                    "id": "#load_polygons.cwl/polygon_type"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#load_polygons.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "data/load_polygons.R",
                    "id": "#load_polygons.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#load_polygons.cwl/scripts_root"
                }
            ],
            "outputs": [
                {
                    "label": "Bounding box and crs of polygon",
                    "doc": "Bounding box and coordinate reference system of output polygon",
                    "type": {
                        "type": "record",
                        "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS",
                        "fields": [
                            {
                                "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/country",
                                "type": {
                                    "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/country/countryDefinition/bboxWGS84",
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
                                "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS",
                                "type": {
                                    "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/region",
                                "type": {
                                    "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#load_polygons.cwl/bbox_crs_out/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#load_polygons.cwl/bbox_crs_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#load_polygons.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "Polygon",
                    "doc": "Polygons of the country, WDPA, EEZs for the country or region of interest",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"polygon\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#load_polygons.cwl/polygon_out"
                }
            ],
            "id": "#load_polygons.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Protconn Analysis",
            "doc": [
                "Description:\nThis script calculates the Protected Connected Index (ProtConn) from protected area polygons using the MK_ProtConn function in the Makurhini package. This creates a distance matrix from protected area polygons and calculates ProtConn using dispersal probabilities between protected areas.\n",
                "Lifecycle tag: Reviewed.",
                "Authors:\nJory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)\n",
                "External link: https://github.com/GEO-BON/biab-2.0/tree/main/scripts/protconn_analysis",
                "References:\nGod\u00ednez-G\u00f3mez, O., Correa Ayram, C.A., Goicolea, T., Saura, S. 2026. Makurhini An R package for comprehensive analysis of landscape fragmentation and connectivity. Environmental Modelling & Software.\nhttps://doi.org/10.1016/j.envsoft.2026.106981\n\nSaura, Santiago, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Gr\u00e9goire Dubois. 2017. \u201cProtected Areas in the World\u2019s Ecoregions: How Well Connected Are They?\u201d Ecological Indicators 76:144\u201358.\nhttps://doi.org/10.1016/j.ecolind.2016.12.047\n\nSaura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Gr\u00e9goire Dubois. 2018. \u201cProtected Area Connectivity: Shortfalls in Global Targets and Country-Level Priorities.\u201d Biological Conservation 219:53\u201367.\nhttps://doi.org/10.1016/j.biocon.2017.12.020\n\nSaura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Gr\u00e9goire Dubois. 2019. \u201cGlobal Trends in Protected Area Connectivity from 2010 to 2018.\u201d Biological Conservation 238:108183.\nhttps://doi.org/10.1016/j.biocon.2019.07.028\n\nUNEP-WCMC and IUCN (2026), Protected Planet: The World Database on Protected Areas (WDPA), Cambridge, UK: UNEP-WCMC and IUCN.\nhttps://doi.org/10.34892/6fwd-af11\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-b02f235",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    study_area_polygon: (inputs.study_area_polygon || []).map(function(file) { return file.path; }),\n    protected_area_polygon: (inputs.protected_area_polygon || []).map(function(file) { return file.path; }),\n    buffer: inputs.buffer,\n    date_column_name: inputs.date_column_name,\n    crs: inputs.crs,\n    distance_threshold: inputs.distance_threshold,\n    pa_size_threshold: inputs.pa_size_threshold,\n    years: inputs.years,\n    time_series: inputs.time_series,\n    include_na_dates: inputs.include_na_dates,\n    start_year: inputs.start_year,\n    year_int: inputs.year_int,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"protconn_analysis__protconn_analysis\" \\\n\"channels: [conda-forge]\ndependencies: [r-ggrepel, r-proj, r-remotes, r-rjson, r-tidyverse, r-units, r-boot,\n  r-cpprouting, r-data.table, r-formattable, r-furrr, r-future, r-gdistance, r-ggplot2,\n  r-ggpubr, r-googledrive, r-igraph, r-magrittr, r-ps, r-purrr, r-rappdirs, r-raster,\n  r-rlang, r-rmapshaper, r-sf, r-terra, r-rcppeigen, r-rcppthread, r-adegenet, r-ecodist,\n  r-foreign, r-hierfstat, r-pegas, r-spatstat.geom, r-spatstat.linnet, r-vegan]\nname: protconn_analysis__protconn_analysis\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh protconn_analysis__protconn_analysis /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Transboundary buffer",
                    "doc": "Buffer for pulling transboundary protected areas (WDPA data only). The buffer will pull protected areas within that distance of the country border or bounding box in the unit of the coordinate reference system (meters or degrees). If pulling WDPA data with a custom bounding box, the buffer will not be applied.",
                    "default": 0,
                    "id": "#protconn_analysis.cwl/buffer"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#protconn_analysis.cwl/condaPackURL"
                },
                {
                    "label": "CRS",
                    "doc": "Object containing CRS.",
                    "type": {
                        "type": "record",
                        "name": "#protconn_analysis.cwl/crs/bboxCRS",
                        "fields": [
                            {
                                "name": "#protconn_analysis.cwl/crs/bboxCRS/country",
                                "type": {
                                    "name": "#protconn_analysis.cwl/crs/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/country/countryDefinition/bboxWGS84",
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
                                "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS",
                                "type": {
                                    "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#protconn_analysis.cwl/crs/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#protconn_analysis.cwl/crs/bboxCRS/region",
                                "type": {
                                    "name": "#protconn_analysis.cwl/crs/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#protconn_analysis.cwl/crs/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#protconn_analysis.cwl/crs"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Date column name",
                    "doc": "Name of the column in the user provided protected area file that specifies when the PA was created. Leave blank if only using WDPA data or your protected area file does not have a date column.",
                    "id": "#protconn_analysis.cwl/date_column_name"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "int"
                        }
                    ],
                    "label": "Distance analysis threshold",
                    "doc": "Refers to the threshold distance (in meters) used to estimate if the areas are connected in a spatial analysis. This threshold represents the median dispersal probability (i.e. where the dispersal probability between patches is 0.5). Dispersal probability is calculated with an exponential decay function with increasing distance.\nCommon dispersal distances that encompass a large majority of terrestrial species are 1000 meters, 3000 meters, 10,000 meters, and 100,000 meters (Saura et al. 2017).\nNote that the more distances you include, the longer the pipeline will take to complete and the more memory it will require. Additionally, larger dispersal distances will be more computationally intensive.\n",
                    "default": [
                        1000,
                        10000
                    ],
                    "id": "#protconn_analysis.cwl/distance_threshold"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#protconn_analysis.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#protconn_analysis.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#protconn_analysis.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include missing values for date",
                    "doc": "How missing values for date should be handled in the time series analysis. If the box is checked, protected areas with missing values for establishment date will be included in the time series analysis and assigned to the chosen value for start year. If not checked, these protected areas will be omitted from the time series analysis (note they will still be included in the main analysis).",
                    "default": true,
                    "id": "#protconn_analysis.cwl/include_na_dates"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "PA size threshold",
                    "doc": "Size threshold for PAs, in meters squared. Protected areas smaller than this area will be removed. A threshold of 1km2 was used in Saura et al. 2017 because at larger scales, protected areas less than 1km2 (1000 m2) do not have a large impact on ProtConn values. Removing small protected areas significantly speeds up calculation and is recommended for large areas. To not PAs filter by size threshold, input a value of 0.",
                    "default": 1000,
                    "id": "#protconn_analysis.cwl/pa_size_threshold"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "Polygon of protected areas",
                    "doc": "The protected areas (PAs) of interest.",
                    "id": "#protconn_analysis.cwl/protected_area_polygon"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#protconn_analysis.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "protconn_analysis/protconn_analysis.R",
                    "id": "#protconn_analysis.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#protconn_analysis.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Start year",
                    "doc": "Year for the time series plot to start. Missing dates for protected area establishment will be automatically assigned to this year for the time series analysis. Leave blank if time series is not selected.",
                    "default": 1980,
                    "id": "#protconn_analysis.cwl/start_year"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "Polygon of study area",
                    "doc": "Polygon of the study area, in GeoPackage format. To use a custom study area, input the path to the file in the userdata folder (e.g. /userdata/study_area_polygon.gpkg).",
                    "id": "#protconn_analysis.cwl/study_area_polygon"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Time series",
                    "doc": "Whether to calculate time series plot of ProtConn values based on date of PA establishment",
                    "default": true,
                    "id": "#protconn_analysis.cwl/time_series"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Year interval",
                    "doc": "Year interval for the time series plot of ProtConn values (e.g. an input of 20 will calculate ProtConn for every 20 years by filtering out protected areas established before that year). The last year will always be the input year. Leave blank if time series is not selected.",
                    "default": 20,
                    "id": "#protconn_analysis.cwl/year_int"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Year for cutoff",
                    "doc": "Year for which you want ProtConn calculated (e.g. an input of 2000 will calculate ProtConn for only PAs that were designated before the year 2000). Leave blank if only using WDPA data or your protected area file does not have dates. Note that if your protected area file doesn't have dates you cannot do the time series analysis.",
                    "default": 2025,
                    "id": "#protconn_analysis.cwl/years"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#protconn_analysis.cwl/logs"
                },
                {
                    "type": "File",
                    "label": "ProtConn results",
                    "doc": "The results of the ProtConn calculations. \"Prot\" and \"Unprot\" is the percentage of the study area that is protected and unprotected, respectively. \"ProtConn\" is the percentage of the study area that is protected, and connected, ProtUnconn is the percentage that is protected but unconnected. \"ProtConn Within\" is the percentage of the landscape that is connected within a single protected area, i.e. the contribution to overall connectivity coming from within the protected area, without species having to traverse unprotected land. \"ProtConn Contig\" is the proportion connected through direct physical adjascency, capturing the value of neighboring or touching PAs.\n",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"protconn_result\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#protconn_analysis.cwl/protconn_result_out"
                },
                {
                    "type": "string",
                    "label": "Area of protected areas",
                    "doc": "Total area of the protected areas in square kilometers",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"protected_area_km2\");\n  return value;\n}\n"
                    },
                    "id": "#protconn_analysis.cwl/protected_area_km2_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "Protected areas",
                    "doc": "Protected areas on which ProtConn has been calculated. Overlapping protected areas have been merged into one to speed up calculation. Protected areas less than the threshold size were also removed.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"protected_areas\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return { class: \"File\", location: \"file://\" + value };\n  });\n}\n"
                    },
                    "id": "#protconn_analysis.cwl/protected_areas_out"
                },
                {
                    "type": "File",
                    "label": "ProtConn result plot",
                    "doc": "Donut plot of the percentage of total area that is unprotected, protected-connected, and protected-unconnected for each input dispersal distance (in meters).\n",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"result_plot\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#protconn_analysis.cwl/result_plot_out"
                },
                {
                    "type": "File",
                    "label": "ProtConn time series results",
                    "doc": "Table of the time series of ProtConn and ProtUnconn values, calculated at the time interval that is specified",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"result_yrs\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#protconn_analysis.cwl/result_yrs_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "ProtConn time series plot",
                    "doc": "Change in the percentage area that is protected and the percentage that is protected and connected over time, at the chosen time interval, compared to the Kunming-Montreal GBF goals.",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"result_yrs_plot\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return { class: \"File\", location: \"file://\" + value };\n  });\n}\n"
                    },
                    "id": "#protconn_analysis.cwl/result_yrs_plot_out"
                },
                {
                    "type": "string",
                    "label": "Area of study area",
                    "doc": "Area of the study area in square kilometers",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"study_area_km2\");\n  return value;\n}\n"
                    },
                    "id": "#protconn_analysis.cwl/study_area_km2_out"
                }
            ],
            "id": "#protconn_analysis.cwl"
        },
        {
            "class": "Workflow",
            "label": "ProtConn Analysis with WDPA",
            "doc": [
                "Description:\n## Introduction\nThe Protected Connected Index (ProtConn) is a key indicator within the Kunming-Montreal Global Biodiversity Framework (GBF) to assess progress toward Goal A and Target 3, which aims to  protect 30% of the planet through well-connected networks by 2030. ProtConn quantifies the percentage of a country or region where protected areas are effectively connected, allowing  for species movement and ecological flow. \n\nProtConn measures how well a region is protected and connected (Saura et al. 2017, 2018). ProtConn is calculated by evaluating the spatial arrangement of protected areas to determine how easily species can move between them across  a landscape. It treats protected areas as \"nodes\" and potential movement between them as \"links\",  measuring the probability that a species with a given dispersal distance will be able to travel between protected areas. This probability is calculated between the nearest edge of adjacent protected areas with a negative exponential dispersal kernel with the input dispersal distance as the median, or where dispersal probability is 0.5. The final  ProtConn value is expressed as a percentage of the total study area, partitioned into percentages that account for connectivity within PAs, between different PAs, and across international borders. To learn more about the ProtConn method, see Saura et al. 2017, 2018, 2019. \n\nThe pipeline uses the \u2018Makurhini\u2019 package (Godinez-Gomez et al. 2026) to calculate ProtConn  metrics. The pipeline can be run with data from the World Database of Protected Areas  (UNEP-WCMC and IUCN 2026) pulled for a specific country or region within the pipeline,  custom shapefiles of protected areas that are uploaded by the user, or a combination of  both. This allows users to evaluate ProtConn currently and with the addition of proposed  future protected areas. ProtConn can be calculated at the country or region level. \n## Uses\nProtConn can be used to assess current progress towards Goal A and Target 3 of the the GBF. The pipeline can also be used to compare the connectedness of different proposed protected areas, assisting with planning and design. The pipeline can be run with a combination of current protected areas from WDPA and user-input polygons of  proposed protected area sites, allowing users to evaluate different plans for protected area expansion.\n## Pipeline limitations \n* On larger datasets, the pipeline is slow and uses a lot of memory, especially with larger input dispersal distances. \n* Currently, the pipeline does not take into account landscape resistance (ie. whether land between protected areas is easily traversed by species) \n## Before you start \nNo API keys are needed to run this pipeline.\nIf you would like to run the pipeline with a custom polygon for your study area, input your file path starting from the user data folder into the \"polygon of study area\" input box  (ex: /userdata/study_area_polygon.gpkg).\n\nIf you would like to run the pipeline with a combination of custom protected area polygons and WDPA data,  ensure your data is in GeoPackage format and input the file path into the \"polygon of protected areas\" input (ex: /userdata/my_PA_polygons.gpkg).\n\nIf you want to run the analysis with custom protected area data only, please use  the `ProtConn Analysis with custom PAs` pipeline.\n\n\n Click [here](https://boninabox.geobon.org/indicator?i=ProtConn) for more information about \n parameterizing and running the pipeline.\n",
                "Lifecycle tag: Reviewed.",
                "Authors:\nJory Griffith (Pipeline development, jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)\nGuillaume Larocque (Pipeline development, guillaume.larocque@mcgill.ca, https://orcid.org/0000-0002-5967-9156)\nLaetitia Tremblay (Pipeline testing, debugging and documentation, laetita.tremblay@mcgill.ca, https://www.linkedin.com/in/laetitia-tremblay-b0619b273/)\nJean-Michel Lord (Environment setup, technical support, standards review, jean-michel.lord@mcgill.ca, https://orcid.org/0009-0007-3826-1125)\n",
                "Reviewers:\nSantiago Saura (santiago.saura@upm.es)\nOscar Godinez-Gomez (oscargodinezgome@ufl.edu)\nCamilo Andres Correa-Ayram (correa.c@javeriana.edu.co)\nTeresa Goicolea (t.goicolea@gmail.com)\nCorey Ruha (coreyruha@gmail.com)\n",
                "References:\nGod\u00ednez-G\u00f3mez, O., Correa Ayram, C.A., Goicolea, T., Saura, S. 2026. Makurhini An R package for comprehensive analysis of landscape fragmentation and connectivity. Environmental Modelling & Software.\nnull\n\nSaura, Santiago, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Gr\u00e9goire Dubois. 2017. \u201cProtected Areas in the World\u2019s Ecoregions: How Well Connected Are They?\u201d Ecological Indicators 76:144\u201358.\nnull\n\nSaura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Gr\u00e9goire Dubois. 2018. \u201cProtected Area Connectivity: Shortfalls in Global Targets and Country-Level Priorities.\u201d Biological Conservation 219:53\u201367.\nnull\n\nSaura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Gr\u00e9goire Dubois. 2019. \u201cGlobal Trends in Protected Area Connectivity from 2010 to 2018.\u201d Biological Conservation 238:108183.\nnull\n\nUNEP-WCMC and IUCN (2026), Protected Planet: The World Database on Protected Areas (WDPA), Cambridge, UK: UNEP-WCMC and IUCN.\nnull\n"
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
                        "boolean"
                    ],
                    "label": "Buffer protected area points",
                    "doc": "Toggle on to buffer protected area points by reported area. Some protected areas are reported as single points rather than polygons. If checked, this will create a circular protected area around the reported point that is equal to the reported area. If there is no reported area, it will remove the point. If left unchecked, all protected areas represented as points will be removed.\n",
                    "default": true,
                    "id": "#main/data>cleanWDPA.yml@48|buffer_points"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include marine and coastal protected areas",
                    "doc": "Toggle on to include marine and coastal protected areas. Note that the analysis is still limited to the bounds of the study  area polygon.\n",
                    "default": false,
                    "id": "#main/data>cleanWDPA.yml@48|include_marine"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include OECMs",
                    "doc": "Toggle on to include areas with other effective area-based conservation measures (OECMs). These are not officially designated protected areas but are still achieving conservation outcomes.\n",
                    "default": true,
                    "id": "#main/data>cleanWDPA.yml@48|include_oecm"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include UNESCO Biosphere reserves",
                    "doc": "Check to include UNESCO Biosphere reserves.  These serve as learning sites for sustainable development  and combine biodiversity conservation with the sustainable use of natural resources and sustainable development.  They may not be legally protected and may not be fully conserved, because they are often used for development or human settlement. Excluding these will limit the dataset to meeting stricter conservation standards.\n",
                    "default": true,
                    "id": "#main/data>cleanWDPA.yml@48|include_unesco"
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
                            "items": "File"
                        }
                    ],
                    "label": "Polygon of protected areas (optional)",
                    "doc": "The protected areas (PAs) of interest. To combine WDPA data and custom data, add the path to the custom geopackage here \"e.g. /userdata/my_protected_areas.gpkg). They will be combined within the script. If you want to use only custom polygons, please use the \"ProtConn analysis with custom PAs\" pipeline. Leave blank to use only WDPA data.",
                    "default": [],
                    "id": "#main/pipeline@29"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "Polygon of study area (optional)",
                    "doc": "Polygon of the study area, in geopackage format. To use a custom study area, input the path to the file in userdata (e.g. /userdata/study_area_polygon.gpkg) and it will override the country polygon from the \"Get country polygon\" script. Leave blank to use country or region polygons pulled from the \"Get country polygon\" script. Protected areas outside of the country polygon will be cropped out.",
                    "default": [],
                    "id": "#main/pipeline@41"
                },
                {
                    "label": "Bounding box and CRS",
                    "doc": "Select a country/region and a CRS to obtain the associated bounding box.\nThe chosen CRS **must** be in a projected coordinate reference system (in meters) to calculate correct distances between protected areas. \n",
                    "type": {
                        "type": "record",
                        "name": "#main/pipeline@60/bboxCRS",
                        "fields": [
                            {
                                "name": "#main/pipeline@60/bboxCRS/country",
                                "type": {
                                    "name": "#main/pipeline@60/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/country/countryDefinition/bboxWGS84",
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
                                "name": "#main/pipeline@60/bboxCRS/CRS",
                                "type": {
                                    "name": "#main/pipeline@60/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#main/pipeline@60/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#main/pipeline@60/bboxCRS/region",
                                "type": {
                                    "name": "#main/pipeline@60/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@60/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#main/pipeline@60"
                },
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "enum",
                            "symbols": [
                                "#main/pipeline@68/Designated",
                                "#main/pipeline@68/Inscribed",
                                "#main/pipeline@68/Established",
                                "#main/pipeline@68/Adopted",
                                "#main/pipeline@68/Proposed"
                            ]
                        }
                    },
                    "label": "PA legal status types to include",
                    "doc": "Legal status types of protected areas to include.\n**Proposed:** The site is in the process of gaining recognition through legal or other effective means. It may still be managed as a protected area during this process. \n**Inscribed:** Protected areas designated under the UNESCO World Heritage Convention.\n**Adopted:** Specially protected areas of marine importance (SPAMI) created under the Barcelona convention, focusing on the protection of the marine environment and coastal region of the mediterranean.\n**Designated:** The site is legally recognized as a protected area. This implies specific binding commitment to conservation in the long term. \n**Established:** The site is recognized as protected area through other effective means. This implies long-term commitment to conservation, but without legal recognition.\n",
                    "default": [
                        "Designated",
                        "Inscribed",
                        "Established",
                        "Proposed",
                        "Adopted"
                    ],
                    "id": "#main/pipeline@68"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Transboundary buffer",
                    "doc": "Buffer for pulling transboundary protected areas (WDPA data only). The buffer will pull protected areas within that distance of the country border or bounding box in the unit of the coordinate reference system (meters or degrees). If pulling WDPA data with a custom bounding box, the buffer will not be applied.\nIt is recommended that the user chooses a transboundary distance 5 times greater than the largest distance threshold, which corresponds to a dispersal probability of ~0.03.\n",
                    "default": 0,
                    "id": "#main/pipeline@69"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Date column name (optional)",
                    "doc": "Name of the column in the user provided protected area file that specifies when the PA was created. Leave blank if only using WDPA data.",
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|date_column_name"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "int"
                        }
                    ],
                    "label": "Distance analysis threshold",
                    "doc": "Refers to the threshold distance (in meters) used to estimate if the areas are connected in a spatial analysis. This threshold represents the median dispersal probability (i.e. where the dispersal probability between patches is 0.5). Dispersal probability is calculated with an exponential decay function with increasing distance.\nCommon dispersal distances that encompass a large majority of terrestrial species are 1000 meters (1km), 3000 meters (3km), 10,000 meters (10 km), and 100,000 meters (100 km; Saura et al. 2017).\nNote that the more distances included, the longer the pipeline will take to run and the more memory it will require. Additionally, larger dispersal distances will be more computationally intensive. \n",
                    "default": [
                        1000,
                        10000
                    ],
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|distance_threshold"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Include missing values for date",
                    "doc": "How missing values for date should be handled in the time series analysis. If toggled on, protected areas with missing values for establishment date will be included in the time series analysis and assigned to the chosen value for start year. If not, these protected areas will be omitted from the time series analysis (note they will still be included in the main analysis).",
                    "default": true,
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|include_na_dates"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "PA size threshold",
                    "doc": "Size threshold for PAs, in meters squared. Protected areas smaller than this area will be removed. A threshold of 1000m2 was used in Saura et al. 2017 because at larger scales, protected areas less than 1000m2 do not have a large impact on ProtConn values. Removing small protected areas significantly speeds up calculation and is recommended for large areas. Input a value of 0 to keep all protected areas.",
                    "default": 1000,
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|pa_size_threshold"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Start year (optional)",
                    "doc": "Year to start the time series. This input will only be used if the time series input is selected.",
                    "default": 1980,
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|start_year"
                },
                {
                    "type": [
                        "null",
                        "boolean"
                    ],
                    "label": "Time series",
                    "doc": "Toggle on to calculate a time series ProtConn values based on date of PA establishment",
                    "default": true,
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|time_series"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Year interval (optional)",
                    "doc": "Year interval for the time series plot of ProtConn values (e.g. an input of 20 will calculate ProtConn for every 20 years by filtering out protected areas established before that year). This input will only be used if the time series input is selected.",
                    "default": 20,
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|year_int"
                },
                {
                    "type": [
                        "null",
                        "int"
                    ],
                    "label": "Year for cutoff",
                    "doc": "Year for which you want ProtConn calculated (e.g. an input of 2000 will calculate ProtConn only for PAs that were designated before the year 2000)",
                    "default": 2026,
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|years"
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
                    "run": "#cleanWDPA.cwl",
                    "in": [
                        {
                            "source": "#main/data>cleanWDPA.yml@48|buffer_points",
                            "id": "#main/data>cleanWDPA.yml@48/buffer_points"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>cleanWDPA.yml@48/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@60",
                            "id": "#main/data>cleanWDPA.yml@48/crs"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__cleanWDPA' } : null)",
                            "id": "#main/data>cleanWDPA.yml@48/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>cleanWDPA.yml@48/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>cleanWDPA.yml@48/environment"
                        },
                        {
                            "source": "#main/data>cleanWDPA.yml@48|include_marine",
                            "id": "#main/data>cleanWDPA.yml@48/include_marine"
                        },
                        {
                            "source": "#main/data>cleanWDPA.yml@48|include_oecm",
                            "id": "#main/data>cleanWDPA.yml@48/include_oecm"
                        },
                        {
                            "source": "#main/data>cleanWDPA.yml@48|include_unesco",
                            "id": "#main/data>cleanWDPA.yml@48/include_unesco"
                        },
                        {
                            "source": "#main/data>load_polygons.yml@64/polygon_out",
                            "id": "#main/data>cleanWDPA.yml@48/protected_area_file"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__cleanWDPA/48' } : null)",
                            "id": "#main/data>cleanWDPA.yml@48/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>cleanWDPA.yml@48/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@68",
                            "id": "#main/data>cleanWDPA.yml@48/status_type"
                        },
                        {
                            "source": "#main/data>load_polygons.yml@61/polygon_out",
                            "id": "#main/data>cleanWDPA.yml@48/study_area_polygon"
                        }
                    ],
                    "out": [
                        "#main/data>cleanWDPA.yml@48/study_area_clean_out",
                        "#main/data>cleanWDPA.yml@48/protected_areas_clean_out"
                    ],
                    "id": "#main/data>cleanWDPA.yml@48"
                },
                {
                    "run": "#load_polygons.cwl",
                    "in": [
                        {
                            "default": 0.0,
                            "id": "#main/data>load_polygons.yml@61/buffer"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>load_polygons.yml@61/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@60",
                            "id": "#main/data>load_polygons.yml@61/country_region_bbox"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)",
                            "id": "#main/data>load_polygons.yml@61/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>load_polygons.yml@61/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>load_polygons.yml@61/environment"
                        },
                        {
                            "default": "Country or region",
                            "id": "#main/data>load_polygons.yml@61/polygon_type"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/61' } : null)",
                            "id": "#main/data>load_polygons.yml@61/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>load_polygons.yml@61/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/data>load_polygons.yml@61/polygon_out",
                        "#main/data>load_polygons.yml@61/bbox_crs_out"
                    ],
                    "id": "#main/data>load_polygons.yml@61"
                },
                {
                    "run": "#load_polygons.cwl",
                    "in": [
                        {
                            "source": "#main/pipeline@69",
                            "id": "#main/data>load_polygons.yml@64/buffer"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>load_polygons.yml@64/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@60",
                            "id": "#main/data>load_polygons.yml@64/country_region_bbox"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)",
                            "id": "#main/data>load_polygons.yml@64/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>load_polygons.yml@64/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>load_polygons.yml@64/environment"
                        },
                        {
                            "default": "WDPA",
                            "id": "#main/data>load_polygons.yml@64/polygon_type"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/64' } : null)",
                            "id": "#main/data>load_polygons.yml@64/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>load_polygons.yml@64/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/data>load_polygons.yml@64/polygon_out",
                        "#main/data>load_polygons.yml@64/bbox_crs_out"
                    ],
                    "id": "#main/data>load_polygons.yml@64"
                },
                {
                    "when": "$(inputs.envFolderWrite != null)",
                    "run": {
                        "class": "CommandLineTool",
                        "requirements": [
                            {
                                "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-b02f235",
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
                            "echo \"Exporting all environments\"\nmkdir -p \"$OUTPUT_LOCATION\" \"$CONDA_PKGS_DIRS\" /conda-env-yml/envs\n\nfunction getPackedEnv {\n  condaEnvName=$1\n  condaEnvYml=$2\n  # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context\n  dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName\n  mkdir -p \"$dedicatedEnvFolder\"\n  \n  echo \"Exporting $condaEnvName...\"\n  source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh \"$OUTPUT_LOCATION\" \"$condaEnvName\" \\\n    \"$condaEnvYml\" \"$dedicatedEnvFolder\" \"$(inputs.condaPackURL)\" --noActivate\n  source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh \"$condaEnvName\" \"$dedicatedEnvFolder\"\n  echo \"Done.\"\n}\nexport -f getPackedEnv\n\nbash -c 'getPackedEnv \"protconn_analysis__protconn_analysis\" \"channels: [conda-forge]\ndependencies: [r-ggrepel, r-proj, r-remotes, r-rjson, r-tidyverse, r-units, r-boot,\n  r-cpprouting, r-data.table, r-formattable, r-furrr, r-future, r-gdistance, r-ggplot2,\n  r-ggpubr, r-googledrive, r-igraph, r-magrittr, r-ps, r-purrr, r-rappdirs, r-raster,\n  r-rlang, r-rmapshaper, r-sf, r-terra, r-rcppeigen, r-rcppthread, r-adegenet, r-ecodist,\n  r-foreign, r-hierfstat, r-pegas, r-spatstat.geom, r-spatstat.linnet, r-vegan]\nname: protconn_analysis__protconn_analysis\n\"'\n\nbash -c 'getPackedEnv \"data__cleanWDPA\" \"channels: [conda-forge, r]\ndependencies: [r-rjson=0.2.23, r-sf=1.1-0, r-lwgeom, r-remotes, r-lubridate=1.9.5,\n  r-tidyverse=2.0.0]\nname: data__cleanWDPA\n\"'\n\nbash -c 'getPackedEnv \"data__load_polygons\" \"channels: [conda-forge]\ndependencies: [r-rjson, r-dbplyr=2.5.2, r-dplyr=1.2.1, r-duckdb=1.4.4, r-fs=2.1.0,\n  r-arrow=24.0.0, r-nanoarrow=0.8.0, r-geoarrow=0.4.2, r-sf=1.1-0, r-stringi=1.8.7,\n  r-stringr=1.6.0, r-tidyr=1.3.2, r-uuid=1.2_2, r-remotes=2.5.0]\nname: data__load_polygons\n\"'\n"
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
                },
                {
                    "run": "#protconn_analysis.cwl",
                    "in": [
                        {
                            "source": "#main/pipeline@69",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/buffer"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@60",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/crs"
                        },
                        {
                            "source": "#main/protconn_analysis>protconn_analysis.yml@42|date_column_name",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/date_column_name"
                        },
                        {
                            "source": "#main/protconn_analysis>protconn_analysis.yml@42|distance_threshold",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/distance_threshold"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/protconn_analysis__protconn_analysis' } : null)",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/environment"
                        },
                        {
                            "source": "#main/protconn_analysis>protconn_analysis.yml@42|include_na_dates",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/include_na_dates"
                        },
                        {
                            "source": "#main/protconn_analysis>protconn_analysis.yml@42|pa_size_threshold",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/pa_size_threshold"
                        },
                        {
                            "source": [
                                "#main/pipeline@29",
                                "#main/data>cleanWDPA.yml@48/protected_areas_clean_out"
                            ],
                            "linkMerge": "merge_flattened",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/protected_area_polygon"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/protconn_analysis__protconn_analysis/42' } : null)",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/scripts_root"
                        },
                        {
                            "source": "#main/protconn_analysis>protconn_analysis.yml@42|start_year",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/start_year"
                        },
                        {
                            "source": [
                                "#main/pipeline@41",
                                "#main/data>cleanWDPA.yml@48/study_area_clean_out"
                            ],
                            "linkMerge": "merge_flattened",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/study_area_polygon"
                        },
                        {
                            "source": "#main/protconn_analysis>protconn_analysis.yml@42|time_series",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/time_series"
                        },
                        {
                            "source": "#main/protconn_analysis>protconn_analysis.yml@42|year_int",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/year_int"
                        },
                        {
                            "source": "#main/protconn_analysis>protconn_analysis.yml@42|years",
                            "id": "#main/protconn_analysis>protconn_analysis.yml@42/years"
                        }
                    ],
                    "out": [
                        "#main/protconn_analysis>protconn_analysis.yml@42/protected_areas_out",
                        "#main/protconn_analysis>protconn_analysis.yml@42/study_area_km2_out",
                        "#main/protconn_analysis>protconn_analysis.yml@42/protected_area_km2_out",
                        "#main/protconn_analysis>protconn_analysis.yml@42/protconn_result_out",
                        "#main/protconn_analysis>protconn_analysis.yml@42/result_plot_out",
                        "#main/protconn_analysis>protconn_analysis.yml@42/result_yrs_plot_out",
                        "#main/protconn_analysis>protconn_analysis.yml@42/result_yrs_out"
                    ],
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "Study area polygon",
                    "doc": "Polygon of the study area",
                    "outputSource": "#main/data>load_polygons.yml@61/polygon_out",
                    "id": "#main/data>load_polygons.yml@61|polygon_out"
                },
                {
                    "type": "File",
                    "label": "ProtConn results",
                    "doc": "The results of the ProtConn calculations. \"Prot\" and \"Unprot\" is the percentage of the study area that is \n      protected and unprotected, respectively. \"ProtConn\" is the percentage of the study area that is protected, and\n      connected, ProtUnconn is the percentage that is protected but unconnected. \"ProtConn Within\" is the percentage\n      of the landscape that is connected within a single protected area, i.e. the contribution to overall connectivity\n      coming from within the protected area, without species having to traverse unprotected land. \"ProtConn Contig\"\n      is the proportion connected through direct physical adjascency, capturing the value of neighboring or touching PAs. \n",
                    "outputSource": "#main/protconn_analysis>protconn_analysis.yml@42/protconn_result_out",
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|protconn_result_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "Protected areas",
                    "doc": "Protected areas polygons for the ProtConn calculation. Overlapping protected areas have been merged to speed up calculation.",
                    "outputSource": "#main/protconn_analysis>protconn_analysis.yml@42/protected_areas_out",
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|protected_areas_out"
                },
                {
                    "type": "File",
                    "label": "ProtConn result plot",
                    "doc": "Donut plot of the percentage of total area that is unprotected, protected and connected, and protected and unconnected for each input dispersal distance (in meters).",
                    "outputSource": "#main/protconn_analysis>protconn_analysis.yml@42/result_plot_out",
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|result_plot_out"
                },
                {
                    "type": "File",
                    "label": "ProtConn time series results",
                    "doc": "Table of the time series of ProtConn and ProtUnconn values, calculated at the time interval that is specified.",
                    "outputSource": "#main/protconn_analysis>protconn_analysis.yml@42/result_yrs_out",
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|result_yrs_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "ProtConn time series plot",
                    "doc": "Change in the percentage area that is protected and the percentage that is protected and connected over time, at the chosen time interval, compared to the Kunming-Montreal GBF goals.",
                    "outputSource": "#main/protconn_analysis>protconn_analysis.yml@42/result_yrs_plot_out",
                    "id": "#main/protconn_analysis>protconn_analysis.yml@42|result_yrs_plot_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
