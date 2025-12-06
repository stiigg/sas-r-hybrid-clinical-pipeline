# Portfolio Management Dashboard Module
# Demonstrates multi-study coordination and resource management

library(shiny)
library(dplyr)
library(ggplot2)
library(plotly)
library(yaml)
library(purrr)
library(rlang)

portfolio_dashboard_UI <- function(id) {
  ns <- NS(id)
  
  tagList(
    h2("Multi-Study Portfolio Dashboard"),
    p("Demonstrates senior programmer capability to manage concurrent clinical trials"),
    
    fluidRow(
      # Portfolio summary cards
      column(3,
             valueBoxOutput(ns("total_studies"))),
      column(3,
             valueBoxOutput(ns("active_studies"))),
      column(3,
             valueBoxOutput(ns("total_patients"))),
      column(3,
             valueBoxOutput(ns("upcoming_milestones")))
    ),
    
    fluidRow(
      column(6,
             plotlyOutput(ns("timeline_gantt"), height = "400px")),
      column(6,
             plotlyOutput(ns("resource_allocation"), height = "400px"))
    ),
    
    fluidRow(
      column(12,
             h3("Study Status Table"),
             DT::dataTableOutput(ns("study_table")))
    ),
    
    fluidRow(
      column(6,
             h3("Priority Queue"),
             plotOutput(ns("priority_plot"))),
      column(6,
             h3("Cross-Study Dependencies"),
             plotOutput(ns("dependency_network")))
    )
  )
}

portfolio_dashboard_Server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    # Load portfolio data
    portfolio_data <- reactive({
      req(file.exists("studies/portfolio_registry.yml"))
      yaml::read_yaml("studies/portfolio_registry.yml")
    })
    
    # Summary metrics
    output$total_studies <- renderValueBox({
      data <- portfolio_data()
      valueBox(
        value = length(data$studies),
        subtitle = "Total Studies in Portfolio",
        icon = icon("flask"),
        color = "blue"
      )
    })
    
    output$active_studies <- renderValueBox({
      data <- portfolio_data()
      active <- sum(sapply(data$studies, function(s) 
        !grepl("Complete", s$status, ignore.case = TRUE)))
      
      valueBox(
        value = active,
        subtitle = "Active Studies",
        icon = icon("play-circle"),
        color = "green"
      )
    })
    
    output$total_patients <- renderValueBox({
      data <- portfolio_data()
      total <- sum(sapply(data$studies, function(s) s$enrollment_target))
      
      valueBox(
        value = format(total, big.mark = ","),
        subtitle = "Total Patients Enrolled",
        icon = icon("users"),
        color = "purple"
      )
    })

    output$upcoming_milestones <- renderValueBox({
      data <- portfolio_data()
      lock_dates <- sapply(data$studies, function(s) {
        planned <- s$database_lock_planned %||% NA
        actual <- s$database_lock_actual %||% NA
        coalesce(planned, actual)
      })

      lock_dates <- lock_dates[!is.na(lock_dates) & nzchar(lock_dates)]
      parsed <- suppressWarnings(as.Date(lock_dates))
      parsed <- parsed[!is.na(parsed)]

      next_lock <- if (length(parsed) > 0) min(parsed) else NA

      valueBox(
        value = if (!is.na(next_lock)) format(next_lock, "%Y-%m-%d") else "TBD",
        subtitle = "Next Database Lock",
        icon = icon("calendar-alt"),
        color = "yellow"
      )
    })
    
    # Study timeline Gantt chart
    output$timeline_gantt <- renderPlotly({
      data <- portfolio_data()
      
      # Extract milestone dates
      timeline_df <- map_dfr(names(data$studies), function(sid) {
        study <- data$studies[[sid]]
        milestones <- study$milestones
        
        data.frame(
          study_id = sid,
          phase = study$phase,
          priority = study$priority,
          first_patient = as.Date(milestones$first_patient_in %||% NA),
          database_lock = as.Date(study$database_lock_planned %||% 
                                   study$database_lock_actual %||% NA),
          stringsAsFactors = FALSE
        )
      }) %>%
        filter(!is.na(first_patient))
      
      # Create Gantt chart
      plot_ly(timeline_df,
              x = ~first_patient,
              xend = ~database_lock,
              y = ~reorder(study_id, priority),
              color = ~phase,
              type = "scatter",
              mode = "lines+markers",
              line = list(width = 20)) %>%
        layout(
          title = "Study Timelines",
          xaxis = list(title = "Date"),
          yaxis = list(title = "Study"),
          showlegend = TRUE
        )
    })
    
    # Resource allocation heatmap
    output$resource_allocation <- renderPlotly({
      data <- portfolio_data()
      
      if (is.null(data$resource_allocation$programmers)) {
        return(NULL)
      }
      
      resource_df <- map_dfr(data$resource_allocation$programmers, function(prog) {
        map_dfr(names(prog$allocation), function(study) {
          data.frame(
            programmer = prog$name,
            study = study,
            allocation = prog$allocation[[study]],
            stringsAsFactors = FALSE
          )
        })
      })
      
      plot_ly(resource_df,
              x = ~study,
              y = ~programmer,
              z = ~allocation,
              type = "heatmap",
              colorscale = "Blues") %>%
        layout(
          title = "Resource Allocation (% Time)",
          xaxis = list(title = "Study/Task"),
          yaxis = list(title = "Programmer")
        )
    })
    
    # Study status table
    output$study_table <- DT::renderDataTable({
      data <- portfolio_data()
      
      table_df <- map_dfr(names(data$studies), function(sid) {
        study <- data$studies[[sid]]
        data.frame(
          Study = sid,
          Protocol = study$protocol_number,
          Phase = study$phase,
          Priority = study$priority,
          Status = study$status,
          `DB Lock` = study$database_lock_planned %||% "N/A",
          Programmer = study$team$trial_programmer %||% "Unassigned",
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      })
      
      DT::datatable(table_df,
                    options = list(pageLength = 10),
                    rownames = FALSE)
    })
  })
}
