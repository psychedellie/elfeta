#!/usr/bin/env Rscript

# NGS_Report_v2.1.R
# Adds:
# - Mobility (MOBTyper)
# - MPF (MOBTyper)
# - Cluster (MOBTyper)
# - Virulence Genes (>90% cov, >90% ID, VirulenceFinder)

utils::globalVariables(c(
  "Plasmid", "Contig", ".", "Lab_ID", "Original_ID", "Index", "Platform",
  "Expected_Organism", "Comments", "Genome_Length", "Depth", "Predicted_Phenotype",
  "Circular_contigs", "Contig_Num", "N50", "GC_percent", "Largest_Contig",
  "X2", "Support", "GC_num", "N50_formatted", "Q30%"
))

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 9)  PIPELINE_MODE_ARG <- "ONT_DEFAULT" else PIPELINE_MODE_ARG <- toupper(args[9])
if (length(args) < 10) FASTP_DIR <- "" else FASTP_DIR <- args[10]
if (length(args) < 11) LOGS_DIR <- "" else LOGS_DIR <- args[11]
if (length(args) < 12) MOB_DIR  <- "" else MOB_DIR  <- args[12]
if (length(args) < 13) VIRULENCE_DIR <- "" else VIRULENCE_DIR <- args[13]

BASE_DIR     <- args[1]
SAMPLE_SHEET <- args[2]
QUAST_DIR    <- args[3]
MLST_DIR     <- args[4]
RMLST_DIR    <- args[5]
PLASMID_DIR  <- args[6]
AMR_DIR      <- args[7]
ASSEMBLY_DIR <- args[8]

suppressPackageStartupMessages({
  if (!requireNamespace("readr",    quietly = TRUE)) install.packages("readr")
  if (!requireNamespace("dplyr",    quietly = TRUE)) install.packages("dplyr")
  if (!requireNamespace("tibble",   quietly = TRUE)) install.packages("tibble")
  if (!requireNamespace("purrr",    quietly = TRUE)) install.packages("purrr")
  if (!requireNamespace("stringr",  quietly = TRUE)) install.packages("stringr")
  if (!requireNamespace("openxlsx", quietly = TRUE)) install.packages("openxlsx")
  if (!requireNamespace("utils",    quietly = TRUE)) install.packages("utils")
  if (!requireNamespace("jsonlite", quietly = TRUE)) install.packages("jsonlite")
})

library(readr)
library(dplyr)
library(tibble)
library(purrr)
library(stringr)
library(openxlsx)
library(utils)
library(jsonlite)

find_isolate_file <- function(dir_path, isolate_id, suffix_regex = ".*\\.(tsv|txt|csv)$", platform = NULL) {
  if (is.null(dir_path) || dir_path == "") return(NA_character_)

  if (suffix_regex == "ASSEMBLY_INFO") {
    if (!is.null(platform) && !is.na(platform)) {
      pattern <- paste0("^", isolate_id, "_", platform, "\\.txt$")
      files <- list.files(dir_path, pattern = pattern, full.names = TRUE, ignore.case = TRUE)
      if (length(files) >= 1) return(files[1])
    }

    pattern <- paste0("^", isolate_id, ".*\\.txt$")
    files <- list.files(dir_path, pattern = pattern, full.names = TRUE, ignore.case = TRUE)
    if (length(files) >= 1) return(files[1])

    return(NA_character_)
  }

  patt <- paste0("^", isolate_id, suffix_regex)
  files <- list.files(dir_path, pattern = patt, full.names = TRUE, ignore.case = TRUE)
  if (length(files) >= 1) return(files[1])

  patt2 <- paste0(isolate_id, ".*", suffix_regex)
  files2 <- list.files(dir_path, pattern = patt2, full.names = TRUE, ignore.case = TRUE, recursive = TRUE)
  if (length(files2) >= 1) return(files2[1])

  return(NA_character_)
}

