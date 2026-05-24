app_server <- function(input, output, session) {

  index <- load_index()
  sessions_meta <- index$sessions
  default_session_id <- if (length(sessions_meta) > 0) sessions_meta[[1]]$id else NULL

  state <- reactiveValues(
    selected_id   = default_session_id,
    transcript    = NULL,
    event_idx     = 0L,
    rendered_n    = 0L,
    playing       = FALSE,
    next_fire_at  = NULL,
    completed     = FALSE
  )

  load_selected <- function(session_id) {
    t <- load_transcript(session_id)
    state$transcript <- t
    state$event_idx <- 0L
    state$rendered_n <- 0L
    state$playing <- FALSE
    state$next_fire_at <- NULL
    state$completed <- FALSE
    shinyjs::html("viewport_stream", "")
    shinyjs::show("viewport_empty")
    shinyjs::hide("viewport_thinking")
    session$sendCustomMessage("replay_reset", list())
  }

  observe({
    if (!is.null(state$selected_id)) load_selected(state$selected_id)
  })

  observeEvent(input$selected_session, {
    state$selected_id <- input$selected_session
  })

  output$session_list <- renderUI({
    roles <- index$roles
    if (is.null(roles) || length(roles) == 0) {
      roles <- unique(vapply(sessions_meta, function(m) m$role %||% "Other", character(1)))
    }
    role_groups <- lapply(roles, function(r) {
      group <- Filter(function(m) identical(m$role %||% "", r), sessions_meta)
      if (length(group) == 0) return(NULL)
      htmltools::tagList(
        htmltools::tags$div(class = "picker-role-header", r),
        lapply(group, function(meta) {
          session_card(meta, selected = identical(meta$id, state$selected_id))
        })
      )
    })
    htmltools::tagList(role_groups)
  })

  output$viewport_title <- renderText({
    t <- state$transcript
    if (is.null(t)) "" else (t$title %||% "")
  })

  output$metadata_stats <- renderUI({
    t <- state$transcript
    if (is.null(t)) return(htmltools::tags$div(class = "metadata-empty", "Pick a session to see details."))
    m <- t$metadata
    stat_row <- function(label, value) {
      if (is.null(value)) return(NULL)
      htmltools::tags$div(class = "stat-row",
        htmltools::tags$span(class = "stat-label", label),
        htmltools::tags$span(class = "stat-value", value)
      )
    }
    htmltools::tagList(
      stat_row("Tool calls", m$tool_calls),
      stat_row("Documents read", m$documents_read),
      stat_row("Wall clock", if (!is.null(m$wall_clock_seconds)) format_duration(m$wall_clock_seconds) else NULL),
      stat_row("Events", length(t$events))
    )
  })

  output$metadata_about <- renderUI({
    t <- state$transcript
    if (is.null(t)) return(NULL)
    desc <- t$description %||% t$subtitle %||% ""
    htmltools::tags$div(class = "about-body", desc)
  })

  observeEvent(input$btn_play, {
    if (is.null(state$transcript)) return()
    if (state$completed) return()
    state$playing <- TRUE
    if (state$rendered_n > 0) shinyjs::hide("viewport_empty")
    if (is.null(state$next_fire_at)) {
      state$next_fire_at <- Sys.time()
    }
  })

  observeEvent(input$btn_pause, {
    state$playing <- FALSE
    shinyjs::hide("viewport_thinking")
  })

  observeEvent(input$btn_restart, {
    if (!is.null(state$selected_id)) load_selected(state$selected_id)
  })

  observe({
    if (!isTRUE(state$playing)) return()
    t <- state$transcript
    if (is.null(t)) return()
    events <- t$events
    if (state$event_idx >= length(events)) {
      state$playing <- FALSE
      state$completed <- TRUE
      shinyjs::hide("viewport_thinking")
      return()
    }

    speed <- as.numeric(input$playback_speed %||% 1)
    if (is.na(speed) || speed <= 0) speed <- 1

    fire_at <- state$next_fire_at %||% Sys.time()
    now <- Sys.time()
    wait_ms <- max(0, as.numeric(difftime(fire_at, now, units = "secs")) * 1000)

    if (wait_ms > 250) {
      shinyjs::show("viewport_thinking")
    } else {
      shinyjs::hide("viewport_thinking")
    }

    if (wait_ms > 0) {
      invalidateLater(min(wait_ms, 200))
      return()
    }

    next_idx <- state$event_idx + 1L
    event <- events[[next_idx]]
    shinyjs::hide("viewport_empty")
    if (!identical(event$type, "pause")) {
      html <- as.character(render_event(event, next_idx))
      session$sendCustomMessage("replay_append", list(html = html, type = event$type %||% ""))
    }
    state$event_idx <- next_idx
    state$rendered_n <- state$rendered_n + 1L

    if (next_idx < length(events)) {
      nxt <- events[[next_idx + 1L]]
      gap_ms <- event_delay_ms(nxt) / speed
      state$next_fire_at <- Sys.time() + gap_ms / 1000
      invalidateLater(min(gap_ms, 200))
    } else {
      state$playing <- FALSE
      state$completed <- TRUE
      shinyjs::hide("viewport_thinking")
    }
  })
}
