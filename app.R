library(shiny)
library(bslib)
library(shinychat)
library(ellmer)
library(httr2)
library(jsonlite)

# Sourced for paperclip_tools() — a direct httr2-based MCP client that
# works on Posit Connect Cloud (no Node / mcp-remote required).
source("R/paperclip_mcp.R")

SYSTEM_PROMPT <- paste(
  "You are a research assistant powered by Paperclip, a CLI-style tool that",
  "exposes ~150M scientific paper abstracts and millions of full-text papers",
  "(PMC, bioRxiv, medRxiv, arXiv) through filesystem-like commands.",
  "When the user asks a research question, use Paperclip tools (search,",
  "lookup, grep, cat, etc.) to find evidence before answering, and cite the",
  "papers you used. Prefer concrete tool calls over guessing."
)

ui <- page_fillable(
  title = "Paperclip Chat",
  theme = bs_theme(bootswatch = "flatly"),

  layout_sidebar(
    sidebar = sidebar(
      width = 340,
      title = "Setup",
      passwordInput(
        "anthropic_key", "Anthropic API key",
        placeholder = "sk-ant-api03-..."
      ),
      passwordInput(
        "paperclip_key", "Paperclip API key",
        placeholder = "gxl_..."
      ),
      selectInput(
        "model", "Model",
        choices = c(
          "claude-opus-4-7",
          "claude-sonnet-4-6",
          "claude-haiku-4-5"
        ),
        selected = "claude-sonnet-4-6"
      ),
      actionButton("connect", "Start chat", class = "btn-primary"),
      tags$hr(),
      tags$details(
        tags$summary("Where do I get these?"),
        tags$ul(
          tags$li(tags$a(
            "Anthropic API key",
            href = "https://console.anthropic.com/settings/keys",
            target = "_blank"
          )),
          tags$li(tags$a(
            "Paperclip API key",
            href = "https://paperclip.gxl.ai/keys",
            target = "_blank"
          ))
        ),
        tags$p(tags$small(
          "Keys are kept in memory for this session only and are never ",
          "written to disk."
        ))
      )
    ),
    uiOutput("chat_panel")
  )
)

server <- function(input, output, session) {
  status <- reactiveVal("Enter your keys and click Start chat.")
  chat_started <- reactiveVal(FALSE)

  output$chat_panel <- renderUI({
    if (!chat_started()) {
      div(
        class = "p-4",
        h3("Paperclip Chat"),
        p(
          "A Shiny chat that gives Claude access to Paperclip's MCP tools ",
          "(search/lookup/grep across ~150M scientific papers)."
        ),
        p(tags$em(status()))
      )
    } else {
      chat_mod_ui("chat")
    }
  })

  observeEvent(input$connect, {
    if (chat_started()) return()
    anth <- trimws(input$anthropic_key %||% "")
    pclip <- trimws(input$paperclip_key %||% "")

    if (!nzchar(anth) || !nzchar(pclip)) {
      status("Please paste both keys before starting.")
      return()
    }
    if (!startsWith(anth, "sk-ant-")) {
      status(paste(
        "Anthropic key should start with sk-ant-api03-... Subscription-only",
        "OAuth tokens (sk-ant-oat01-...) are rejected by the Messages API,",
        "so ellmer cannot use them. See README."
      ))
      return()
    }

    status("Connecting to Paperclip MCP...")
    tools <- tryCatch(
      paperclip_tools(api_key = pclip),
      error = function(e) {
        status(paste("Paperclip MCP error:", conditionMessage(e)))
        NULL
      }
    )
    req(tools)

    chat <- ellmer::chat_anthropic(
      system_prompt = SYSTEM_PROMPT,
      model = input$model,
      api_key = anth
    )
    chat$set_tools(tools)

    chat_started(TRUE)
    chat_mod_server("chat", chat)
  })
}

shinyApp(ui, server)
