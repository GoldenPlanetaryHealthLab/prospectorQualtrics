library(maestro)
library(glue)
library(cronR)
library(here)


#' Ferry Qualtrics Responses To The Gold Mine
#'
#' @maestroFrequency 1 day
#' @maestroStartTime 2026-06-12
#' @maestroTz US/Eastern
#' @maestroLogLevel INFO
process_data_pipeline <- function() {

  print("Running the maestro pipeline...")
  source(here("R/process_qualtrics_data.R"))

}
