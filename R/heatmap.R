# Source https://github.com/Leaflet/Leaflet.heat
heatmapDependency <- function() {
  list(
    html_dep_prod("lfx-heat", "0.1.0", has_binding = TRUE)
  )
}

#' Add a heatmap
#' @param intensity intensity of the heat. A vector of numeric values or a formula.
#' @param minOpacity minimum opacity at which the heat will start
#' @param max  maximum point intensity. The default is \code{1.0}
#' @param radius radius of each "point" of the heatmap.  The default is
#'          \code{25}.
#' @param blur amount of blur to apply.  The default is \code{15}.
#'          \code{blur=1} means no blur.
#' @param gradient palette name from \code{RColorBrewer} or an array of
#'          of colors to be provided to \code{\link[leaflet]{colorNumeric}}, or
#'          a color mapping function returned from \code{colorNumeric}
#' @param cellSize  the cell size in the grid. Points which are closer
#'          than this may be merged. Defaults to `radius / 2`.s
#'          Set to `1` to do almost no merging.
#' @inheritParams leaflet::addCircleMarkers
#' @rdname heatmap
#' @export
#' @examples
#' leaflet(quakes) %>%
#'   addProviderTiles(providers$CartoDB.DarkMatter) %>%
#'   setView(178, -20, 5) %>%
#'   addHeatmap(
#'     lng = ~long, lat = ~lat, intensity = ~mag,
#'     blur = 20, max = 0.05, radius = 15
#'   )
#'
#' ## for more examples see
#' # browseURL(system.file("examples/heatmaps.R", package = "leaflet.extras"))
addHeatmap <- function(
   map,
   shared,                                  
   lng = NULL, lat = NULL, intensity = NULL,
   layerId = NULL, group = NULL,
    minOpacity = 0.05,
    max = 1.0, radius = 25,
    blur = 15, gradient = NULL, cellSize = NULL,
    data = leaflet::getMapData(map)) {
  map$dependencies <- c(
    map$dependencies,
    heatmapDependency(),
    crosstalk::crosstalkLibs()            
  )

  # convert gradient to expected format from leaflet
  if (!is.null(gradient)) {
    if (!is.function(gradient)) {
      gradient <- colorNumeric(gradient, 0:1, alpha = TRUE)
    }
    gradient <- as.list(gradient(0:20 / 20))
    names(gradient) <- as.character(0:20 / 20)
  }

 # if `shared` is a SharedData, pull its selected data frame;
  # otherwise assume `shared` is your data frame:
  df <- if (inherits(shared, "SharedData")) shared$data(withSelection = TRUE) else shared
  pts <- leaflet::derivePoints(
    df, lng, lat, missing(lng), missing(lat), "addHeatmap"
  )

  if (is.null(intensity)) {
    points <- cbind(pts$lat, pts$lng)
  } else {
    if (inherits(intensity, "formula")) {
      intensity <- eval(intensity[[2]], data, environment(intensity))
    }
    points <- cbind(pts$lat, pts$lng, intensity)
  }

  # Build the rawData list of key/lat/lng/weight for JS filtering:
  rawData <- df %>%
    dplyr::transmute(
      key    = as.character(.key),
      lat    = !!rlang::enquo(lat),
      lng    = !!rlang::enquo(lng),
      weight = if (is.null(intensity)) NA_real_ else !!rlang::enquo(intensity)
    ) %>% purrr::transpose()

  leaflet::invokeMethod(
    map,                  # leaflet proxy
    df,                   # data context
    "addHeatmap",         # JS method
    points,               # [lat, lng, intensity] matrix
    layerId,              # Leaflet layerId
    group,                # Leaflet group
    rawData,              # NEW: unfiltered rows
    shared$groupName(),   # NEW: Crosstalk group name
    leaflet::filterNULL(list(
      minOpacity = minOpacity,
      max        = max,
      radius     = radius,
      blur       = blur,
      gradient   = gradient,
      cellSize   = cellSize
    ))
  ) %>% leaflet::expandLimits(pts$lat, pts$lng)
}