read_quast_metrics <- function(tsv_path) {
  needed <- c("# contigs", "Total length", "N50", "Avg. coverage depth", "GC (%)", "Largest contig")
  if (!file.exists(tsv_path)) return(setNames(as.list(rep(NA, length(needed))), needed))

  df <- suppressMessages(readr::read_tsv(tsv_path, show_col_types = FALSE, progress = FALSE))

  if (ncol(df) == 2) {
    keys <- trimws(as.character(df[[1]]))
    vals <- df[[2]]
    names(vals) <- keys

    out <- setNames(vector("list", length(needed)), unname(needed))
    for (k in needed) out[[k]] <- if (k %in% names(vals)) vals[[k]] else NA
    return(out)
  }

  out <- setNames(vector("list", length(needed)), unname(needed))
  for (k in needed) out[[k]] <- if (k %in% names(df)) df[[k]][1] else NA
  out
}

read_assembly_info_circular_count <- function(file_path) {
  if (is.na(file_path) || !file.exists(file_path)) return(NA_character_)

  df <- tryCatch(
    readr::read_tsv(file_path, comment = "", show_col_types = FALSE, progress = FALSE, trim_ws = TRUE),
    error = function(e) NULL
  )

  if (is.null(df) || nrow(df) == 0) return(NA_character_)

  names(df) <- sub("^#", "", names(df))
  circ_col <- names(df)[grepl("^circ\\.?$", names(df), ignore.case = TRUE)]

  if (length(circ_col) == 0) return(NA_character_)

  circ_vals <- toupper(as.character(df[[circ_col[1]]]))
  count <- sum(circ_vals == "Y", na.rm = TRUE)

  as.character(count)
}

read_mlst_st <- function(tsv_path) {
  if (!file.exists(tsv_path)) return(NA_character_)

  df <- tryCatch(
    utils::read.delim(
      tsv_path,
      sep = "\t",
      header = FALSE,
      stringsAsFactors = FALSE,
      quote = "",
      comment.char = "",
      fill = TRUE,
      check.names = FALSE
    ),
    error = function(e) NULL
  )

  if (is.null(df) || nrow(df) < 1) return(NA_character_)
  if (ncol(df) >= 3 && !is.na(df[1, 3]) && nzchar(df[1, 3])) return(as.character(df[1, 3]))

  row1 <- paste(df[1, ], collapse = " ")
  m <- stringr::str_extract(row1, "(?<!\\d)\\d+(?!\\d)")

  ifelse(is.na(m) || m == "", NA_character_, m)
}

read_rmlst_taxon <- function(tsv_path) {
  if (!file.exists(tsv_path)) return(NA_character_)

  df <- tryCatch(
    readr::read_tsv(tsv_path, show_col_types = FALSE, progress = FALSE),
    error = function(e) NULL
  )

  if (is.null(df) || !"Taxon" %in% names(df) || nrow(df) < 1) return(NA_character_)

  val <- df$Taxon[1]
  ifelse(is.na(val) || val == "", NA_character_, as.character(val))
}

read_rmlst_detection <- function(tsv_path) {
  if (!file.exists(tsv_path)) return(NA_character_)

  df <- tryCatch(
    readr::read_tsv(tsv_path, show_col_types = FALSE, progress = FALSE),
    error = function(e) NULL
  )

  if (is.null(df) || !"Support" %in% names(df) || nrow(df) < 1) return(NA_character_)

  val <- df$Support[1]
  ifelse(is.na(val) || val == "", NA_character_, as.character(val))
}

read_plasmid_list <- function(tsv_path) {
  if (!file.exists(tsv_path)) return(NA_character_)

  df <- tryCatch(
    readr::read_tsv(tsv_path, show_col_types = FALSE, progress = FALSE),
    error = function(e) NULL
  )

  if (is.null(df) || !"Plasmid" %in% names(df) || nrow(df) == 0) return(NA_character_)

  df <- df %>%
    mutate(
      Plasmid = as.character(Plasmid),
      Contig = if ("Contig" %in% names(.)) as.character(Contig) else NA_character_
    ) %>%
    filter(!is.na(Plasmid), nzchar(Plasmid))

  if (nrow(df) == 0) return(NA_character_)

  if ("Contig" %in% names(df) && any(!is.na(df$Contig))) {
    per_contig <- df %>%
      group_by(Contig) %>%
      summarise(merged = paste(Plasmid, collapse = "/"), .groups = "drop") %>%
      arrange(Contig)

    paste(per_contig$merged, collapse = "; ")
  } else {
    paste(df$Plasmid, collapse = "; ")
  }
}

