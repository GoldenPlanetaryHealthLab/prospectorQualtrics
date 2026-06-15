box::use(httr2)
box::use(readr)
box::use(lubridate)
box::use(fs)
box::use(here)
box::use(janitor)
box::use(glue)
box::use(purrr)
box::use(testthat)


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
#' @family Downloaders
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
    response_date = response_date,
    responder_id = responder_id,
    base_url = base_url,
    api_token = api_token,
    output_dir = output_dir
  )

  is_missing <- function(x) {
     is.null(x) || (length(x) == 1 && (is.na(x) || identical(x, "") || (is.character(x) && !nzchar(x))))
   }
  missing_args <- names(required_args)[vapply(required_args, is_missing, logical(1))]

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

  filename <- fs::path_file(filename)

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


#' Stage a dataset uploaded through the lab Globus intake collection
#'
#' Locates a dataset uploaded to the lab's Globus intake collection and copies
#' it into the prospector staging area. Uploads are expected to reside in a
#' directory named after the associated Qualtrics response ID. The function
#' verifies that the intake directory exists and contains files before copying
#' the contents to a response-specific staging directory.
#'
#' Unlike datasets uploaded directly through Qualtrics, Globus-uploaded data
#' already resides on Harvard's HPC storage infrastructure. As a result, this
#' function performs a filesystem copy operation rather than a network
#' download.
#'
#' @param response_id Character. Qualtrics response ID used to identify the
#'   corresponding Globus intake directory.
#' @param response_date Date, POSIXct, or character coercible to a date. Used
#'   to partition staged datasets by submission date.
#' @param responder_id Character. Identifier for the uploader. Used to create
#'   a responder-specific staging directory.
#' @param base_url Character. Path to the root Globus intake directory on the
#'   filesystem. Defaults to the lab's Globus-backed intake location.
#' @param output_dir Character. Base directory where staged datasets should be
#'   copied.
#'
#' @return Character path to the staged dataset directory. Returns
#'   `NA_character_` if one or more files fail to copy successfully.
#'
#' @details
#' The function assumes that:
#'
#' \itemize{
#'   \item Large datasets have been uploaded through the lab's Globus intake
#'     collection.
#'   \item Each upload resides in a directory named after the corresponding
#'     Qualtrics response ID.
#'   \item The intake collection is backed by a filesystem path accessible from
#'     the execution environment.
#' }
#'
#' @seealso [download_from_qualtrics()]
#'
#' @examples
#' \dontrun{
#' download_from_globus_netscratch(
#'   response_id = "R_123456789",
#'   response_date = "2026-05-03",
#'   responder_id = "Jane Doe"
#' )
#' }
#' @family Downloaders
#'
#' @export
download_from_globus_netscratch <- function(
  response_id,
  response_date,
  responder_id,
  base_url = "/n/netscratch/cgolden_lab/Lab/qualtrics_data_intake_folder",
  output_dir = here::here("data/staging/globus")
) {
  required_args <- list(
    response_id = response_id,
    response_date = response_date,
    responder_id = responder_id,
    base_url = base_url,
    output_dir = output_dir
  )

  is_missing <- function(x) {
     is.null(x) || (length(x) == 1 && (is.na(x) || identical(x, "") || (is.character(x) && !nzchar(x))))
   }
  missing_args <- names(required_args)[vapply(required_args, is_missing, logical(1))]

  if (length(missing_args) > 0) {
    stop(
      "Missing required argument(s): ",
      paste(missing_args, collapse = ", "),
      call. = FALSE
    )
  }

  download_url <- fs::fs_path(
    glue::glue(
      "{base_url}/{response_id}"
    )
  )

  message("Testing if Globus netscratch URL exists")

  fs::dir_exists(download_url) || stop(
    glue::glue("Globus netscratch URL does not exist: {download_url}"),
    call. = FALSE
  )

  response_date <- lubridate::as_date(response_date)

  output_dir_final <- fs::path(
    output_dir,
    response_date,
    janitor::make_clean_names(responder_id),
    response_id
  )

  fs::dir_create(output_dir_final)

  filenames <- fs::dir_ls(download_url, type = "file") # this may appear as a singular character vector, but since it is a named char, you can use it as a list in subsequent map functions (ie it wont map over each character in the string, but rather treat the whole string as one element to map over)

  message("Testing if Globus netscratch URL contains files")
  length(filenames) > 0 || stop(
    glue::glue("Globus netscratch URL does not contain any files: {download_url}"),
    call. = FALSE
  )

  fs::dir_copy(download_url, output_dir_final, overwrite = TRUE)

  successfully_copied <- purrr::map_lgl(filenames, ~ fs::file_exists(fs::path(output_dir_final, fs::path_file(.x)))) |> 
    unlist()

   if(all(successfully_copied)) {
     message(glue::glue("All files copied successfully from {download_url} to {output_dir_final}"))
     return(as.character(output_dir_final))
   } else {
     warning(glue::glue("Some files failed to copy from {download_url} to {output_dir_final}"))
   }
  NA_character_
}
