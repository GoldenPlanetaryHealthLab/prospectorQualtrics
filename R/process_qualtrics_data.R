library(dplyr)


library(glue)
library(qualtRics)
library(googlesheets4)
library(here)


print("Setting up Qualtrics API connection...")


connection_to_api <- "Connected"


print("Accessing Qualtrics project...")


qualtrics_project_id <- "1234567890"
print(paste("Project ID:", qualtrics_project_id))


survey_df <- data.frame(
  respondent_id = c("R1", "R2", "R3"),
  response = c("Yes", "No", "Yes"),
  data_gt_50mb = c(FALSE, FALSE, TRUE),
  data_path_globus = c(NA, NA, "globus://path/to/large/data/R3")
)
print("Survey data retrieved:")


gsheet <- "url to google sheet"
sheet_df <- data.frame(
  respondent_id = c("R1", "R2", "R3"),
  processed = c(FALSE, FALSE, FALSE)
)


sheet_df |>
    filter(!processed) |>
    left_join(survey_df, by = "respondent_id") |>
    rowwise() |>
    mutate(
        download_path = ifelse(data_gt_50mb == FALSE, paste0("gold_mine/qualtrics/", respondent_id, ".csv"), data_path_globus)
    ) |>
    ungroup() -> unprocessed_responses


print("Unprocessed responses with download paths:")


print(unprocessed_responses)


download_data <- function(download_path, respondent_id) {
    if (grepl("globus://", download_path)) {
        print(paste("Downloading large data for respondent", respondent_id, "from globus path:", download_path))
        # Code to download from globus would go here
    } else {
        print(paste("Downloading small data for respondent", respondent_id, "from Qualtrics response object ID:", download_path))
        # Code to download from Qualtrics would go here
    }
}

unprocessed_responses |>
    rowwise() |>
    mutate(
        download_result = download_data(download_path, respondent_id)
    ) -> processed_responses


updated_sheet_df <- sheet_df |>
    left_join(processed_responses, by = "respondent_id") |>
    mutate(processed = ifelse(!is.na(download_result), TRUE, FALSE))

print("Updated sheet with processed status:")


print(updated_sheet_df)