read_amr_column <- function(txt_path, scope_wanted, type_wanted, subtype_wanted = NULL, out_col = "Element symbol") {
  if (!file.exists(txt_path)) return(NA_character_)

  df <- tryCatch(
    readr::read_tsv(txt_path, show_col_types = FALSE, progress = FALSE),
    error = function(e) NULL
  )

  if (is.null(df) || nrow(df) == 0) return(NA_character_)

  nms <- names(df)
  nms_lc <- tolower(nms)

  col_idx <- function(pattern) {
    i <- which(grepl(pattern, nms_lc, perl = TRUE))
    if (length(i)) i[1] else NA_integer_
  }

  i_out   <- col_idx(paste0("^", tolower(out_col), "$"))
  i_scope <- col_idx("^scope$")
  i_type  <- col_idx("^type$")
  i_subty <- col_idx("^subtype$")
  i_cov   <- col_idx("coverage.*reference")
  i_id    <- col_idx("%?identity.*reference")

  if (any(is.na(c(i_out, i_scope, i_type, i_cov, i_id)))) return(NA_character_)

  outval <- as.character(df[[i_out]])
  scope  <- as.character(df[[i_scope]])
  type_  <- as.character(df[[i_type]])
  subty  <- if (!is.na(i_subty)) as.character(df[[i_subty]]) else rep(NA_character_, length(outval))

  cov_num <- suppressWarnings(readr::parse_number(as.character(df[[i_cov]])))
  id_num  <- suppressWarnings(readr::parse_number(as.character(df[[i_id]])))

  keep <- !is.na(outval) & nzchar(outval) &
    scope == scope_wanted &
    type_ == type_wanted &
    !is.na(cov_num) & cov_num >= 90 &
    !is.na(id_num) & id_num >= 90

  if (!is.null(subtype_wanted)) keep <- keep & !is.na(subty) & subty %in% subtype_wanted

  idx <- which(keep)

  if (!length(idx)) return(NA_character_)

  paste(outval[idx], collapse = ", ")
}

read_fastp_q30 <- function(json_path) {
  if (is.null(json_path) || is.na(json_path) || !file.exists(json_path)) return(NA_real_)

  data <- tryCatch(jsonlite::read_json(json_path), error = function(e) NULL)
  if (is.null(data)) return(NA_real_)

  rate <- data$summary$after_filtering$q30_rate
  if (is.null(rate)) return(NA_real_)

  round(as.numeric(rate) * 100, 2)
}

read_mob_fields <- function(tsv_path) {
  out <- list(
    mobility = NA_character_,
    mpf = NA_character_,
    cluster = NA_character_
  )

  if (!file.exists(tsv_path)) return(out)

  df <- tryCatch(
    readr::read_tsv(tsv_path, show_col_types = FALSE, progress = FALSE),
    error = function(e) NULL
  )

  if (is.null(df) || nrow(df) < 1) return(out)

  nms <- names(df)
  nms_lc <- tolower(nms)

  pick <- function(rx) {
    i <- which(grepl(rx, nms_lc))
    if (length(i)) nms[i[1]] else NA_character_
  }

  col_mob <- pick("^predicted_mobility$|mobility")
  col_mpf <- pick("^mpf_type$|\\bmpf\\b")
  col_clu <- pick("^primary_cluster_id$|primary_cluster")

  if (!is.na(col_mob)) out$mobility <- as.character(df[[col_mob]][1])
  if (!is.na(col_mpf)) out$mpf      <- as.character(df[[col_mpf]][1])
  if (!is.na(col_clu)) out$cluster  <- as.character(df[[col_clu]][1])

  out
}

