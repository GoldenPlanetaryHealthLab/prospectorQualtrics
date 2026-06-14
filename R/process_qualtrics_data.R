library(dplyr)
library(stringr)
library(glue)
library(tidyr)
library(qualtRics)
library(googledrive)
library(googlesheets4)
library(here)
library(testthat)
library(logger)
box::use(
  R/downloaders[download_from_qualtrics]
)

if(!exists("params$testing")) {
  testing <- interactive()
}

log_file <- here("pipelines/logs/maestro.log")

if (testing) {
  log_threshold(DEBUG)
  #log_appender(appender_tee(log_file))
  log_info("Running in testing mode: logs will be printed to console.")
} else {
  log_threshold(INFO)
  log_appender(appender_file(log_file))
    log_info("Running in production mode: logs will be saved to file only.")
}


log_info("Setting up Qualtrics API connection...")

test_that("Qualtrics API credentials are set", {
  expect_true(Sys.getenv("QUALTRICS_API_KEY") != "")
  expect_true(Sys.getenv("QUALTRICS_BASE_URL") != "")
  expect_no_error(all_surveys())
})


log_info("Accessing Qualtrics project...")
qualtrics_project_id <- all_surveys() |>
  dplyr::filter(str_detect(name, "Data Intake Form")) |> 
  pull(id)

log_info("Qualtrics project ID retrieved")
survey_df <- fetch_survey(qualtrics_project_id)
log_info("Survey data retrieved: dimensions - {nrow(survey_df)} rows, {ncol(survey_df)} columns")


log_info("Setting up Google Sheets access...")

sa <- Sys.getenv("GOOGLEDRIVE_SERVICE_ACCOUNT_FILE")
gsheet <- Sys.getenv("GOOGLESHEETS_SHEET_URL")

test_that("Google API credentials are set", {

  expect_true(nzchar(sa))
  expect_true(file.exists(sa))
  expect_no_error(drive_auth(path = sa))
  expect_no_error(gs4_auth(path = sa))

})

sheet_df <- read_sheet(gsheet, col_types = "cTcccc")

test_that("Google Sheet data retrieved correctly", {
  expect_true(nrow(sheet_df) > 0)
  expect_true(all(c("response_id", "processed") %in% colnames(sheet_df)))
})


sheet_df |>
  mutate(
    gsheets_index = 1:n(), 
    data_gt_50_mb = case_when(
      data_gt_50_mb == "Yes" ~ TRUE,
      data_gt_50_mb == "No" ~ FALSE,
      TRUE ~ NA
    )) |>
  mutate(
    processed = if_else(
      processed %in% c("TRUE", "FALSE", "", NA),
      processed,
      NA_character_
    ) %>% as.logical() %>% replace_na(FALSE)
  ) |>
  dplyr::filter(!processed) %>%
  full_join(., survey_df, by = join_by("response_id" == "ResponseId")) -> unprocessed_responses

log_info("Unprocessed responses identified: {nrow(unprocessed_responses)}")

unprocessed_responses |>
  dplyr::filter(!data_gt_50_mb) -> direct_download_candidates

unprocessed_responses |>
  dplyr::filter(data_gt_50_mb) -> globus_download_candidates

log_info("Download Candidates: {nrow(direct_download_candidates)} direct, {nrow(globus_download_candidates)} globus")


if(nrow(direct_download_candidates) > 0){
  log_info("Processing direct downloads for {nrow(direct_download_candidates)} candidates...")

  direct_download_candidates %>%
    {
      if(testing){
        # just taking a sample for testing
        slice_sample(., n = min(3, nrow(.)))
      } else {
        .
      }
    } %>%
    rowwise() |>
    mutate(
      download_result = download_from_qualtrics(
        file_id = Q25_Id,
        filename = Q25_Name,
        qualtrics_project_id = qualtrics_project_id,
        response_id = response_id,
        response_date = StartDate,
        responder_id = case_when(
          !is.na(Q12) ~ Q12,
          !is.na(Q14) ~ Q14,
          !is.na(Q15) ~ Q15,
          !is.na(Q17) ~ Q17,
          !is.na(uploader_name) ~ uploader_name,
          TRUE ~ "Unknown"
        )
      )
    ) -> direct_download_results
  log_info("Direct download attempts completed for {nrow(direct_download_results)} candidates")
  test_that("Qualtrics direct download process completed successfully", {
    expect_true(all(!is.na(direct_download_results$download_result)))
    expect_true(all(file.exists(direct_download_results$download_result)))
  })
} else {
  log_info("No direct download candidates to process.")
  direct_download_results <- direct_download_candidates %>%
    mutate(download_result = NA_character_)
}


updated_sheet_df <- sheet_df |>
  mutate(processed = as.logical(processed)) |>
  left_join(
    direct_download_results |> select(response_id, download_result),
    by = join_by(response_id)
  ) |>
  mutate(
    processed = case_when(
      !is.na(download_result) ~ TRUE,
      TRUE ~ processed
    )
  ) %>%
  select(-download_result)

test_that("Google Sheet updated correctly after processing", {
  expect_true(nrow(updated_sheet_df) == nrow(sheet_df))
})

log_info("Google Sheet updated with processed status for direct downloads. Attempting to write back to Google Sheets...")
range_write(gsheet, updated_sheet_df, range = "A1", col_names = TRUE)
log_info("Google Sheet updated successfully with processed status for direct downloads.")
