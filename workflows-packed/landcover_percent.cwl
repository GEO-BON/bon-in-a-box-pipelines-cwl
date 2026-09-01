{
    "$graph": [
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
            "id": "#loadFromStac.cwl",
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
            "label": "Percentage cover of raster categories",
            "doc": [
                "Description:\nThis script calculates the proportion of a polygon or bounding box that are covered by categories in a raster layer.\nThis script only works with categorical rasters (e.g. landcover)\n",
                "Authors:\nJory Griffith (jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)\n",
                "References:\nBastion 2023\nhttps://doi.org/10.32614/CRAN.package.exactextractr\n"
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
                "log=$OUTPUT_LOCATION/logs.txt\nrm -f $log\nmkdir -p /conda-env-yml/pkgs /conda-env-yml/envs\n\ncat > \"$OUTPUT_LOCATION/input.json\" <<'JSON'\n${\n  return JSON.stringify({\n    rasters: (inputs.rasters || []).map(function(file) { return file.path; }),\n    study_area_polygon: inputs.study_area_polygon ? inputs.study_area_polygon.path : null,\n  }, null, 2);\n}\nJSON\necho \"Running in $OUTPUT_LOCATION\" | tee -a $log\necho \"Inputs:\" | tee -a $log\ncat $OUTPUT_LOCATION/input.json | tee -a $log\n\nsource $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION \"zonal_statistics__percentage_cover_classes\" \\\n\"channels: [conda-forge, r]\ndependencies: [r-rjson, r-terra, r-dplyr, r-sf, r-exactextractr]\nname: zonal_statistics__percentage_cover_classes\n\" /conda-envs $(inputs.condaPackURL) >> \"$log\" 2>&1\n\nRscript \\\n  $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \\\n  $OUTPUT_LOCATION \\\n  $SCRIPT_LOCATION/$(inputs.scriptPath) \\\n  2>&1 | tee -a $log\nscriptExitCode=\\${PIPESTATUS[0]}\necho \"Script exited with code $scriptExitCode\" | tee -a $log\n\nif [[ \"$OUTPUT_LOCATION\" != \"$(runtime.outdir)\" ]]; then\n  echo \"Copying results from run folder to CWL output directory\" | tee -a $log\n  cp -a \"$OUTPUT_LOCATION\"/. \"$(runtime.outdir)\"/\nfi\n\nsource $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh zonal_statistics__percentage_cover_classes /conda-envs >> \"$log\" 2>&1\n\nexit \"$scriptExitCode\"\n"
            ],
            "inputs": [
                {
                    "type": "string",
                    "doc": "Base URL to check for conda-pack environments.",
                    "default": "https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/",
                    "id": "#percentage_cover_classes.cwl/condaPackURL"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Folder for conda-pack to export environments. This avoids downloading/resolving the same environment multiple times.",
                    "id": "#percentage_cover_classes.cwl/envFolder"
                },
                {
                    "type": "boolean",
                    "doc": "Whether the envFolder should be writable. If false, the folder will be mounted read-only. In that case, the conda environment needs to be present as an unpacked conda-pack beforehand otherwise the script can't run. envFolderWritable must be false when running in a workflow, but can be true when ran as an individual tool.",
                    "default": true,
                    "id": "#percentage_cover_classes.cwl/envFolderWritable"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "doc": "Optional. BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.",
                    "id": "#percentage_cover_classes.cwl/environment"
                },
                {
                    "type": [
                        "null",
                        {
                            "type": "array",
                            "items": "File"
                        }
                    ],
                    "label": "Rasters",
                    "doc": "Rasters to calculate zonal statistics (can be one or more).",
                    "id": "#percentage_cover_classes.cwl/rasters"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script. If left blank, a temporary folder will be used and discarded after the run.",
                    "id": "#percentage_cover_classes.cwl/runFolder"
                },
                {
                    "type": "string",
                    "doc": "Path to the script, relative to scripts root.",
                    "default": "zonal_statistics/percentage_cover_classes.R",
                    "id": "#percentage_cover_classes.cwl/scriptPath"
                },
                {
                    "type": [
                        "null",
                        "Directory"
                    ],
                    "doc": "Root folder for scripts. Use this to override the image's scripts while debugging.",
                    "id": "#percentage_cover_classes.cwl/scripts_root"
                },
                {
                    "type": [
                        "null",
                        "File"
                    ],
                    "label": "Polygon of study area",
                    "doc": "Polygon of the study area of interest",
                    "id": "#percentage_cover_classes.cwl/study_area_polygon"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "Percentage of classes",
                    "doc": "Percentage of each categorical class in a raster layer over a polygon or bounding box of interest",
                    "outputBinding": {
                        "glob": "output.json",
                        "loadContents": true,
                        "outputEval": "${\n  var value = extractOutput(self, \"class_percentage\");\n  if (value === null) return null;\n  return { class: \"File\", location: \"file://\" + value };\n}\n"
                    },
                    "id": "#percentage_cover_classes.cwl/class_percentage_out"
                },
                {
                    "type": "File",
                    "outputBinding": {
                        "glob": "logs.txt"
                    },
                    "id": "#percentage_cover_classes.cwl/logs"
                }
            ],
            "id": "#percentage_cover_classes.cwl"
        },
        {
            "class": "Workflow",
            "label": "Percentage of raster classes",
            "doc": [
                "Description:\nCalculate percentage of classes over a bounding box or polygon of interest in categorical rasters.\n",
                "Authors:\nJory Griffith (Pipeline development, jory.griffith@mcgill.ca, https://orcid.org/0000-0001-6020-6690)\n",
                "References:\nBastion 2023\nnull\n"
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
                            "#main/data>loadFromStac.yml@42|aggregation/first",
                            "#main/data>loadFromStac.yml@42|aggregation/min",
                            "#main/data>loadFromStac.yml@42|aggregation/max",
                            "#main/data>loadFromStac.yml@42|aggregation/mean",
                            "#main/data>loadFromStac.yml@42|aggregation/median"
                        ]
                    },
                    "label": "Aggregation method",
                    "doc": "Method used to aggregate items when layers combining over time.",
                    "default": "first",
                    "id": "#main/data>loadFromStac.yml@42|aggregation"
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
                    "doc": "Vector of strings. To pull specific collection items, input the collection name followed by '|' followed by item id (e.g. \"chelsa-clim|bio1\"). To extract a whole collection, type the collection name only (e.g. \"chelsa-clim\"). To pull collection items by date, write the collection name and provide a start date, end date, and temporal resolution.\nLayers used in this pipeline must be categorical variables (e.g. landcover). \n",
                    "default": [
                        "esacci-lc|esacci-lc-2020"
                    ],
                    "id": "#main/data>loadFromStac.yml@42|collections_items"
                },
                {
                    "type": {
                        "type": "enum",
                        "symbols": [
                            "#main/data>loadFromStac.yml@42|resampling/near",
                            "#main/data>loadFromStac.yml@42|resampling/bilinear",
                            "#main/data>loadFromStac.yml@42|resampling/average",
                            "#main/data>loadFromStac.yml@42|resampling/mode",
                            "#main/data>loadFromStac.yml@42|resampling/cubic",
                            "#main/data>loadFromStac.yml@42|resampling/cubicspline",
                            "#main/data>loadFromStac.yml@42|resampling/lanczos",
                            "#main/data>loadFromStac.yml@42|resampling/rms",
                            "#main/data>loadFromStac.yml@42|resampling/min",
                            "#main/data>loadFromStac.yml@42|resampling/max",
                            "#main/data>loadFromStac.yml@42|resampling/sum",
                            "#main/data>loadFromStac.yml@42|resampling/med",
                            "#main/data>loadFromStac.yml@42|resampling/q1",
                            "#main/data>loadFromStac.yml@42|resampling/q3"
                        ]
                    },
                    "label": "Resampling method",
                    "doc": "Resampling method used when rescaling and/or reprojecting the raster layers. See [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) for description.",
                    "default": "near",
                    "id": "#main/data>loadFromStac.yml@42|resampling"
                },
                {
                    "type": [
                        "null",
                        "float"
                    ],
                    "label": "Spatial resolution (optional)",
                    "doc": "Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). \nIf this is left blank it will use the native resolution of the rasters. \nIf the spatial resolution is coarser than the native resolution of the rasters, the layers will be resampled with the resampling method chosen below.\n",
                    "default": 0.008833,
                    "id": "#main/data>loadFromStac.yml@42|spatial_res"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "STAC URL",
                    "doc": "URL of the STAC catalog.",
                    "default": "https://stac.geobon.org/",
                    "id": "#main/data>loadFromStac.yml@42|stac_url"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Start date",
                    "doc": "Start date for time series layers in format YYYY-MM-DD. Leave blank if extracting items by name.",
                    "default": "2020-01-01",
                    "id": "#main/data>loadFromStac.yml@42|t0"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "End date",
                    "doc": "End date for time series layers in format YYYY-MM-DD. Leave blank if extracting items by name.",
                    "default": "2020-12-31",
                    "id": "#main/data>loadFromStac.yml@42|t1"
                },
                {
                    "type": [
                        "null",
                        "string"
                    ],
                    "label": "Temporal resolution",
                    "doc": "Temporal resolution to use when querying STAC items by date, in the format (\"P\", time interval, and time unit, e.g. \"P1Y\" is yearly, \"P1M\" is montly, and \"P1D\" is daily). Leave blank if not querying by date. If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below.",
                    "default": "P1Y",
                    "id": "#main/data>loadFromStac.yml@42|temporal_res"
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
                    "label": "Bounding box and CRS",
                    "doc": "Select a country/region and a CRS to obtain the associated bounding box.",
                    "type": {
                        "type": "record",
                        "name": "#main/pipeline@43/bboxCRS",
                        "fields": [
                            {
                                "name": "#main/pipeline@43/bboxCRS/country",
                                "type": {
                                    "name": "#main/pipeline@43/bboxCRS/country/countryDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/country/countryDefinition/englishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/country/countryDefinition/ISO3",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/country/countryDefinition/bboxWGS84",
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
                                "name": "#main/pipeline@43/bboxCRS/CRS",
                                "type": {
                                    "name": "#main/pipeline@43/bboxCRS/CRS/CRSDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/CRS/CRSDefinition/unit",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/CRS/CRSDefinition/code",
                                            "type": [
                                                "null",
                                                "int"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/CRS/CRSDefinition/authority",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/CRS/CRSDefinition/name",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/CRS/CRSDefinition/CRSBboxWGS84",
                                            "type": [
                                                "null",
                                                {
                                                    "type": "array",
                                                    "items": "float"
                                                }
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/CRS/CRSDefinition/proj4Def",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/CRS/CRSDefinition/wktDef",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        }
                                    ]
                                }
                            },
                            {
                                "name": "#main/pipeline@43/bboxCRS/bbox",
                                "type": {
                                    "type": "array",
                                    "items": "float"
                                }
                            },
                            {
                                "name": "#main/pipeline@43/bboxCRS/region",
                                "type": {
                                    "name": "#main/pipeline@43/bboxCRS/region/regionDefinition",
                                    "type": "record",
                                    "fields": [
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/region/regionDefinition/countryEnglishName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/region/regionDefinition/regionID",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/region/regionDefinition/regionName",
                                            "type": [
                                                "null",
                                                "string"
                                            ]
                                        },
                                        {
                                            "name": "#main/pipeline@43/bboxCRS/region/regionDefinition/bboxWGS84",
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
                    "id": "#main/pipeline@43"
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
                    "run": "#loadFromStac.cwl",
                    "in": [
                        {
                            "source": "#main/data>loadFromStac.yml@42|aggregation",
                            "id": "#main/data>loadFromStac.yml@42/aggregation"
                        },
                        {
                            "source": "#main/pipeline@43",
                            "id": "#main/data>loadFromStac.yml@42/bbox_crs"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@42|collections_items",
                            "id": "#main/data>loadFromStac.yml@42/collections_items"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>loadFromStac.yml@42/condaPackURL"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac' } : null)",
                            "id": "#main/data>loadFromStac.yml@42/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>loadFromStac.yml@42/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>loadFromStac.yml@42/environment"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@42|resampling",
                            "id": "#main/data>loadFromStac.yml@42/resampling"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__loadFromStac/42' } : null)",
                            "id": "#main/data>loadFromStac.yml@42/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>loadFromStac.yml@42/scripts_root"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@42|spatial_res",
                            "id": "#main/data>loadFromStac.yml@42/spatial_res"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@42|stac_url",
                            "id": "#main/data>loadFromStac.yml@42/stac_url"
                        },
                        {
                            "source": "#main/data>load_polygons.yml@44/polygon_out",
                            "id": "#main/data>loadFromStac.yml@42/study_area"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@42|t0",
                            "id": "#main/data>loadFromStac.yml@42/t0"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@42|t1",
                            "id": "#main/data>loadFromStac.yml@42/t1"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@42|temporal_res",
                            "id": "#main/data>loadFromStac.yml@42/temporal_res"
                        }
                    ],
                    "out": [
                        "#main/data>loadFromStac.yml@42/rasters_out"
                    ],
                    "id": "#main/data>loadFromStac.yml@42"
                },
                {
                    "run": "#load_polygons.cwl",
                    "in": [
                        {
                            "default": 0.0,
                            "id": "#main/data>load_polygons.yml@44/buffer"
                        },
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/data>load_polygons.yml@44/condaPackURL"
                        },
                        {
                            "source": "#main/pipeline@43",
                            "id": "#main/data>load_polygons.yml@44/country_region_bbox"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons' } : null)",
                            "id": "#main/data>load_polygons.yml@44/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/data>load_polygons.yml@44/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/data>load_polygons.yml@44/environment"
                        },
                        {
                            "default": "Country or region",
                            "id": "#main/data>load_polygons.yml@44/polygon_type"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/data__load_polygons/44' } : null)",
                            "id": "#main/data>load_polygons.yml@44/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/data>load_polygons.yml@44/scripts_root"
                        }
                    ],
                    "out": [
                        "#main/data>load_polygons.yml@44/polygon_out",
                        "#main/data>load_polygons.yml@44/bbox_crs_out"
                    ],
                    "id": "#main/data>load_polygons.yml@44"
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
                            "echo \"Exporting all environments\"\nmkdir -p \"$OUTPUT_LOCATION\" \"$CONDA_PKGS_DIRS\" /conda-env-yml/envs\n\nfunction getPackedEnv {\n  condaEnvName=$1\n  condaEnvYml=$2\n  # We use a dedicated env folder to avoid copying the whole env folder between steps in a k8 context\n  dedicatedEnvFolder=$(inputs.envFolderWrite.path)/$condaEnvName\n  mkdir -p \"$dedicatedEnvFolder\"\n  \n  echo \"Exporting $condaEnvName...\"\n  source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh \"$OUTPUT_LOCATION\" \"$condaEnvName\" \\\n    \"$condaEnvYml\" \"$dedicatedEnvFolder\" \"$(inputs.condaPackURL)\" --noActivate\n  source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh \"$condaEnvName\" \"$dedicatedEnvFolder\"\n  echo \"Done.\"\n}\nexport -f getPackedEnv\n\nbash -c 'getPackedEnv \"zonal_statistics__percentage_cover_classes\" \"channels: [conda-forge, r]\ndependencies: [r-rjson, r-terra, r-dplyr, r-sf, r-exactextractr]\nname: zonal_statistics__percentage_cover_classes\n\"'\n\nbash -c 'getPackedEnv \"data__loadFromStac\" \"channels: [conda-forge, r]\ndependencies: [libgdal, r-lubridate, proj, r-proj, r-gdalcubes=0.7.4, r-rstac, r-dplyr,\n  r-rcurl, r-rjson, r-sf, r-stars, r-terra]\nname: data__loadFromStac\n\"'\n\nbash -c 'getPackedEnv \"data__load_polygons\" \"channels: [conda-forge]\ndependencies: [r-rjson, r-dbplyr=2.5.2, r-dplyr=1.2.1, r-duckdb=1.4.4, r-fs=2.1.0,\n  r-arrow=24.0.0, r-nanoarrow=0.8.0, r-geoarrow=0.4.2, r-sf=1.1-0, r-stringi=1.8.7,\n  r-stringr=1.6.0, r-tidyr=1.3.2, r-uuid=1.2_2, r-remotes=2.5.0]\nname: data__load_polygons\n\"'\n"
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
                    "run": "#percentage_cover_classes.cwl",
                    "in": [
                        {
                            "source": "#main/condaPackURL",
                            "id": "#main/zonal_statistics>percentage_cover_classes.yml@22/condaPackURL"
                        },
                        {
                            "source": "#main/prepareEnvironments/envFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/zonal_statistics__percentage_cover_classes' } : null)",
                            "id": "#main/zonal_statistics>percentage_cover_classes.yml@22/envFolder"
                        },
                        {
                            "default": false,
                            "id": "#main/zonal_statistics>percentage_cover_classes.yml@22/envFolderWritable"
                        },
                        {
                            "source": "#main/environment",
                            "id": "#main/zonal_statistics>percentage_cover_classes.yml@22/environment"
                        },
                        {
                            "source": "#main/data>loadFromStac.yml@42/rasters_out",
                            "id": "#main/zonal_statistics>percentage_cover_classes.yml@22/rasters"
                        },
                        {
                            "source": "#main/runFolder",
                            "valueFrom": "$(self ? { class: 'Directory', location: self.location + '/zonal_statistics__percentage_cover_classes/22' } : null)",
                            "id": "#main/zonal_statistics>percentage_cover_classes.yml@22/runFolder"
                        },
                        {
                            "source": "#main/scripts_root",
                            "id": "#main/zonal_statistics>percentage_cover_classes.yml@22/scripts_root"
                        },
                        {
                            "source": "#main/data>load_polygons.yml@44/polygon_out",
                            "id": "#main/zonal_statistics>percentage_cover_classes.yml@22/study_area_polygon"
                        }
                    ],
                    "out": [
                        "#main/zonal_statistics>percentage_cover_classes.yml@22/class_percentage_out"
                    ],
                    "id": "#main/zonal_statistics>percentage_cover_classes.yml@22"
                }
            ],
            "outputs": [
                {
                    "type": "File",
                    "label": "Polygon",
                    "doc": "Polygons of the country, WDPA, EEZs for the country or region of interest",
                    "outputSource": "#main/data>load_polygons.yml@44/polygon_out",
                    "id": "#main/data>load_polygons.yml@44|polygon_out"
                },
                {
                    "type": "File",
                    "label": "Percentage of classes",
                    "doc": "Percentage of each categorical class in a raster layer over a polygon or bounding box of interest",
                    "outputSource": "#main/zonal_statistics>percentage_cover_classes.yml@22/class_percentage_out",
                    "id": "#main/zonal_statistics>percentage_cover_classes.yml@22|class_percentage_out"
                }
            ],
            "id": "#main"
        }
    ],
    "cwlVersion": "v1.2"
}
