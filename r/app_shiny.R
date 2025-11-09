library(shiny)
library(haven)
library(dplyr)

root <- "/project-root"

adsl_path <- file.path(root, "data", "adam", "adsl.sas7bdat")
if (!file.exists(adsl_path)) {
  stop("ADSL file not found at: ", adsl_path,
       "\nRun the SAS steps 10_raw_import, 20_sdtm_dm, 30_adam_adsl first.")
}

adsl <- read_sas(adsl_path)

ui <- fluidPage(
  titlePanel("ADSL Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("trt", "Treatment", choices = c("All", sort(unique(adsl$TRT01A)))),
      selectInput("var", "Summary variable", choices = c("AGE", "SEX"))
    ),
    mainPanel(
      tableOutput("summary_tbl")
    )
  )
)

server <- function(input, output, session) {
  filtered <- reactive({
    if (input$trt == "All") adsl else subset(adsl, TRT01A == input$trt)
  })

  output$summary_tbl <- renderTable({
    df <- filtered()
    if (input$var == "AGE") {
      data.frame(
        N = nrow(df),
        Mean = mean(df$AGE, na.rm = TRUE),
        SD = sd(df$AGE, na.rm = TRUE),
        Min = min(df$AGE, na.rm = TRUE),
        Max = max(df$AGE, na.rm = TRUE)
      )
    } else {
      df %>%
        count(SEX, name = "N") %>%
        mutate(Percent = round(100 * N / sum(N), 1))
    }
  })
}

shinyApp(ui, server)
