# paperclip.shiny

A Shiny app that turns the [Paperclip](https://paperclip.gxl.ai) scientific-literature
MCP server into a browser-native chat agent, using
[`shinychat`](https://posit-dev.github.io/shinychat/r/) +
[`ellmer`](https://ellmer.tidyverse.org) (+ a tiny in-process MCP client,
because `mcptools` can't speak HTTP on Posit Connect Cloud).

## What it does

- Renders a `shinychat` chat panel.
- Wires an `ellmer::chat_anthropic()` Chat to the Paperclip MCP server at
  `https://paperclip.gxl.ai/mcp`. Every tool the MCP server advertises
  (`search`, `lookup`, `grep`, `cat`, `sql`, `ask-image`, …) is exposed to
  Claude via `chat$set_tools()`.
- Users enter their **own** Anthropic API key and Paperclip API key in the
  sidebar — both stay in memory for the session only, never written to disk.

## Run locally

```r
install.packages(c("shiny", "bslib", "shinychat", "ellmer", "httr2", "jsonlite"))
shiny::runApp()
```

Then paste:
- An Anthropic API key (`sk-ant-api03-…`) from
  <https://console.anthropic.com/settings/keys>
- A Paperclip key (`gxl_…`) from <https://paperclip.gxl.ai/keys>

## Deploy to Posit Connect Cloud

`rsconnect::deployApp()` will pick up `app.R`, `R/`, and `dependencies.R`.
No environment variables or secrets are baked into the bundle — each visitor
brings their own keys.

## Why not just `mcptools`?

`mcptools` is the official MCP client for R, but at the time of writing it
only implements the **stdio** transport. To reach an HTTP MCP server like
Paperclip's it shells out to `npx mcp-remote`, which needs Node.js — and
Posit Connect Cloud's R image doesn't ship Node. So `R/paperclip_mcp.R`
contains ~80 lines of `httr2` that speak just enough Streamable HTTP MCP
(`initialize` → `notifications/initialized` → `tools/list` → `tools/call`)
to wrap every Paperclip tool as an `ellmer::tool()`.

If you're running locally with Node installed, `R/paperclip_mcp_via_mcptools.R`
shows the `mcptools` + `mcp-remote` path instead.

## About Claude subscription tokens (the `setup-token` question)

Short answer: **no, you can't use a Pro/Max subscription token with this
app — and not because of R.**

`claude setup-token` mints an OAuth token of the form `sk-ant-oat01-…`.
Anthropic's official documentation states that this token type **only works
with Claude Code** and is explicitly **rejected by the Messages API**, which
is the endpoint `ellmer` (and every other SDK) calls. There is no R-side
workaround for this — it's an Anthropic policy enforced server-side.

Practical options if you want to ship this publicly:

1. **Bring-your-own-key (what this app does).** Each visitor pastes their
   own `sk-ant-api03-…` developer key. Costs land on their Anthropic
   account, not yours. Good fit for a public Posit Connect Cloud deploy.
2. **You pay for everyone.** Bake a single API key into a Connect
   environment variable (`ANTHROPIC_API_KEY`), remove the sidebar input,
   and gate access at the Connect level. Watch your bill.
3. **Subscription-via-proxy (brittle).** Projects like CLIProxyAPI
   impersonate Claude Code's request format and translate `sk-ant-oat01-…`
   to Messages-API calls. You'd run such a proxy yourself and point
   `ellmer` at it via `Sys.setenv(ANTHROPIC_BASE_URL = ...)`. This is a
   policy-grey area, can break whenever Anthropic changes Claude Code's
   wire format, and is **not** what I'd ship on a public Connect Cloud URL.

A proper "log in with Claude" OAuth flow (PKCE → access token → Messages
API) is not something Anthropic currently offers third-party apps; the only
OAuth they expose is Claude Code's, and that token doesn't work against
the API ellmer uses. So a login-screen UX is blocked at the protocol level,
not at the R level.

## Files

```
app.R                              # shinychat + ellmer + sidebar setup
R/paperclip_mcp.R                  # direct httr2 MCP client (used by app.R)
R/paperclip_mcp_via_mcptools.R     # reference: mcptools + mcp-remote path
dependencies.R                     # package list for rsconnect bundler
```
