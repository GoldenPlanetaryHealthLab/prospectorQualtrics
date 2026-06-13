# render
quarto::quarto_render()

# git
repo_path <- here::here()
repo <- git2r::init(repo_path)
git2r::add(repo, "*")
msg <- glue::glue("update website: {Sys.time()}")
git2r::commit(repo, msg)