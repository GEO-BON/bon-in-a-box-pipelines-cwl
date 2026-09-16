{
    "$graph": [
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
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-259f5b2",
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
            "id": "#load_polygons.cwl",
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
            ]
        },
        {
            "class": "CommandLineTool",
            "label": "Phenology difference",
            "doc": [
                "Description:\nScript to calculate the difference in the layers of the phenology raster layers from the start to end year to show the spatial\ndistribution of changes in phenology. The start year is subtracted from the end year, so larger values indicate a larger difference in\nthe phenology layers.\n",
                "Authors:\nJory Griffith (jory.griffith@gmail.com, https://orcid.org/0000-0001-6020-6690)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-259f5b2",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    rasters: (inputs.rasters || []).map(function(file) { return file.path; }),\n    start_year: inputs.start_year,\n    end_year: inputs.end_year,\n    timeseries: inputs.timeseries ? inputs.timeseries.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"rbase\" \\\n\"\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh rbase /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#phenology_difference.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "End year",
                    "doc": "End year for phenology time series (not inclusive).",
                    "default": "2024",
                    "id": "#phenology_difference.cwl/end_year"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#phenology_difference.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#phenology_difference.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#phenology_difference.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "Rasters of phenology",
                    "doc": "Rasters for phenology",
                    "id": "#phenology_difference.cwl/rasters"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#phenology_difference.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "phenology/phenology_difference.R",
                    "id": "#phenology_difference.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#phenology_difference.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Start year",
                    "doc": "Start date for phenology time series",
                    "default": "2017",
                    "id": "#phenology_difference.cwl/start_year"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Zonal statistics",
                    "doc": "Summarised values over the polygon of interest (mean, minimum, or maximum) for each year for each band of interest",
                    "id": "#phenology_difference.cwl/timeseries"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#phenology_difference.cwl/logs"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "Change in phenology metrics",
                    "doc": "Raster plot of change in phenology from the start year to the end year. The end year is subtracted from the start year, so larger values indicate a greater decrease in the given value over time.\n",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"phenology_change\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return { class: \"File\", location: \"file://\" + value };\n  });\n}\n"
                    },
                    "id": "#phenology_difference.cwl/phenology_change_out"
                },
                {
                    "type": "File",
                    "label": "Plot of phenology change",
                    "doc": "Plot of the summarised phenology values over time for the bands of interest",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"phenology_change_plot\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#phenology_difference.cwl/phenology_change_plot_out"
                }
            ],
            "id": "#phenology_difference.cwl"
        },
        {
            "class": "CommandLineTool",
            "label": "Summarise phenology",
            "doc": [
                "Description:\nSummarises the yearly phenology data for a country (Europe only) using the copernicus data space ecosystem phenology layer. The script uses the openEO python client to send a job to openEO.\nThe raster has values for the Plant Phenology Index (PPI), which is a vegetation index that helps estimate vegetation health and photosynthetic activity throughout the growing season.\nIt is more directly related to plant phenology compared to other vegetation indices like NDVI, and does not saturate in high biomass conditions.\nIt is computed with near infrared reflectance, which is strongly reflected by healthy vegetation. You can read more about the phenology layers [here](https://land.copernicus.eu/en/dataset-catalog).\n",
                "Authors:\nJory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)\n"
            ],
            "requirements": [
                {
                    "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-259f5b2",
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    bbox_crs: inputs.bbox_crs,\n    study_area_polygon: inputs.study_area_polygon ? inputs.study_area_polygon.path : null,\n    start_year: inputs.start_year,\n    end_year: inputs.end_year,\n    season: inputs.season,\n    bands: inputs.bands,\n    aggregate_function: inputs.aggregate_function,\n    spatial_resolution: inputs.spatial_resolution,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"phenology__summarise_phenology\" \\\n\"channels: [conda-forge]\ndependencies: [openeo, pandas, geopandas, shapely]\nname: phenology__summarise_phenology\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\npython3 \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.py \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh phenology__summarise_phenology /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#summarise_phenology.cwl/aggregate_function/mean",
                            "#summarise_phenology.cwl/aggregate_function/min",
                            "#summarise_phenology.cwl/aggregate_function/max"
                        ]
                    },
                    "label": "Aggregate function",
                    "doc": "Function to spatially aggregate the phenology data",
                    "default": "mean",
                    "id": "#summarise_phenology.cwl/aggregate_function"
                },
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "enum",
                            "symbols": [
                                "#summarise_phenology.cwl/bands/SOSD",
                                "#summarise_phenology.cwl/bands/EOSD",
                                "#summarise_phenology.cwl/bands/SOSV",
                                "#summarise_phenology.cwl/bands/EOSV",
                                "#summarise_phenology.cwl/bands/MAXD",
                                "#summarise_phenology.cwl/bands/MAXV",
                                "#summarise_phenology.cwl/bands/MINV",
                                "#summarise_phenology.cwl/bands/AMPL",
                                "#summarise_phenology.cwl/bands/LENGTH",
                                "#summarise_phenology.cwl/bands/LSLOPE",
                                "#summarise_phenology.cwl/bands/RSLOPE",
                                "#summarise_phenology.cwl/bands/SPROD",
                                "#summarise_phenology.cwl/bands/TPROD",
                                "#summarise_phenology.cwl/bands/QFLAG"
                            ]
                        }
                    },
                    "label": "Bands",
                    "doc": "Bands of interest for the calculations. - Start of season date (SOSD) - date when the vegetation growing season starts, when the PPI value reaches 25% of the season amplitude during the green-up period. - End of season date (EOSD) - the date when the vegetation growing season ends in the time profile of the PPI. Occurs when the PPI value reaches 15% of the season ampltitude during the green-down period. - Start of season value (SOSV) - the value of the PPI at the start of the vegetation growing season - End of season value (EOSV) - the value of the PPI at the end of the vegetation growing season - Season maximum value (MAXV) - the maximum (peak) value that the PPI reaches during the vegetation growing season - Season maximum date (MAXD) - date in the vegetation growing season where the mximum PPI is reached - Season minimum value (MINV) - average PPI of minima of left adn right sides of each season - Season amplitude (AMPL) - difference between the maximum and minimum PPI values reached during the season - Season length (LENGTH) - number of days between the start and end dates of the vegetation growing season - Slope of the green-up period (LSLOPE) - the rate of change in the values of PPI at the day when the vegetation growing season starts - Slope of the green-down period (RSLOPE) - the rate of change in tha values of PPO at the dat when the vegetatio growing season ends - Seasonal productivity (SPROD) - growing season integral computed as sum of all daily PPI values between the dates of the season start and end, minus their base level. - Total productivity (TPROD) - the growing season integral computed as sum of all daily PPI values between the dates of the season start and end - Quality flag (QFLAG) - quality indicator assisting users with the screening of clouds, shadows from clouds and topography, other dark areas, snow and water surfaces in their analysis of the PPI dataset\n",
                    "default": [
                        "LENGTH",
                        "AMPL"
                    ],
                    "id": "#summarise_phenology.cwl/bands"
                },
                {
                    "label": "Bounding box and CRS",
                    "doc": "Object containing the chosen bounding box and CRS.",
                    "type": {
                        "type": "record",
                        "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS",
                        "fields": [
                            {
                                "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/country",
                                "type": {
                                    "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/country/countryDefinition/bboxWGS84",
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
                                "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS",
                                "type": {
                                    "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/region",
                                "type": {
                                    "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#summarise_phenology.cwl/bbox_crs/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#summarise_phenology.cwl/bbox_crs"
                },
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#summarise_phenology.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "End year",
                    "doc": "End date for phenology time series.",
                    "default": "2024",
                    "id": "#summarise_phenology.cwl/end_year"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#summarise_phenology.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#summarise_phenology.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#summarise_phenology.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#summarise_phenology.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "phenology/summarise_phenology.py",
                    "id": "#summarise_phenology.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#summarise_phenology.cwl/scripts_root"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#summarise_phenology.cwl/season/SEASON1",
                            "#summarise_phenology.cwl/season/SEASON2"
                        ]
                    },
                    "label": "Season of interest",
                    "doc": "Season for which to run phenology analyses. Season 1 is the first growing season (spring and early summer) and season 2 is the second growing season (late summer and fall).\n",
                    "default": "SEASON1",
                    "id": "#summarise_phenology.cwl/season"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Spatial resolution",
                    "doc": "Spatial resolution, in meters, of the raster for plotting, leave blank to have the original spatial resolution of the layer (10m x 10m).",
                    "default": 1000,
                    "id": "#summarise_phenology.cwl/spatial_resolution"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Start year",
                    "doc": "Start date for phenology time series.",
                    "default": "2017",
                    "id": "#summarise_phenology.cwl/start_year"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Polygon of study area",
                    "doc": "Polygon of the study area of interest. Leave blank if you do not want to crop by a polygon and want to use the bounding box instead.",
                    "id": "#summarise_phenology.cwl/study_area_polygon"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#summarise_phenology.cwl/logs"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "Phenology rasters",
                    "doc": "Rasters of phenology layers, with one raster per year in the input time range. Will either be the raw raster layers or resampled to the spatial resolution input by the user.\n",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"rasters\");\n  if (value === null) return null;\n  var items = Array.isArray(value) ? value : [value];\n  return items.map(function (value) {\n    if (value === null) return null;\n    return { class: \"File\", location: \"file://\" + value };\n  });\n}\n"
                    },
                    "id": "#summarise_phenology.cwl/rasters_out"
                },
                {
                    "type": "File",
                    "label": "Zonal statistics",
                    "doc": "Summarised values over the polygon of interest (mean, minimum, or maximum) for each year for each band of interest",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"timeseries\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#summarise_phenology.cwl/timeseries_out"
                }
            ],
            "id": "#summarise_phenology.cwl"
        },
        {
            "class": "Workflow",
            "label": "Plant phenology index pipeline (Europe only)",
            "doc": [
                "Description:\n## Introduction\nPhenology is one of the species trait EBVs. It describes presence, absence, abundance or duration of seasonal activities of organisms. This pipeline uses the openEO python package to pull phenology layers from the copernicus data space ecosystem phenology layer. The raster has values for the Plant Phenology Index (PPI), which is a vegetation index that helps estimate vegetation health and photosyntehtic activity throughout the growing season. It is more directly related to plant phenology compared to other vegetation indices like NDVI, and does not saturate in high biomass conditions. It is computed with near infrared reflectance, which is strongly reflected by healthy vegetation. \nYou can read more about the phenology layers [here](https://land.copernicus.eu/en/dataset-catalog). The script pulls the yearly phenology layers using openEO and resamples them to the spatial resolution of choice, calculates summary statistics over a country or region of interest, and subtracts the rasters to look at change over time.\n## Context\nThis pipeline can be used to look at the Phenology EBV. It can also serve as inputs for subsequent pipelines,  such as species distribution models.\n## Pipeline limitations \n* Phenology layers are only available for countries in Europe.\n* The pipeline uses a very fine resolution, so it takes a long time to run on for large areas.\n## Before you start\nThe pipeline requires an API key for the Copernicus Data Space Ecosystem. To acquire an API key, visit the CDSE [website](https://dataspace.copernicus.eu/analyse/openeo).\n",
                "Lifecycle tag: In development.",
                "Authors:\nJory Griffith (Pipeline Development, jory.griffith@gmail.com, https://orcid.org/0000-0001-6020-6690)\nLaetitia Tremblay (Pipeline testing, debugging, and documentation, laetitia.tremblay@mcgill.ca, https://www.linkedin.com/in/laetitia-tremblay-b0619b273/)\n",
                "External link: https://land.copernicus.eu/en/products/vegetation"
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
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#main/data>load_polygons.yml@69|polygon_type/Country or region",
                            "#main/data>load_polygons.yml@69|polygon_type/Polygon of bounding box"
                        ]
                    },
                    "label": "Polygon type",
                    "doc": "Type of polygon to load. Country or region polygons, World database of Protected Areas (WDPA), Exclusive Economic Zones (EEZs), or a custom polygon of a bounding box.",
                    "default": "Country or region",
                    "id": "#main/data>load_polygons.yml@69|polygon_type"
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
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#main/phenology>summarise_phenology.yml@37|aggregate_function/mean",
                            "#main/phenology>summarise_phenology.yml@37|aggregate_function/min",
                            "#main/phenology>summarise_phenology.yml@37|aggregate_function/max"
                        ]
                    },
                    "label": "Aggregate function",
                    "doc": "Method used to aggregate items when layers combining over time. Will be ignored if not aggregating.\n",
                    "default": "mean",
                    "id": "#main/phenology>summarise_phenology.yml@37|aggregate_function"
                },
                {
                    "type": {
                        "type": "array",
                        "items": {
                            "type": "enum",
                            "symbols": [
                                "#main/phenology>summarise_phenology.yml@37|bands/SOSD",
                                "#main/phenology>summarise_phenology.yml@37|bands/EOSD",
                                "#main/phenology>summarise_phenology.yml@37|bands/SOSV",
                                "#main/phenology>summarise_phenology.yml@37|bands/EOSV",
                                "#main/phenology>summarise_phenology.yml@37|bands/MAXD",
                                "#main/phenology>summarise_phenology.yml@37|bands/MAXV",
                                "#main/phenology>summarise_phenology.yml@37|bands/MINV",
                                "#main/phenology>summarise_phenology.yml@37|bands/AMPL",
                                "#main/phenology>summarise_phenology.yml@37|bands/LENGTH",
                                "#main/phenology>summarise_phenology.yml@37|bands/LSLOPE",
                                "#main/phenology>summarise_phenology.yml@37|bands/RSLOPE",
                                "#main/phenology>summarise_phenology.yml@37|bands/SPROD",
                                "#main/phenology>summarise_phenology.yml@37|bands/TPROD",
                                "#main/phenology>summarise_phenology.yml@37|bands/QFLAG"
                            ]
                        }
                    },
                    "label": "Bands",
                    "doc": "Bands of interest for the calculations.  - SOSD (Start of season date) - date when the vegetation growing season starts, when the PPI value reaches 25% of the season amplitude during the green-up period. - EOSD (End of season date) - the date when the vegetation growing season ends in the time profile of the PPI. Occurs when the PPI value reaches 15% of the season amplitude during the green-down period. - SOSV (Start of season value) - the value of the PPI at the start of the vegetation growing season - EOSV (End of season value) - the value of the PPI at the end of the vegetation growing season - MAXV (Season maximum value) - the maximum (peak) value that the PPI reaches during the vegetation growing season - MAXD (Season maximum date) - date in the vegetation growing season where the maximum PPI is reached - MINV (Season minimum value) - average PPI of minima of left and right sides of each season - AMPL (Season amplitude) - difference between the maximum and minimum PPI values reached during the season - LENGTH (Season length) - number of days between the start and end dates of the vegetation growing season - LSLOPE (Slope of the green-up period) - the rate of change in the values of PPI at the day when the vegetation growing season starts - RSLOPE (Slope of the green-down period) - the rate of change in the values of PPO at the date when the vegetation growing season ends - SPROD (Seasonal productivity) - growing season integral computed as sum of all daily PPI values between the dates of the season start and end, minus their base level. - TPROD (Total productivity) - the growing season integral computed as sum of all daily PPI values between the dates of the season start and end - QFLAG (Quality flag) - quality indicator assisting users with the screening of clouds, shadows from clouds and topography, other dark areas, snow and water surfaces in their analysis of the PPI dataset\n",
                    "default": [
                        "LENGTH",
                        "AMPL"
                    ],
                    "id": "#main/phenology>summarise_phenology.yml@37|bands"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#main/phenology>summarise_phenology.yml@37|season/SEASON1",
                            "#main/phenology>summarise_phenology.yml@37|season/SEASON2"
                        ]
                    },
                    "label": "Season of interest",
                    "doc": "Season for which to run phenology analyses. Season 1 is the first growing season (spring and early summer) and season 2 is the second growing season (late summer and fall).\n",
                    "default": "SEASON1",
                    "id": "#main/phenology>summarise_phenology.yml@37|season"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Spatial resolution",
                    "doc": "Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). Leave blank to use the original spatial resolution of the layers. If left blank, CRS must be EPSG:4326.\n",
                    "default": 0,
                    "id": "#main/phenology>summarise_phenology.yml@37|spatial_resolution"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Start year",
                    "doc": "Start date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if using all available dates.",
                    "default": "2017",
                    "id": "#main/pipeline@44"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "End year",
                    "doc": "End date for time series layers. Can be in the format YYYY or YYYY-MM-DD. Leave blank if using all available dates.",
                    "default": "2024",
                    "id": "#main/pipeline@45"
                },
                {
                    "label": "Bounding box and CRS",
                    "doc": "Select a country/region and a CRS to obtain the associated bounding box.",
                    "type": {
                        "type": "record",
                        "name": "#main/pipeline@68/bboxCRS",
                        "fields": [
                            {
                                "name": "#main/pipeline@68/bboxCRS/country",
                                "type": {
                                    "name": "#main/pipeline@68/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/country/countryDefinition/bboxWGS84",
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
                                "name": "#main/pipeline@68/bboxCRS/CRS",
                                "type": {
                                    "name": "#main/pipeline@68/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#main/pipeline@68/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#main/pipeline@68/bboxCRS/region",
                                "type": {
                                    "name": "#main/pipeline@68/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@68/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#main/pipeline@68"
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
                    "run": "#load_polygons.cwl",
                    "in": [
                        {
                            "default": 0.0,
                            "id": "#main/data>load_polygons.yml@69/buffer"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>load_polygons.yml@69/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@68",
                            "id": "#main/data>load_polygons.yml@69/country_region_bbox"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)",
                            "id": "#main/data>load_polygons.yml@69/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>load_polygons.yml@69/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>load_polygons.yml@69/environment"
                        },
                        {
                            "source": "#main/data>load_polygons.yml@69|polygon_type",
                            "id": "#main/data>load_polygons.yml@69/polygon_type"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/69' } : null)",
                            "id": "#main/data>load_polygons.yml@69/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>load_polygons.yml@69/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/data>load_polygons.yml@69/polygon_out",
                        "#main/data>load_polygons.yml@69/bbox_crs_out"
                    ],
                    "id": "#main/data>load_polygons.yml@69"
                },
                {
                    "run": "#phenology_difference.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/phenology>phenology_difference.yml@48/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@45",
                            "id": "#main/phenology>phenology_difference.yml@48/end_year"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/phenology>phenology_difference.yml@48/environment"
                        },
                        {
                            "source": "#main/phenology>summarise_phenology.yml@37/rasters_out",
                            "id": "#main/phenology>phenology_difference.yml@48/rasters"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/phenology__phenology_difference/48' } : null)",
                            "id": "#main/phenology>phenology_difference.yml@48/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/phenology>phenology_difference.yml@48/scripts_root"
                        },
                        {
                            "source": "#main/pipeline@44",
                            "id": "#main/phenology>phenology_difference.yml@48/start_year"
                        },
                        {
                            "source": "#main/phenology>summarise_phenology.yml@37/timeseries_out",
                            "id": "#main/phenology>phenology_difference.yml@48/timeseries"
                        }
                    ],
                    "out": [
                        "#main/phenology>phenology_difference.yml@48/phenology_change_out",
                        "#main/phenology>phenology_difference.yml@48/phenology_change_plot_out"
                    ],
                    "id": "#main/phenology>phenology_difference.yml@48"
                },
                {
                    "run": "#summarise_phenology.cwl",
                    "in": [
                        {
                            "source": "#main/phenology>summarise_phenology.yml@37|aggregate_function",
                            "id": "#main/phenology>summarise_phenology.yml@37/aggregate_function"
                        },
                        {
                            "source": "#main/phenology>summarise_phenology.yml@37|bands",
                            "id": "#main/phenology>summarise_phenology.yml@37/bands"
                        },
                        {
                            "source": "#main/pipeline@68",
                            "id": "#main/phenology>summarise_phenology.yml@37/bbox_crs"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/phenology>summarise_phenology.yml@37/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@45",
                            "id": "#main/phenology>summarise_phenology.yml@37/end_year"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/phenology__summarise_phenology' } : null)",
                            "id": "#main/phenology>summarise_phenology.yml@37/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/phenology>summarise_phenology.yml@37/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/phenology>summarise_phenology.yml@37/environment"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/phenology__summarise_phenology/37' } : null)",
                            "id": "#main/phenology>summarise_phenology.yml@37/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/phenology>summarise_phenology.yml@37/scripts_root"
                        },
                        {
                            "source": "#main/phenology>summarise_phenology.yml@37|season",
                            "id": "#main/phenology>summarise_phenology.yml@37/season"
                        },
                        {
                            "source": "#main/phenology>summarise_phenology.yml@37|spatial_resolution",
                            "id": "#main/phenology>summarise_phenology.yml@37/spatial_resolution"
                        },
                        {
                            "source": "#main/pipeline@44",
                            "id": "#main/phenology>summarise_phenology.yml@37/start_year"
                        },
                        {
                            "source": "#main/data>load_polygons.yml@69/polygon_out",
                            "id": "#main/phenology>summarise_phenology.yml@37/study_area_polygon"
                        }
                    ],
                    "out": [
                        "#main/phenology>summarise_phenology.yml@37/rasters_out",
                        "#main/phenology>summarise_phenology.yml@37/timeseries_out"
                    ],
                    "id": "#main/phenology>summarise_phenology.yml@37"
                },
                {
                    "when": "$(inputs.envFolderWrite != null)",
                    "run": {
                        "class": "CommandLineTool",
                        "requirements": [
                            {
                                "dockerPull": "ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:sha-259f5b2",
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
                            "echo \"Exporting all environments\"\nmkdir -p \"$OUTPUT_LOCATION\" \"$CONDA_PKGS_DIRS\" /conda-env-yml/envs\n\nfunction getPackedEnv {\n  condaEnvName=$1\n  condaEnvYml=$2\n  # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context\n  dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName\n  mkdir -p \"$dedicatedEnvFolder\"\n  \n  echo \"Exporting $condaEnvName...\"\n  source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh \"$OUTPUT_LOCATION\" \"$condaEnvName\" \\\n    \"$condaEnvYml\" \"$dedicatedEnvFolder\" \"$(inputs.condaPackURL)\" --noActivate\n  source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh \"$condaEnvName\" \"$dedicatedEnvFolder\"\n  echo \"Done.\"\n}\nexport -f getPackedEnv\n\nbash -c 'getPackedEnv \"phenology__summarise_phenology\" \"channels: [conda-forge]\ndependencies: [openeo, pandas, geopandas, shapely]\nname: phenology__summarise_phenology\n\"'\n\nbash -c 'getPackedEnv \"data__load_polygons\" \"channels: [conda-forge]\ndependencies: [r-rjson, r-dbplyr=2.5.2, r-dplyr=1.2.1, r-duckdb=1.4.4, r-fs=2.1.0,\n  r-arrow=24.0.0, r-nanoarrow=0.8.0, r-geoarrow=0.4.2, r-sf=1.1-0, r-stringi=1.8.7,\n  r-stringr=1.6.0, r-tidyr=1.3.2, r-uuid=1.2_2, r-remotes=2.5.0]\nname: data__load_polygons\n\"'\n"
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
                    "label": "Polygon",
                    "doc": "Polygons of the country, WDPA, EEZs for the country or region of interest",
                    "outputSource": "#main/data>load_polygons.yml@69/polygon_out",
                    "id": "#main/data>load_polygons.yml@69|polygon_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "Change in phenology metrics",
                    "doc": "Raster plot of change in phenology from the start year to the end year. The end year is subtracted from the start year, so larger values indicate a greater decrease in the given value over time.\n",
                    "outputSource": "#main/phenology>phenology_difference.yml@48/phenology_change_out",
                    "id": "#main/phenology>phenology_difference.yml@48|phenology_change_out"
                },
                {
                    "type": "File",
                    "label": "Plot of phenology change",
                    "doc": "Plot of the summarised phenology values over time for the bands of interest",
                    "outputSource": "#main/phenology>phenology_difference.yml@48/phenology_change_plot_out",
                    "id": "#main/phenology>phenology_difference.yml@48|phenology_change_plot_out"
                },
                {
                    "type": {
                        "type": "array",
                        "items": "File"
                    },
                    "label": "Phenology rasters",
                    "doc": "Rasters of phenology layers, with one raster per year in the input time range. Will either be the raw raster layers or resampled to the spatial resolution and CRS input by the user.\n",
                    "outputSource": "#main/phenology>summarise_phenology.yml@37/rasters_out",
                    "id": "#main/phenology>summarise_phenology.yml@37|rasters_out"
                },
                {
                    "type": "File",
                    "label": "Zonal statistics",
                    "doc": "Summarised values over the polygon of interest (mean, minimum, or maximum) for each year for each band of interest",
                    "outputSource": "#main/phenology>summarise_phenology.yml@37/timeseries_out",
                    "id": "#main/phenology>summarise_phenology.yml@37|timeseries_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