read_virulencefinder_genes <- function(tsv_path) {
  if (is.na(tsv_path) || !file.exists(tsv_path)) return(NA_character_)

  lines <- readLines(tsv_path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]

  if (length(lines) < 2) return(NA_character_)

  data_lines <- lines[-1]

  genes <- c()

  for (line in data_lines) {
    parts <- strsplit(line, "\t", fixed = TRUE)[[1]]

    if (length(parts) < 4) next

    gene <- trimws(parts[2])
    identity <- suppressWarnings(as.numeric(parts[3]))
    len_field <- trimws(parts[4])

    len_match <- stringr::str_match(len_field, "^\\s*([0-9]+)\\s*/\\s*([0-9]+)\\s*$")

    if (is.na(gene) || gene == "") next
    if (is.na(identity)) next
    if (any(is.na(len_match[1, 2:3]))) next

    query_len <- suppressWarnings(as.numeric(len_match[1, 2]))
    template_len <- suppressWarnings(as.numeric(len_match[1, 3]))

    if (is.na(query_len) || is.na(template_len) || template_len <= 0) next

    coverage <- (query_len / template_len) * 100

    if (identity >= 90 && coverage >= 90) {
      genes <- c(genes, gene)
    }
  }

  genes <- unique(genes)

  if (!length(genes)) return(NA_character_)

  paste(genes, collapse = ", ")
}

get_pipeline_versions <- function(logs_dir) {
  if (logs_dir == "" || !dir.exists(logs_dir)) return(list())

  versions_list <- list()

  v_files <- list.files(logs_dir, pattern = "versions\\.(txt|yml)$", recursive = TRUE, full.names = TRUE)
  db_files <- list.files(logs_dir, pattern = "db_version.txt", recursive = TRUE, full.names = TRUE)

  get_tool_name <- function(path) {
    parts <- unlist(strsplit(dirname(path), .Platform$file.sep))
    tail(parts, 1)
  }

  for (f in v_files) {
    tool_name <- get_tool_name(f)

    if (is.null(versions_list[[tool_name]])) {
      versions_list[[tool_name]] <- list(tool = NA, db = NA)
    }

    if (!is.na(versions_list[[tool_name]]$tool)) next

    lines <- readLines(f, warn = FALSE)

    for (line in lines) {
      if (grepl("^\\s*#", line) || trimws(line) == "") next

      parts <- unlist(strsplit(line, ":", fixed = TRUE))

      if (length(parts) >= 2) {
        key_raw <- trimws(parts[1])
        key_raw <- gsub('["\']', "", key_raw)

        val_raw <- trimws(paste(parts[2:length(parts)], collapse = ":"))
        val_raw <- gsub('["\']', "", val_raw)

        if (val_raw == "") next

        if (!grepl("process", key_raw, ignore.case = TRUE) &&
            !grepl("workflow", key_raw, ignore.case = TRUE) &&
            !grepl("module", key_raw, ignore.case = TRUE) &&
            !grepl("cpus", key_raw, ignore.case = TRUE) &&
            !grepl("memory", key_raw, ignore.case = TRUE) &&
            !grepl("container", key_raw, ignore.case = TRUE)) {
          versions_list[[tool_name]]$tool <- val_raw
          break
        }
      }
    }
  }

  for (f in db_files) {
    tool_name <- get_tool_name(f)

    if (is.null(versions_list[[tool_name]])) {
      versions_list[[tool_name]] <- list(tool = NA, db = NA)
    }

    if (!is.na(versions_list[[tool_name]]$db)) next

    content <- readLines(f, warn = FALSE, n = 1)

    if (length(content) > 0) {
      content <- trimws(content)

      if (tool_name == "Bakta") {
        clean_path <- gsub("Database path used:\\s*", "", content, ignore.case = TRUE)
        clean_path <- trimws(clean_path)
        bakta_json_path <- file.path(clean_path, "version.json")

        if (file.exists(bakta_json_path)) {
          tryCatch({
            bk <- jsonlite::read_json(bakta_json_path)
            content <- sprintf("v%s.%s %s (%s)", bk$major, bk$minor, bk$type, bk$date)
          }, error = function(e) {
            content <- paste(content, "(JSON Error)")
          })
        }
      }

      versions_list[[tool_name]]$db <- content
    }
  }

  final_v <- list()

  for (t in names(versions_list)) {
    entry <- versions_list[[t]]
    str <- ""

    if (!is.na(entry$tool)) str <- paste0(entry$tool)

    if (!is.na(entry$db)) {
      if (str != "") {
        str <- paste0(str, " (DB: ", entry$db, ")")
      } else {
        str <- paste0("DB: ", entry$db)
      }
    }

    if (str != "") final_v[[t]] <- str
  }

  final_v
}

