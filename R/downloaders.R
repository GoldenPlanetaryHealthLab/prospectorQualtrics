box::use(httr2)
box::use(readr)
box::use(lubridate)
box::use(fs)
box::use(here)
box::use(janitor)
box::use(glue)

#' Download an uploaded file from a Qualtrics survey response
#'
#' Downloads a file attached to a Qualtrics survey response using the Qualtrics
#' uploaded-files API endpoint. Files are staged under a date- and
#' responder-specific directory.
#'
#' @param file_id Character. Qualtrics uploaded file ID, usually beginning with
#'   `"F_"`.
#' @param filename Character. Output filename to use when saving the downloaded
#'   file.
#' @param qualtrics_project_id Character. Qualtrics survey ID, usually beginning
#'   with `"SV_"`.
#' @param response_id Character. Qualtrics response ID, usually beginning with
#'   `"R_"`.
#' @param response_date Date, POSIXct, or character coercible to a date. Used to
#'   partition staged downloads by response date.
#' @param responder_id Character. Identifier for the respondent or uploader.
#'   Used to create a responder-specific staging directory.
#' @param base_url Character. Qualtrics base URL. Defaults to the
#'   `QUALTRICS_BASE_URL` environment variable.
#' @param api_token Character. Qualtrics API token. Defaults to the
#'   `QUALTRICS_API_KEY` environment variable.
#' @param output_dir Character. Base staging directory for downloaded Qualtrics
#'   files.
#'
#' @return Character path to the downloaded file. Returns `NA_character_` if the
#'   download fails.
#'
#'
#' @examples
#' \dontrun{
#' download_from_qualtrics(
#'   file_id = "F_abc123",
#'   filename = "example.csv",
#'   qualtrics_project_id = "SV_abc123",
#'   response_id = "R_abc123",
#'   response_date = "2026-05-03",
#'   responder_id = "Example Responder"
#' )
#' }
#' @export
download_from_qualtrics <- function(
  file_id,
  filename,
  qualtrics_project_id,
  response_id,
  response_date,
  responder_id,
  base_url = Sys.getenv("QUALTRICS_BASE_URL"),
  api_token = Sys.getenv("QUALTRICS_API_KEY"),
  output_dir = here::here("data/staging/qualtrics")
) {
  required_args <- list(
    file_id = file_id,
    filename = filename,
    qualtrics_project_id = qualtrics_project_id,
    response_id = response_id,
    responder_id = responder_id,
    base_url = base_url,
    api_token = api_token,
    output_dir = output_dir
  )

  missing_args <- names(required_args)[vapply(required_args, identical, logical(1), "")]

  if (length(missing_args) > 0) {
    stop(
      "Missing required argument(s): ",
      paste(missing_args, collapse = ", "),
      call. = FALSE
    )
  }

  base_url <- sub("/+$", "", base_url)

  download_url <- glue::glue(
    "{base_url}/API/v3/surveys/{qualtrics_project_id}/responses/{response_id}/uploaded-files/{file_id}"
  )

  response_date <- lubridate::as_date(response_date)

  output_dir_final <- fs::path(
    output_dir,
    response_date,
    janitor::make_clean_names(responder_id)
  )

  fs::dir_create(output_dir_final)

  output_path <- fs::path(output_dir_final, filename)

  response <- httr2::request(download_url) |>
    httr2::req_headers(
      `X-API-TOKEN` = api_token,
      Accept = "application/octet-stream"
    ) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform(path = output_path)

  status_code <- httr2::resp_status(response)

  if (status_code == 200 && fs::file_exists(output_path)) {
    message(glue::glue("File downloaded successfully to {output_path}"))
    return(as.character(output_path))
  }

  error_body <- tryCatch(
    httr2::resp_body_string(response),
    error = function(e) NA_character_
  )

  warning(
    glue::glue(
      "Failed to download file from Qualtrics. ",
      "Status code: {status_code}. ",
      "Output path: {output_path}. ",
      "Response body: {error_body}"
    ),
    call. = FALSE
  )

  NA_character_
}
