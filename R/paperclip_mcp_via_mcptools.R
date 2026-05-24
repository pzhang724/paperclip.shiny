# Alternative path: use the official `mcptools` package as the MCP client.
#
# mcptools only speaks stdio MCP, so we wrap Paperclip's HTTP endpoint with
# the `mcp-remote` Node bridge. This requires Node.js + npx on the host and
# is therefore NOT used by the deployed app (Posit Connect Cloud doesn't
# bundle Node). Keep this file as a reference for local development.
#
# Usage:
#   tools <- paperclip_tools_via_mcptools("gxl_xxx")
#   chat$set_tools(tools)

paperclip_tools_via_mcptools <- function(api_key,
                                         url = "https://paperclip.gxl.ai/mcp") {
  if (!requireNamespace("mcptools", quietly = TRUE)) {
    stop("Install mcptools: install.packages('mcptools')")
  }
  if (Sys.which("npx") == "") {
    stop("npx not found on PATH. Install Node.js, or use paperclip_tools() ",
         "from R/paperclip_mcp.R instead.")
  }

  cfg_path <- tempfile(fileext = ".json")
  cfg <- list(
    mcpServers = list(
      paperclip = list(
        command = "npx",
        args = list(
          "-y", "mcp-remote", url,
          "--header", paste0("X-API-Key:", api_key),
          "--transport", "http-only"
        )
      )
    )
  )
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE)
  options(.mcptools_config = cfg_path)
  mcptools::mcp_tools()
}