final_columns <- c(
  "Lab ID", "Original ID", "Index", "Platform",
  "Contig Number", "Circular Contigs", "Genome Length", "N50", "Depth", "Q30%",
  "GC content", "Largest Contig",
  "Expected Organism",
  "Detected Organism", "Detection (rMLST)", "ST", "Clonal Complex",
  "Plasmid (PlasmidFinder)",
  "Mobility (MOBTyper)",
  "MPF (MOBTyper)",
  "Cluster (MOBTyper)",
  "ARGs (>90% cov, >90% ID, AMRFinderPlus)",
  "Point Mutations",
  "Predicted Phenotype",
  "Virulence Genes (>90% cov, >90% ID, AMRFinderPlus)",
  "Virulence Genes (>90% cov, >90% ID, VirulenceFinder)",
  "Comments"
)

sample_df <- readr::read_csv(SAMPLE_SHEET, show_col_types = FALSE, progress = FALSE, trim_ws = TRUE)

if (!"Comments" %in% names(sample_df)) {
  sample_df$Comments <- ""
}

if (!"Expected_Organism" %in% names(sample_df)) {
  sample_df$Expected_Organism <- ""
}

base_part <- sample_df %>%
  transmute(
    Lab_ID,
    Original_ID,
    Index,
    Platform,
    Expected_Organism = ifelse(
      is.na(Expected_Organism) | Expected_Organism == "",
      "N/A (Unknown)",
      Expected_Organism
    ),
    Comments
  )

quast_part <- purrr::map_dfr(base_part$Lab_ID, function(iso_id) {
  tsv <- find_isolate_file(QUAST_DIR, iso_id, suffix_regex = ".*\\.tsv$")
  met <- read_quast_metrics(tsv)

  quast_map <- c(
    "# contigs" = "Contig Number",
    "Total length" = "Genome Length",
    "N50" = "N50",
    "Avg. coverage depth" = "Depth",
    "GC (%)" = "GC content",
    "Largest contig" = "Largest Contig"
  )

  vals <- setNames(vector("list", length(quast_map)), unname(quast_map))

  for (k in names(quast_map)) {
    vals[[quast_map[[k]]]] <- met[[k]]
  }

  tibble::as_tibble(vals)
})

platform_col <- base_part %>%
  transmute(Platform = Platform)

circular_contigs_col <- tibble(`Circular Contigs` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  platform <- base_part %>%
    filter(Lab_ID == iso_id) %>%
    pull(Platform) %>%
    first()

  platform_search <- ifelse(is.na(platform) || platform == "", NULL, platform)

  candidate <- find_isolate_file(
    ASSEMBLY_DIR,
    iso_id,
    suffix_regex = "ASSEMBLY_INFO",
    platform = platform_search
  )

  if (is.na(candidate) || !file.exists(candidate)) return(NA_character_)

  read_assembly_info_circular_count(candidate)
}))

q30_col <- tibble(`Q30%` = purrr::map_dbl(base_part$Lab_ID, function(iso_id) {
  json_file <- find_isolate_file(FASTP_DIR, iso_id, suffix_regex = ".*\\.json$")
  read_fastp_q30(json_file)
}))

org_col <- tibble(`Detected Organism` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  tsv <- find_isolate_file(RMLST_DIR, iso_id, suffix_regex = ".*\\.tsv$")
  read_rmlst_taxon(tsv)
}))

det_col <- tibble(`Detection (rMLST)` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  tsv <- find_isolate_file(RMLST_DIR, iso_id, suffix_regex = ".*\\.tsv$")
  read_rmlst_detection(tsv)
}))

st_col <- tibble(ST = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  tsv <- find_isolate_file(MLST_DIR, iso_id, suffix_regex = ".*\\.tsv$")
  read_mlst_st(tsv)
}))

plasmid_col <- tibble(`Plasmid (PlasmidFinder)` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  tsv <- find_isolate_file(PLASMID_DIR, iso_id, suffix_regex = ".*\\.tsv$")
  read_plasmid_list(tsv)
}))

