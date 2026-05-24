#' Direct HTTP MCP client for Paperclip
#'
#' mcptools only supports stdio MCP servers (it shells out to `npx mcp-remote`
#' for HTTP ones), and Posit Connect Cloud doesn't have Node available. So we
#' implement just enough of the Streamable HTTP MCP transport in R to list
#' Paperclip's tools and expose each one as an `ellmer::tool()`.

PAPERCLIP_MCP_URL <- "https://paperclip.gxl.ai/mcp"

mcp_request <- function(url, api_key, method, params = NULL, id = 1L,
                       session_id = NULL, notification = FALSE) {
  body <- list(jsonrpc = "2.0", method = method)
  if (!is.null(params)) body$params <- params
  if (!notification) body$id <- id

  req <- httr2::request(url) |>
    httr2::req_headers(
      `X-API-Key` = api_key,
      `Content-Type` = "application/json",
      Accept = "application/json, text/event-stream"
    ) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_error(is_error = function(resp) FALSE)

  if (!is.null(session_id)) {
    req <- httr2::req_headers(req, `Mcp-Session-Id` = session_id)
  }

  resp <- httr2::req_perform(req)
  list(
    status = httr2::resp_status(resp),
    session_id = httr2::resp_header(resp, "Mcp-Session-Id"),
    body = parse_mcp_body(resp)
  )
}

parse_mcp_body <- function(resp) {
  ctype <- httr2::resp_content_type(resp) %||% ""
  if (httr2::resp_status(resp) == 202 || httr2::resp_has_body(resp) == FALSE) {
    return(NULL)
  }
  if (grepl("text/event-stream", ctype, fixed = TRUE)) {
    raw <- httr2::resp_body_string(resp)
    # SSE frames separated by blank lines, each line is `field: value`.
    frames <- strsplit(raw, "\n\n", fixed = TRUE)[[1]]
    for (frame in frames) {
      data_lines <- grep("^data:", strsplit(frame, "\n", fixed = TRUE)[[1]],
                         value = TRUE)
      if (length(data_lines)) {
        payload <- paste(sub("^data: ?", "", data_lines), collapse = "\n")
        return(jsonlite::fromJSON(payload, simplifyVector = FALSE))
      }
    }
    return(NULL)
  }
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

#' Connect to Paperclip MCP and return a list of ellmer tools
#'
#' Each tool advertised by the Paperclip MCP server is wrapped as an
#' `ellmer::tool()` so it can be passed to `chat$set_tools()`.
#'
#' @param api_key Paperclip API key (starts with `gxl_`).
#' @param url MCP endpoint. Defaults to `https://paperclip.gxl.ai/mcp`.
paperclip_tools <- function(api_key, url = PAPERCLIP_MCP_URL) {
  stopifnot(nzchar(api_key))

  init <- mcp_request(url, api_key, "initialize", params = list(
    protocolVersion = "2025-06-18",
    capabilities = list(),
    clientInfo = list(name = "paperclip.shiny", version = "0.1.0")
  ))
  if (init$status >= 400 || is.null(init$body$result)) {
    stop("MCP initialize failed (HTTP ", init$status, "): ",
         init$body$error$message %||% "unknown error")
  }
  session_id <- init$session_id

  # The spec requires sending an `initialized` notification before further calls.
  mcp_request(url, api_key, "notifications/initialized",
              session_id = session_id, notification = TRUE)

  listed <- mcp_request(url, api_key, "tools/list",
                        session_id = session_id, id = 2L)
  tools <- listed$body$result$tools %||% list()
  lapply(tools, function(spec) mcp_tool_to_ellmer(spec, api_key, url, session_id))
}

mcp_tool_to_ellmer <- function(spec, api_key, url, session_id) {
  name <- spec$name
  description <- spec$description %||% name
  schema <- spec$inputSchema %||% list(type = "object", properties = list())

  fn <- function(...) {
    args <- list(...)
    call_id <- as.integer(sample.int(.Machine$integer.max, 1L))
    res <- mcp_request(url, api_key, "tools/call",
                       params = list(name = name, arguments = args),
                       session_id = session_id, id = call_id)
    flatten_mcp_content(res$body$result)
  }

  arg_types <- schema_to_ellmer_args(schema)
  do.call(ellmer::tool, c(
    list(fn, .name = name, .description = description),
    arg_types
  ))
}

# Convert a JSON Schema `object` into a named list of ellmer type_*() args
# suitable for splatting into ellmer::tool().
schema_to_ellmer_args <- function(schema) {
  props <- schema$properties %||% list()
  required <- unlist(schema$required %||% list())
  out <- list()
  for (nm in names(props)) {
    out[[nm]] <- schema_to_ellmer_type(props[[nm]], required = nm %in% required)
  }
  out
}

schema_to_ellmer_type <- function(prop, required = FALSE) {
  type <- prop$type %||% "string"
  if (is.list(type)) type <- type[[1]]
  desc <- prop$description %||% ""
  switch(type,
    "string"  = ellmer::type_string(description = desc, required = required),
    "integer" = ellmer::type_integer(description = desc, required = required),
    "number"  = ellmer::type_number(description = desc, required = required),
    "boolean" = ellmer::type_boolean(description = desc, required = required),
    "array"   = ellmer::type_array(
      description = desc,
      items = schema_to_ellmer_type(prop$items %||% list(type = "string"))
    ),
    "object"  = do.call(ellmer::type_object, c(
      list(.description = desc, .required = required),
      schema_to_ellmer_args(prop)
    )),
    ellmer::type_string(description = desc, required = required)
  )
}

flatten_mcp_content <- function(result) {
  if (is.null(result)) return("")
  content <- result$content %||% list()
  texts <- vapply(content, function(item) {
    if (identical(item$type, "text")) item$text %||% "" else ""
  }, character(1))
  paste(texts, collapse = "\n")
}

`%||%` <- function(a, b) if (is.null(a)) b else a