#' Adds a heatmap with data from a GeoJSON/TopoJSON file/url
#' @param geojson The geojson or topojson url or contents as string.
#' @param intensityProperty The property to use for determining the intensity at a point.
#' Can be a "string" or a JS function, or NULL.
#' @rdname heatmap
#' @export
addGeoJSONHeatmap <- function(
    map, geojson, layerId = NULL, group = NULL,
    intensityProperty = NULL,
    minOpacity = 0.05,
    max = 1.0, radius = 25,
    blur = 15, gradient = NULL, cellSize = NULL) {
  map$dependencies <- c(map$dependencies, omnivoreDependencies())
  map$dependencies <- c(map$dependencies, heatmapDependency())

  leaflet::invokeMethod(
    map, leaflet::getMapData(map),
    "addGeoJSONHeatmap", geojson, intensityProperty,
    layerId, group,
    leaflet::filterNULL(list(
      minOpacity = minOpacity,
      max = max,
      radius = radius,
      blur = blur,
      gradient = gradient,
      cellSize = cellSize
    ))
  )
}

#' Adds a heatmap with data from a KML file/url
#' @param kml The KML url or contents as string.
#' @rdname heatmap
#' @export
#' @examples
#' kml <- readr::read_file(
#'   system.file("examples/data/kml/crimes.kml.zip", package = "leaflet.extras")
#' )
#'
#' leaflet() %>%
#'   setView(-77.0369, 38.9072, 12) %>%
#'   addProviderTiles(providers$CartoDB.Positron) %>%
#'   addKMLHeatmap(kml, radius = 7) %>%
#'   addKML(
#'     kml,
#'     markerType = "circleMarker",
#'     stroke = FALSE, fillColor = "black", fillOpacity = 1,
#'     markerOptions = markerOptions(radius = 1)
#'   )
#'
#' ## for more examples see
#' # browseURL(system.file("examples/KML.R", package = "leaflet.extras"))
addKMLHeatmap <- function(
    map, kml, layerId = NULL, group = NULL,
    intensityProperty = NULL,
    minOpacity = 0.05,
    max = 1.0, radius = 25,
    blur = 15, gradient = NULL, cellSize = NULL) {
  map$dependencies <- c(map$dependencies, omnivoreDependencies())
  map$dependencies <- c(map$dependencies, heatmapDependency())

  leaflet::invokeMethod(
    map, leaflet::getMapData(map),
    "addKMLHeatmap", kml, intensityProperty,
    layerId, group,
    leaflet::filterNULL(list(
      minOpacity = minOpacity,
      max = max,
      radius = radius,
      blur = blur,
      gradient = gradient,
      cellSize = cellSize
    ))
  )
}

#' Adds a heatmap with data from a CSV file/url
#' @param csv The CSV url or contents as string.
#' @param csvParserOptions options for parsing the CSV.
#' Use \code{\link{csvParserOptions}}() to supply csv parser options.
#' @rdname heatmap
#' @export
addCSVHeatmap <- function(
    map, csv, csvParserOptions, layerId = NULL, group = NULL,
    intensityProperty = NULL,
    minOpacity = 0.05,
    max = 1.0, radius = 25,
    blur = 15, gradient = NULL, cellSize = NULL) {
  map$dependencies <- c(map$dependencies, omnivoreDependencies())
  map$dependencies <- c(map$dependencies, heatmapDependency())

  leaflet::invokeMethod(
    map, leaflet::getMapData(map),
    "addCSVHeatmap", csv, intensityProperty,
    layerId, group,
    leaflet::filterNULL(list(
      minOpacity = minOpacity,
      max = max,
      radius = radius,
      blur = blur,
      gradient = gradient,
      cellSize = cellSize
    )),
    csvParserOptions
  )
}

#' Adds a heatmap with data from a GPX file/url
#' @param gpx The GPX url or contents as string.
#' @rdname heatmap
#' @export
addGPXHeatmap <- function(
    map, gpx, layerId = NULL, group = NULL,
    intensityProperty = NULL,
    minOpacity = 0.05,
    max = 1.0, radius = 25,
    blur = 15, gradient = NULL, cellSize = NULL) {
  map$dependencies <- c(map$dependencies, omnivoreDependencies())
  map$dependencies <- c(map$dependencies, heatmapDependency())

  leaflet::invokeMethod(
    map, leaflet::getMapData(map),
    "addGPXHeatmap", gpx, intensityProperty,
    layerId, group,
    leaflet::filterNULL(list(
      minOpacity = minOpacity,
      max = max,
      radius = radius,
      blur = blur,
      gradient = gradient,
      cellSize = cellSize
    ))
  )
}


#' removes the heatmap
#' @rdname heatmap
#' @export
removeHeatmap <- function(map, layerId) {
  leaflet::invokeMethod(map, leaflet::getMapData(map), "removeHeatmap", layerId)
}

#' clears the heatmap
#' @rdname heatmap
#' @export
clearHeatmap <- function(map) {
  leaflet::invokeMethod(map, NULL, "clearHeatmap")
}