mobility_col <- tibble(`Mobility (MOBTyper)` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  if (is.null(MOB_DIR) || MOB_DIR == "" || !dir.exists(MOB_DIR)) return(NA_character_)
  tsv <- find_isolate_file(MOB_DIR, iso_id, suffix_regex = ".*\\.tsv$")
  read_mob_fields(tsv)$mobility
}))

mpf_col <- tibble(`MPF (MOBTyper)` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  if (is.null(MOB_DIR) || MOB_DIR == "" || !dir.exists(MOB_DIR)) return(NA_character_)
  tsv <- find_isolate_file(MOB_DIR, iso_id, suffix_regex = ".*\\.tsv$")
  read_mob_fields(tsv)$mpf
}))

cluster_col <- tibble(`Cluster (MOBTyper)` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  if (is.null(MOB_DIR) || MOB_DIR == "" || !dir.exists(MOB_DIR)) return(NA_character_)
  tsv <- find_isolate_file(MOB_DIR, iso_id, suffix_regex = ".*\\.tsv$")
  read_mob_fields(tsv)$cluster
}))

amr_col <- tibble(`ARGs (>90% cov, >90% ID, AMRFinderPlus)` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  txt <- find_isolate_file(AMR_DIR, iso_id, suffix_regex = ".*\\.txt$")
  read_amr_column(
    txt,
    scope_wanted = "core",
    type_wanted = "AMR",
    subtype_wanted = "AMR",
    out_col = "Element symbol"
  )
}))

point_col <- tibble(`Point Mutations` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  txt <- find_isolate_file(AMR_DIR, iso_id, suffix_regex = ".*\\.txt$")
  read_amr_column(
    txt,
    scope_wanted = "core",
    type_wanted = "AMR",
    subtype_wanted = "POINT",
    out_col = "Element symbol"
  )
}))

pred_col <- tibble(`Predicted Phenotype` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  txt <- find_isolate_file(AMR_DIR, iso_id, suffix_regex = ".*\\.txt$")
  read_amr_column(
    txt,
    scope_wanted = "core",
    type_wanted = "AMR",
    subtype_wanted = c("AMR", "POINT"),
    out_col = "Subclass"
  )
}))

vir_col <- tibble(`Virulence Genes (>90% cov, >90% ID, AMRFinderPlus)` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  txt <- find_isolate_file(AMR_DIR, iso_id, suffix_regex = ".*\\.txt$")
  read_amr_column(
    txt,
    scope_wanted = "plus",
    type_wanted = "VIRULENCE",
    subtype_wanted = NULL,
    out_col = "Element symbol"
  )
}))

virulencefinder_col <- tibble(`Virulence Genes (>90% cov, >90% ID, VirulenceFinder)` = purrr::map_chr(base_part$Lab_ID, function(iso_id) {
  if (is.null(VIRULENCE_DIR) || VIRULENCE_DIR == "" || !dir.exists(VIRULENCE_DIR)) {
    return(NA_character_)
  }

  vf_file <- find_isolate_file(
    VIRULENCE_DIR,
    iso_id,
    suffix_regex = ".*\\.(tsv|txt|csv)$"
  )

  read_virulencefinder_genes(vf_file)
}))

clonal_complex_col <- tibble(`Clonal Complex` = NA_character_)

final_report <- bind_cols(
  base_part %>% transmute(`Lab ID` = Lab_ID, `Original ID` = Original_ID, Index),
  platform_col,
  quast_part,
  circular_contigs_col,
  q30_col,
  base_part %>% transmute(`Expected Organism` = Expected_Organism),
  org_col,
  det_col,
  st_col,
  clonal_complex_col,
  plasmid_col,
  mobility_col,
  mpf_col,
  cluster_col,
  amr_col,
  point_col,
  pred_col,
  vir_col,
  virulencefinder_col,
  base_part %>% transmute(Comments)
)

missing_cols <- setdiff(final_columns, names(final_report))

if (length(missing_cols)) {
  final_report[missing_cols] <- NA
}

final_report <- final_report[, final_columns]

final_report <- final_report %>%
  mutate(
    Depth = {
      v <- suppressWarnings(readr::parse_number(as.character(Depth)))
      ifelse(is.na(v), NA_character_, paste0(round(v), "x"))
    },
    `Genome Length` = suppressWarnings(readr::parse_number(as.character(`Genome Length`))),
    `Predicted Phenotype` = {
      sapply(`Predicted Phenotype`, function(x) {
        if (is.na(x) || !nzchar(x)) return(NA_character_)

        parts <- strsplit(x, ", ")[[1]]
        parts <- trimws(parts)
        parts <- parts[nzchar(parts)]

        if (!length(parts)) return(NA_character_)

        seen <- character()

        uniq <- vapply(parts, function(p) {
          if (!(p %in% seen)) {
            seen <<- c(seen, p)
            TRUE
          } else {
            FALSE
          }
        }, logical(1))

        paste(parts[uniq], collapse = ", ")
      })
    },
    `Circular Contigs` = {
      sapply(`Circular Contigs`, function(x) {
        if (is.na(x) || x == "" || x == "NA") "0" else x
      })
    },
    `Detection (rMLST)` = {
      v <- suppressWarnings(readr::parse_number(as.character(`Detection (rMLST)`)))
      ifelse(is.na(v), NA_character_, paste0(round(v), "%"))
    },
    GC_num = suppressWarnings(as.numeric(gsub("%", "", `GC content`))),
    N50_formatted = {
      v <- suppressWarnings(as.numeric(N50))
      ifelse(is.na(v), NA_character_, format(v, big.mark = ","))
    }
  ) %>%
  mutate(
    N50 = N50_formatted,
    `GC content` = ifelse(is.na(GC_num), NA_character_, paste0(round(GC_num, 1), "%"))
  ) %>%
  select(-GC_num, -N50_formatted)

calculate_stats <- function(report, logs_dir) {
  found_versions <- get_pipeline_versions(logs_dir)

  list(
    total_samples = nrow(report),
    depth_high = sum(sapply(report$Depth, function(x) {
      num <- suppressWarnings(as.numeric(gsub("x", "", x)))
      !is.na(num) && num > 30
    }), na.rm = TRUE),
    circular_contigs = sum(sapply(report$`Circular Contigs`, function(x) {
      num <- suppressWarnings(as.numeric(x))
      !is.na(num) && num > 0
    }), na.rm = TRUE),
    platforms = length(unique(na.omit(report$Platform))),
    platform_value = unique(na.omit(report$Platform))[1],
    versions = found_versions
  )
}

stats <- calculate_stats(final_report, LOGS_DIR)

final_report_json <- as.data.frame(final_report)
final_report_json[is.na(final_report_json)] <- ""

json_data_file <- file.path(BASE_DIR, "report_data.json")
write_json(final_report_json, json_data_file, pretty = TRUE)

json_stats_file <- file.path(BASE_DIR, "report_stats.json")
write_json(stats, json_stats_file, pretty = TRUE)

out_xlsx <- file.path(BASE_DIR, "final_report_complete.xlsx")

wb <- createWorkbook()
addWorksheet(wb, "Final Report")

final_report_excel <- final_report %>%
  mutate(`Genome Length` = sapply(`Genome Length`, function(x) {
    if (is.na(x) || x == "") return("")
    sprintf("%.2f Mbps", as.numeric(x) / 1e6)
  })) %>%
  mutate(`Q30%` = sapply(`Q30%`, function(x) {
    if (is.na(x) || x == "") return("")
    paste0(x, "%")
  }))

writeData(wb, "Final Report", as.data.frame(final_report_excel), rowNames = FALSE)
saveWorkbook(wb, out_xlsx, overwrite = TRUE)

r_script_dir <- dirname(sub(
  "--file=",
  "",
  commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))]
))

if (length(r_script_dir) == 0) r_script_dir <- getwd()

js_file <- file.path(r_script_dir, "generate_html.js")

if (file.exists(js_file)) {
  js_command <- sprintf(
    'node "%s" "%s" "%s" "%s"',
    js_file,
    BASE_DIR,
    json_data_file,
    json_stats_file
  )

  system(js_command, wait = TRUE)
} else {
  cat("JS file not found.\n")
}

cat("Done.\n")