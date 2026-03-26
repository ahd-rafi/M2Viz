library(jsonlite)
library(limma)
library(trackViewer)
library(GenomicRanges)
library(plumber)
library(base64enc)

# ─────────────────────────────────────────────────────────────────────────────
# Helper: read CSV from a base64-encoded string
# ─────────────────────────────────────────────────────────────────────────────
read_csv_from_b64 <- function(b64_string) {
  raw_bytes <- base64decode(b64_string)
  csv_text  <- rawToChar(raw_bytes)
  read.csv(text = csv_text, stringsAsFactors = FALSE)
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: parse conf (features)
# ─────────────────────────────────────────────────────────────────────────────
parse_conf <- function(conf) {
  parsed <- tryCatch(fromJSON(toJSON(conf), flatten = TRUE), error = function(e) NULL)
  if (is.null(parsed) || length(parsed) == 0 ||
      (is.data.frame(parsed) && nrow(parsed) == 0)) {
    return(data.frame(
      Accession         = character(0),
      start             = integer(0),
      end               = integer(0),
      type              = character(0),
      description       = character(0),
      `Sequence Length` = integer(0),
      check.names = FALSE
    ))
  }
  return(parsed)
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: safely parse seq_len param (plumber passes everything as string)
# ─────────────────────────────────────────────────────────────────────────────
parse_seq_len <- function(seq_len) {
  if (is.null(seq_len)) return(NULL)
  val <- suppressWarnings(as.numeric(trimws(as.character(seq_len))))
  if (length(val) == 0 || is.na(val) || val <= 0) return(NULL)
  return(val)
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: render lolliplot to SVG string and inject tooltip <desc> tag
# ─────────────────────────────────────────────────────────────────────────────
render_svg_with_tooltips <- function(plot_expr, w, h, tooltip_df, mar_vec = c(4,4,3,22)) {
  tmp <- tempfile(fileext = ".svg")
  on.exit(unlink(tmp))

  svg(tmp, width = w, height = h)
  par(mar = mar_vec, oma = c(0,0,0,0))
  force(plot_expr)
  dev.off()

  svg_text <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  json_str <- toJSON(tooltip_df, auto_unbox = TRUE)

  svg_text <- sub(
    "(<svg[^>]*>)",
    paste0("\\1\n<desc id=\"tooltip-data\">",
           gsub("<", "&lt;", gsub(">", "&gt;", json_str)),
           "</desc>"),
    svg_text
  )
  svg_text
}

# ─────────────────────────────────────────────────────────────────────────────
# Limma batch correction
# ─────────────────────────────────────────────────────────────────────────────
#* @post /limma_batch
#* @param csv_b64
#* @param batches
function(csv_b64, batches) {
  df    <- read_csv_from_b64(csv_b64)
  df_m  <- as.matrix(df)
  btc   <- fromJSON(batches)
  batch <- c(btc)
  removeBatchEffect(df_m, batch)
}

#* @post /limma_diff_calc
#* @param csv_b64
#* @param matrix_li
function(csv_b64, matrix_li) {
  y      <- read_csv_from_b64(csv_b64)
  x2     <- log2(y)
  sample <- fromJSON(matrix_li)
  sample <- unlist(sample)
  sample <- factor(sample)
  designmatrix <- model.matrix(~ 0 + sample)
  something    <- colnames(designmatrix)
  op <- list()
  for (j in something) {
    index_jjj      <- which(something == j)
    contrastmatrix <- matrix(0, nrow = length(something), ncol = 1)
    contrastmatrix[1, 1] <- -1
    contrastmatrix[index_jjj, 1] <- 1
    rownames(contrastmatrix) <- something
    colnames(contrastmatrix) <- paste(j, "-", "samplecontrol")
    fit  <- lmFit(x2, designmatrix)
    fit2 <- contrasts.fit(fit, contrastmatrix)
    fit3 <- eBayes(fit2)
    op   <- append(op, list(fit3$p.value, fit3$coefficient))
  }
  df  <- data.frame(op)
  df1 <- df[, -c(1, 2)]
  return(df1)
}


# ─────────────────────────────────────────────────────────────────────────────
# /get_prot_ptm_prof
# ─────────────────────────────────────────────────────────────────────────────
#* @serializer text
#* @post /get_prot_ptm_prof
#* @param csv_b64
#* @param conf
#* @param seq_len
function(csv_b64, conf, seq_len = NULL, res) {

  cat("DEBUG /get_prot_ptm_prof seq_len received:", deparse(seq_len), "\n")

  ptm_data      <- read_csv_from_b64(csv_b64)
  features_data <- parse_conf(conf)
  has_features  <- nrow(features_data) > 0
  accession_id  <- if (has_features) features_data$Accession[1] else "Unknown"

  parsed_seq_len <- parse_seq_len(seq_len)
  cat("DEBUG parsed_seq_len:", deparse(parsed_seq_len), "\n")

  color_map_feat <- c(
    "Domain"             = "#FF9999",
    "Region"             = "#99CCFF",
    "Compositional bias" = "#27ab9d",
    "Motif"              = "#a26617",
    "Repeat"             = "#4741a0",
    "Coiled coil"        = "#a72fb8"
  )
  color_map_ptm <- c(
    "Phosphorylation" = "#f0b80a",
    "Acetylation"     = "#76448a",
    "Ubiquitination"  = "#DE3163",
    "Methylation"     = "#2E8B57",
    "Sumoylation"     = "#FF6347",
    "Nitrosylation"   = "#4682B4"
  )

  if (has_features) {
    features_df             <- features_data[, c("start","end","type","description"), drop=FALSE]
    features_df$type        <- as.character(features_df$type)
    features_df$description <- as.character(features_df$description)
    feature_numbers         <- seq_len(nrow(features_df))
    feature_mapping         <- paste0(feature_numbers, ": ", features_df$type, " - ", features_df$description)
    seq_length              <- max(features_data$`Sequence Length`, na.rm = TRUE)
  } else {
    features_df     <- data.frame(start=integer(0), end=integer(0), type=character(0), description=character(0))
    feature_numbers <- integer(0)
    feature_mapping <- character(0)
    if (!"PTM_Site" %in% colnames(ptm_data)) stop("Error: 'PTM_Site' column missing.")
    positions  <- as.numeric(gsub("[^0-9]", "", ptm_data$PTM_Site))
    seq_length <- if (!is.null(parsed_seq_len)) parsed_seq_len else max(positions, na.rm = TRUE)
  }

  cat("DEBUG seq_length final:", seq_length, "\n")

  x_margin <- seq_length * 0.05
  x_start  <- max(1 - x_margin, 0)
  x_end    <- seq_length + x_margin

  if (has_features) {
    features_gr <- GRanges(
      seqnames       = "chr1",
      ranges         = IRanges(start = features_df$start, end = features_df$end),
      featureLayerID = features_df$type,
      fill           = color_map_feat[features_df$type],
      featureLabel   = as.character(feature_numbers),
      border         = NA
    )
    mcols(features_gr)$height <- 0.02
    mcols(features_gr)$y     <- -0.1
    names(features_gr)        <- as.character(feature_numbers)
  } else {
    features_gr <- GRanges("chr1", IRanges(start = x_start, end = x_end), fill = "white")
  }

  if (!"PTM_Site" %in% colnames(ptm_data)) stop("Error: 'PTM_Site' column missing.")
  ptm_data$amino_acid <- substr(ptm_data$PTM_Site, 1, 1)
  ptm_data$position   <- as.numeric(substr(ptm_data$PTM_Site, 2, nchar(ptm_data$PTM_Site)))
  if (!"PTM"       %in% colnames(ptm_data)) ptm_data$PTM       <- "Unknown"
  if (!"Frequency" %in% colnames(ptm_data)) ptm_data$Frequency <- 1

  ptm_data$color <- sapply(ptm_data$PTM, function(p)
    if (p %in% names(color_map_ptm)) color_map_ptm[[p]] else "#808080")

  stem_color          <- "#A9A9A9"
  lollis              <- GRanges("chr1", IRanges(ptm_data$position, width=1, names=ptm_data$PTM_Site))
  lollis$color        <- ptm_data$color
  lollis$border       <- stem_color
  lollis$dashline.col <- stem_color
  lollis$score        <- ptm_data$Frequency
  lollis$y0           <- 0

  unique_ptms       <- unique(ptm_data$PTM)
  ptm_legend_colors <- sapply(unique_ptms, function(p)
    if (p %in% names(color_map_ptm)) color_map_ptm[[p]] else "#808080")

  legend_labels <- paste0(unique_ptms)
  legend_colors <- ptm_legend_colors
  if (has_features && length(feature_mapping) > 0) {
    legend_labels <- c(legend_labels, feature_mapping)
    legend_colors <- c(legend_colors, color_map_feat[features_df$type])
  }
  legend_list <- list(
    labels = legend_labels, col = legend_colors, pch = 16,
    title  = if (has_features) "PTMs and Features" else "PTMs",
    cex = 1.0, bty = "n", horiz = FALSE
  )

  tick_space <- ifelse(seq_length<=50,5,ifelse(seq_length<=100,10,
               ifelse(seq_length<=500,50,ifelse(seq_length<=1000,100,ifelse(seq_length<=10000,1000,10000)))))
  xaxis <- seq(0, seq_length, by=tick_space)

  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))

  tooltip_df <- data.frame(
    site      = ptm_data$PTM_Site,
    frequency = ptm_data$Frequency,
    label     = ptm_data$PTM,
    color     = ptm_data$color,
    stringsAsFactors = FALSE
  )

  res$setHeader("Content-Type", "image/svg+xml")
  render_svg_with_tooltips(
    plot_expr = lolliplot(
      lollis, features = features_gr,
      xaxis = xaxis,
      ylab = "Frequency", xlab = "Protein Sequence Position",
      main = sprintf("PTM Profile for %s (Length: %d aa)", accession_id, seq_length),
      col = lollis$color, cex = 0.6, type = "circle",
      featureLayerID = "default", label_on_feature = TRUE,
      lwd = 0.5, yaxis = TRUE, side = "top",
      legend = legend_list, ranges = extended_range
    ),
    w = 25, h = 6, tooltip_df = tooltip_df, mar_vec = c(4,4,3,22)
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# /get_prot_ptm_diff
# ─────────────────────────────────────────────────────────────────────────────
#* @serializer text
#* @post /get_prot_ptm_diff
#* @param csv_b64
#* @param conf
#* @param seq_len
function(csv_b64, conf, seq_len = NULL, res) {

  cat("DEBUG /get_prot_ptm_diff seq_len received:", deparse(seq_len), "\n")

  ptm_data      <- read_csv_from_b64(csv_b64)
  features_data <- parse_conf(conf)
  has_features  <- nrow(features_data) > 0
  accession_id  <- if (has_features) features_data$Accession[1] else "Unknown"

  parsed_seq_len <- parse_seq_len(seq_len)
  cat("DEBUG parsed_seq_len:", deparse(parsed_seq_len), "\n")

  color_map_feat <- c(
    "Domain"             = "#FF9999",
    "Region"             = "#99CCFF",
    "Compositional bias" = "#27ab9d",
    "Motif"              = "#a26617",
    "Repeat"             = "#4741a0",
    "Coiled coil"        = "#a72fb8"
  )
  color_palette <- c(
    "#D81B60","#1E88E5","#FFC107","#004D40",
    "#8E24AA","#43A047","#F57C00","#3949AB",
    "#C0CA33","#00ACC1","#7CB342","#FB8C00",
    "#5E35B1","#039BE5","#546E7A","#6D4C41"
  )

  if (has_features) {
    features_df             <- features_data[, c("start","end","type","description"), drop=FALSE]
    features_df$type        <- as.character(features_df$type)
    features_df$description <- as.character(features_df$description)
    feature_numbers         <- seq_len(nrow(features_df))
    feature_mapping         <- paste0(feature_numbers, ": ", features_df$type, " - ", features_df$description)
    seq_length              <- max(features_data$`Sequence Length`, na.rm = TRUE)
  } else {
    features_df     <- data.frame(start=integer(0), end=integer(0), type=character(0), description=character(0))
    feature_numbers <- integer(0)
    feature_mapping <- character(0)
    if (!"PTM_Site" %in% colnames(ptm_data)) stop("Error: 'PTM_Site' column missing.")
    positions  <- as.numeric(gsub("[^0-9]", "", ptm_data$PTM_Site))
    seq_length <- if (!is.null(parsed_seq_len)) parsed_seq_len else max(positions, na.rm = TRUE)
  }

  cat("DEBUG seq_length final:", seq_length, "\n")

  x_margin <- seq_length * 0.05
  x_start  <- max(1 - x_margin, 0)
  x_end    <- seq_length + x_margin

  if (has_features) {
    features_gr <- GRanges(
      seqnames       = "chr1",
      ranges         = IRanges(start = features_df$start, end = features_df$end),
      featureLayerID = features_df$type,
      fill           = color_map_feat[features_df$type],
      featureLabel   = as.character(feature_numbers),
      border         = NA
    )
    mcols(features_gr)$height <- 0.02
    mcols(features_gr)$y     <- -0.1
    names(features_gr)        <- as.character(feature_numbers)
  } else {
    features_gr <- GRanges("chr1", IRanges(start = x_start, end = x_end), fill = "white")
  }

  if (!"PTM_Site" %in% colnames(ptm_data)) stop("Error: 'PTM_Site' column missing.")
  ptm_data$position   <- as.numeric(gsub("[^0-9]", "", ptm_data$PTM_Site))
  ptm_data$amino_acid <- substr(ptm_data$PTM_Site, 1, 1)
  if (!"PTM"        %in% colnames(ptm_data)) ptm_data$PTM        <- "Unknown"
  if (!"Frequency"  %in% colnames(ptm_data)) ptm_data$Frequency  <- 1
  if (!"Regulation" %in% colnames(ptm_data)) ptm_data$Regulation <- "Unknown"

  unique_ptms   <- unique(ptm_data$PTM)
  ptm_color_map <- setNames(color_palette[1:min(length(unique_ptms), length(color_palette))], unique_ptms)
  ptm_data$color <- sapply(ptm_data$PTM, function(p)
    if (p %in% names(ptm_color_map)) ptm_color_map[[p]] else "#808080")

  stem_color          <- "#A9A9A9"
  lollis              <- GRanges("chr1", IRanges(ptm_data$position, width=1, names=ptm_data$PTM_Site))
  lollis$color        <- ptm_data$color
  lollis$border       <- stem_color
  lollis$dashline.col <- stem_color
  lollis$score        <- ptm_data$Frequency
  lollis$SNPsideID    <- ifelse(ptm_data$Regulation == "Upregulation", "top", "bottom")

  tick_space <- ifelse(seq_length<=50,5,ifelse(seq_length<=100,10,
               ifelse(seq_length<=500,50,ifelse(seq_length<=1000,100,ifelse(seq_length<=10000,1000,10000)))))
  xaxis    <- seq(0, seq_length, by=tick_space)
  roundup  <- function(x) ceiling(x/10)*10
  max_freq <- roundup(max(ptm_data$Frequency))
  yaxis    <- as.integer(seq(0,1,by=0.2)*max_freq)

  ptm_legend_colors <- sapply(unique_ptms, function(p)
    if (p %in% names(ptm_color_map)) ptm_color_map[[p]] else "#808080")
  legend_labels <- paste0(unique_ptms)
  legend_colors <- ptm_legend_colors
  if (has_features && length(feature_mapping) > 0) {
    legend_labels <- c(legend_labels, feature_mapping)
    legend_colors <- c(legend_colors, color_map_feat[features_df$type])
  }
  legend_list <- list(
    labels = legend_labels, col = legend_colors, pch = 16,
    title  = if (has_features) "PTMs and Features" else "PTMs",
    cex = 1.0, bty = "n", horiz = FALSE
  )

  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))

  tooltip_df <- data.frame(
    site       = ptm_data$PTM_Site,
    frequency  = ptm_data$Frequency,
    label      = ptm_data$PTM,
    color      = ptm_data$color,
    regulation = ptm_data$Regulation,
    stringsAsFactors = FALSE
  )

  res$setHeader("Content-Type", "image/svg+xml")
  render_svg_with_tooltips(
    plot_expr = lolliplot(
      lollis, features = features_gr,
      xaxis = xaxis, yaxis = yaxis,
      main = sprintf("PTM Regulation Profile for %s (Length: %d aa)", accession_id, seq_length),
      col = lollis$color, cex = 0.6, type = "circle",
      featureLayerID = "default", label_on_feature = TRUE, lwd = 0.5,
      ylab = "Downregulation                                            Upregulation",
      xlab = "Protein Sequence Position",
      legend = legend_list, ranges = extended_range
    ),
    w = 25, h = 12, tooltip_df = tooltip_df, mar_vec = c(4,4,3,22)
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# /get_prot_saav_prof
# ─────────────────────────────────────────────────────────────────────────────
#* @serializer text
#* @post /get_prot_saav_prof
#* @param csv_b64
#* @param conf
#* @param seq_len
function(csv_b64, conf, seq_len = NULL, res) {

  cat("DEBUG /get_prot_saav_prof seq_len received:", deparse(seq_len), "\n")

  saav_data     <- read_csv_from_b64(csv_b64)
  features_data <- parse_conf(conf)
  has_features  <- nrow(features_data) > 0
  accession_id  <- if (has_features) features_data$Accession[1] else "Unknown"

  parsed_seq_len <- parse_seq_len(seq_len)
  cat("DEBUG parsed_seq_len:", deparse(parsed_seq_len), "\n")

  color_map_feat <- c(
    "Domain"             = "#FF9999",
    "Region"             = "#99CCFF",
    "Compositional bias" = "#27ab9d",
    "Motif"              = "#a26617",
    "Repeat"             = "#4741a0",
    "Coiled coil"        = "#a72fb8"
  )

  if (has_features) {
    features_df             <- features_data[, c("start","end","type","description"), drop=FALSE]
    features_df$type        <- as.character(features_df$type)
    features_df$description <- as.character(features_df$description)
    feature_numbers         <- seq_len(nrow(features_df))
    feature_mapping         <- paste0(feature_numbers, ": ", features_df$type, " - ", features_df$description)
    seq_length              <- max(features_data$`Sequence Length`, na.rm = TRUE)
  } else {
    features_df     <- data.frame(start=integer(0), end=integer(0), type=character(0), description=character(0))
    feature_numbers <- integer(0)
    feature_mapping <- character(0)
    if (!"SAAV_Site" %in% colnames(saav_data)) stop("Error: 'SAAV_Site' column missing.")
    positions  <- as.numeric(substr(saav_data$SAAV_Site, 2, nchar(saav_data$SAAV_Site)-1))
    seq_length <- if (!is.null(parsed_seq_len)) parsed_seq_len else max(positions, na.rm = TRUE)
  }

  cat("DEBUG seq_length final:", seq_length, "\n")

  x_margin <- seq_length * 0.05
  x_start  <- max(1 - x_margin, 0)
  x_end    <- seq_length + x_margin

  if (has_features) {
    features_gr <- GRanges(
      seqnames       = "chr1",
      ranges         = IRanges(start = features_df$start, end = features_df$end),
      featureLayerID = features_df$type,
      fill           = color_map_feat[features_df$type],
      featureLabel   = as.character(feature_numbers),
      border         = NA
    )
    mcols(features_gr)$height <- 0.02
    mcols(features_gr)$y     <- -0.1
    names(features_gr)        <- as.character(feature_numbers)
  } else {
    features_gr <- GRanges("chr1", IRanges(start = x_start, end = x_end), fill = "white")
  }

  if (!"SAAV_Site" %in% colnames(saav_data)) stop("Error: 'SAAV_Site' column missing.")
  saav_data$original_aa <- substr(saav_data$SAAV_Site, 1, 1)
  saav_data$variant_aa  <- substr(saav_data$SAAV_Site, nchar(saav_data$SAAV_Site), nchar(saav_data$SAAV_Site))
  saav_data$position    <- as.numeric(substr(saav_data$SAAV_Site, 2, nchar(saav_data$SAAV_Site)-1))
  if (!"Frequency" %in% colnames(saav_data)) saav_data$Frequency <- 1

  saav_color <- "#2E8B57"; stem_color <- "#A9A9A9"
  saav_data$color <- saav_color

  lollis              <- GRanges("chr1", IRanges(saav_data$position, width=1, names=saav_data$SAAV_Site), shape="diamond")
  lollis$color        <- saav_data$color
  lollis$border       <- stem_color
  lollis$dashline.col <- stem_color
  lollis$score        <- saav_data$Frequency
  lollis$y0           <- 0.05

  legend_labels <- "Single Amino Acid Variants (SAAVs)"
  legend_colors <- saav_color
  if (has_features && length(feature_mapping) > 0) {
    legend_labels <- c(legend_labels, feature_mapping)
    legend_colors <- c(legend_colors, color_map_feat[features_df$type])
  }
  legend_list <- list(
    labels = legend_labels, col = legend_colors, pch = 16,
    title  = if (has_features) "SAAVs and Features" else "SAAVs",
    cex = 1.0, bty = "n", horiz = FALSE
  )

  tick_space <- ifelse(seq_length<=50,5,ifelse(seq_length<=100,10,
               ifelse(seq_length<=500,50,ifelse(seq_length<=1000,100,ifelse(seq_length<=10000,1000,10000)))))
  xaxis <- seq(0, seq_length, by=tick_space)

  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))

  tooltip_df <- data.frame(
    site      = saav_data$SAAV_Site,
    frequency = saav_data$Frequency,
    label     = "SAAV",
    color     = saav_data$color,
    stringsAsFactors = FALSE
  )

  res$setHeader("Content-Type", "image/svg+xml")
  render_svg_with_tooltips(
    plot_expr = lolliplot(
      lollis, features = features_gr,
      xaxis = xaxis,
      ylab = "Frequency", xlab = "Protein Sequence Position",
      main = sprintf("SAAV Profile for %s (Length: %d aa)", accession_id, seq_length),
      col = lollis$color, cex = 0.6,
      featureLayerID = "default", label_on_feature = TRUE,
      lwd = 0.5, yaxis = TRUE, side = "top",
      legend = legend_list, ranges = extended_range
    ),
    w = 25, h = 6, tooltip_df = tooltip_df, mar_vec = c(4,4,3,22)
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# /get_prot_saav_diff
# ─────────────────────────────────────────────────────────────────────────────
#* @serializer text
#* @post /get_prot_saav_diff
#* @param csv_b64
#* @param conf
#* @param seq_len
function(csv_b64, conf, seq_len = NULL, res) {

  cat("DEBUG /get_prot_saav_diff seq_len received:", deparse(seq_len), "\n")

  saav_data     <- read_csv_from_b64(csv_b64)
  features_data <- parse_conf(conf)
  has_features  <- nrow(features_data) > 0
  accession_id  <- if (has_features) features_data$Accession[1] else "Unknown"

  parsed_seq_len <- parse_seq_len(seq_len)
  cat("DEBUG parsed_seq_len:", deparse(parsed_seq_len), "\n")

  color_map_feat <- c(
    "Domain"             = "#FF9999",
    "Region"             = "#99CCFF",
    "Compositional bias" = "#27ab9d",
    "Motif"              = "#a26617",
    "Repeat"             = "#4741a0",
    "Coiled coil"        = "#a72fb8"
  )
  saav_color <- "#2E8B57"

  if (has_features) {
    features_df             <- features_data[, c("start","end","type","description"), drop=FALSE]
    features_df$type        <- as.character(features_df$type)
    features_df$description <- as.character(features_df$description)
    feature_numbers         <- seq_len(nrow(features_df))
    feature_mapping         <- paste0(feature_numbers, ": ", features_df$type, " - ", features_df$description)
    seq_length              <- max(features_data$`Sequence Length`, na.rm = TRUE)
  } else {
    features_df     <- data.frame(start=integer(0), end=integer(0), type=character(0), description=character(0))
    feature_numbers <- integer(0)
    feature_mapping <- character(0)
    if (!"SAAV_Site" %in% colnames(saav_data)) stop("Error: 'SAAV_Site' column missing.")
    positions  <- as.numeric(substr(saav_data$SAAV_Site, 2, nchar(saav_data$SAAV_Site)-1))
    seq_length <- if (!is.null(parsed_seq_len)) parsed_seq_len else max(positions, na.rm = TRUE)
  }

  cat("DEBUG seq_length final:", seq_length, "\n")

  x_margin <- seq_length * 0.05
  x_start  <- max(1 - x_margin, 0)
  x_end    <- seq_length + x_margin

  if (has_features) {
    features_gr <- GRanges(
      seqnames       = "chr1",
      ranges         = IRanges(start = features_df$start, end = features_df$end),
      featureLayerID = features_df$type,
      fill           = color_map_feat[features_df$type],
      featureLabel   = as.character(feature_numbers),
      border         = NA
    )
    mcols(features_gr)$height <- 0.02
    mcols(features_gr)$y     <- -0.1
    names(features_gr)        <- as.character(feature_numbers)
  } else {
    features_gr <- GRanges("chr1", IRanges(start = x_start, end = x_end), fill = "white")
  }

  if (!"SAAV_Site" %in% colnames(saav_data)) stop("Error: 'SAAV_Site' column missing.")
  saav_data$position    <- as.numeric(substr(saav_data$SAAV_Site, 2, nchar(saav_data$SAAV_Site)-1))
  saav_data$original_aa <- substr(saav_data$SAAV_Site, 1, 1)
  saav_data$variant_aa  <- substr(saav_data$SAAV_Site, nchar(saav_data$SAAV_Site), nchar(saav_data$SAAV_Site))
  if (!"Frequency"  %in% colnames(saav_data)) saav_data$Frequency  <- 1
  if (!"Regulation" %in% colnames(saav_data)) saav_data$Regulation <- "Unknown"

  stem_color      <- "#A9A9A9"
  saav_data$color <- saav_color

  lollis              <- GRanges("chr1", IRanges(saav_data$position, width=1, names=saav_data$SAAV_Site), shape="diamond")
  lollis$color        <- saav_data$color
  lollis$border       <- stem_color
  lollis$dashline.col <- stem_color
  lollis$score        <- saav_data$Frequency
  lollis$SNPsideID    <- ifelse(saav_data$Regulation == "Upregulation", "top", "bottom")

  tick_space <- ifelse(seq_length<=50,5,ifelse(seq_length<=100,10,
               ifelse(seq_length<=500,50,ifelse(seq_length<=1000,100,ifelse(seq_length<=10000,1000,10000)))))
  xaxis    <- seq(0, seq_length, by=tick_space)
  roundup  <- function(x) ceiling(x/10)*10
  max_freq <- roundup(max(saav_data$Frequency))
  yaxis    <- as.integer(seq(0,1,by=0.2)*max_freq)

  legend_labels <- "SAAV (Single Amino Acid Variant)"
  legend_colors <- saav_color
  if (has_features && length(feature_mapping) > 0) {
    legend_labels <- c(legend_labels, feature_mapping)
    legend_colors <- c(legend_colors, color_map_feat[features_df$type])
  }
  legend_list <- list(
    labels = legend_labels, col = legend_colors, pch = 16,
    title  = if (has_features) "SAAVs and Features" else "SAAVs",
    cex = 1.0, bty = "n", horiz = FALSE
  )

  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))

  tooltip_df <- data.frame(
    site       = saav_data$SAAV_Site,
    frequency  = saav_data$Frequency,
    label      = "SAAV",
    color      = saav_data$color,
    regulation = saav_data$Regulation,
    stringsAsFactors = FALSE
  )

  res$setHeader("Content-Type", "image/svg+xml")
  render_svg_with_tooltips(
    plot_expr = lolliplot(
      lollis, features = features_gr,
      xaxis = xaxis, yaxis = yaxis,
      main = sprintf("SAAV Regulation Profile for %s (Length: %d aa)", accession_id, seq_length),
      col = lollis$color, cex = 0.6, type = "circle",
      featureLayerID = "default", label_on_feature = TRUE, lwd = 0.5,
      ylab = "Downregulation                                            Upregulation",
      xlab = "Protein Sequence Position",
      legend = legend_list, ranges = extended_range
    ),
    w = 25, h = 12, tooltip_df = tooltip_df, mar_vec = c(4,4,3,22)
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# /get_dna_snv_prof
# ─────────────────────────────────────────────────────────────────────────────
#* @serializer text
#* @post /get_dna_snv_prof
#* @param csv_b64
#* @param ax
function(csv_b64, ax, res) {

  ax   <- as.numeric(ax)
  data <- read_csv_from_b64(csv_b64)

  if ("SNV" %in% colnames(data) && "Frequency" %in% colnames(data)) {
    colnames(data)[colnames(data) == "SNV"]       <- "site"
    colnames(data)[colnames(data) == "Frequency"] <- "freq"
  } else if (!("site" %in% colnames(data) && "freq" %in% colnames(data))) {
    stop("Error: Required columns missing.")
  }
  data$position <- as.numeric(gsub("[^0-9]", "", data$site))

  get_dynamic_break_interval <- function(ax) {
    if      (ax <= 10000)  return(2000)
    else if (ax <= 50000)  return(5000)
    else if (ax <= 100000) return(20000)
    else if (ax <= 200000) return(30000)
    else { base <- 10^(floor(log10(ax))-1); return(base*2) }
  }
  break_interval <- get_dynamic_break_interval(ax)

  lollipop_color <- "#f10c0c"; stem_color <- "grey"
  lollis              <- GRanges("chr1", IRanges(data$position, width=1, names=data$site), shape="diamond")
  lollis$color        <- lollipop_color
  lollis$border       <- stem_color
  lollis$dashline.col <- stem_color
  lollis$score        <- data$freq
  lollis$y0           <- 0.05

  x_margin <- ax*0.02; x_start <- max(1-x_margin,0); x_end <- ax+x_margin
  features <- GRanges("chr1", IRanges(start=x_start, end=x_end), fill="white")

  min_freq <- min(data$freq); max_freq <- max(data$freq); y_range <- max_freq-min_freq
  y_step   <- ifelse(y_range<=5,1,ifelse(y_range<=20,2,ifelse(y_range<=50,5,
              ifelse(y_range<=100,10,ifelse(y_range<=500,25,ceiling(y_range/8))))))
  y_start  <- floor(max(0,min_freq-y_range*0.05)/y_step)*y_step
  y_end    <- ceiling((max_freq+y_range*0.15)/y_step)*y_step
  yaxis    <- seq(y_start, y_end, by=y_step)
  xaxis    <- seq(0, ax, by=break_interval)

  legend_list <- list(
    labels = "Single Nucleotide Variations", col = lollipop_color,
    pch = 18, title = "Legend", cex = 1.0, bty = "n", pt.cex = 1.2
  )
  extended_range <- GRanges("chr1", IRanges(start=x_start, end=x_end))

  tooltip_df <- data.frame(
    site      = data$site,
    frequency = data$freq,
    label     = "SNV",
    color     = lollipop_color,
    stringsAsFactors = FALSE
  )

  res$setHeader("Content-Type", "image/svg+xml")
  render_svg_with_tooltips(
    plot_expr = lolliplot(
      lollis, features = features,
      xaxis = xaxis, yaxis = yaxis, cex = 0.4, label.cex = 0.7,
      ylab = "Frequency", xlab = "DNA Sequence Position", main = "SNV Profile",
      col = lollis$color, lwd = 0.5, side = "top", ranges = extended_range
    ),
    w = 25, h = 6, tooltip_df = tooltip_df, mar_vec = c(4,4,3,14)
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# /get_dna_snv_diff
# ─────────────────────────────────────────────────────────────────────────────
#* @serializer text
#* @post /get_dna_snv_diff
#* @param csv_b64
#* @param ax
function(csv_b64, ax, res) {

  ax   <- as.numeric(ax)
  data <- read_csv_from_b64(csv_b64)

  if ("SNV" %in% colnames(data) && "Frequency" %in% colnames(data) && "Expression" %in% colnames(data)) {
    colnames(data)[colnames(data) == "SNV"]        <- "site"
    colnames(data)[colnames(data) == "Frequency"]  <- "freq"
    colnames(data)[colnames(data) == "Expression"] <- "expression"
  } else if (!("site" %in% colnames(data) && "freq" %in% colnames(data) && "expression" %in% colnames(data))) {
    stop("Error: Required columns missing.")
  }
  data$position <- as.numeric(gsub("[^0-9]", "", data$site))

  get_dynamic_break_interval <- function(ax) {
    if      (ax <= 10000)  return(2000)
    else if (ax <= 50000)  return(5000)
    else if (ax <= 100000) return(20000)
    else if (ax <= 200000) return(30000)
    else { base <- 10^(floor(log10(ax))-1); return(base*2) }
  }
  break_interval <- get_dynamic_break_interval(ax)

  over_data  <- data[data$expression == "Overexpressed",  ]
  under_data <- data[data$expression == "Underexpressed", ]
  over_color <- "#D22B2B"; under_color <- "#0A1195"; stem_color <- "grey"

  make_lollis <- function(d, col, side) {
    if (nrow(d) == 0) return(GRanges())
    g <- GRanges("chr1", IRanges(d$position, width=1, names=d$site), shape="diamond")
    g$color <- col; g$border <- stem_color; g$dashline.col <- stem_color
    g$score <- d$freq; g$SNPsideID <- side; g
  }
  lollis_over  <- make_lollis(over_data,  over_color,  "top")
  lollis_under <- make_lollis(under_data, under_color, "bottom")
  all_lollis   <- if (length(lollis_over)>0 && length(lollis_under)>0) c(lollis_over,lollis_under) else if (length(lollis_over)>0) lollis_over else lollis_under

  x_margin <- ax*0.02; x_start <- max(1-x_margin,0); x_end <- ax+x_margin
  features <- GRanges("chr1", IRanges(start=x_start, end=x_end), fill="white")

  max_abs_freq <- max(abs(data$freq))
  y_max_pad    <- max_abs_freq * 1.2
  y_step       <- ifelse(y_max_pad<=10,1,ifelse(y_max_pad<=40,2,ifelse(y_max_pad<=100,5,
                  ifelse(y_max_pad<=200,10,ifelse(y_max_pad<=1000,25,ceiling(y_max_pad/10))))))
  yaxis <- seq(0, ceiling(y_max_pad/y_step)*y_step, by=y_step)
  xaxis <- seq(0, ax, by=break_interval)

  legend_labels <- c(); legend_colors <- c()
  if (nrow(over_data)>0)  { legend_labels <- c(legend_labels,"Overexpressed");  legend_colors <- c(legend_colors,over_color)  }
  if (nrow(under_data)>0) { legend_labels <- c(legend_labels,"Underexpressed"); legend_colors <- c(legend_colors,under_color) }
  legend_list <- list(labels=legend_labels, col=legend_colors, pch=rep(18,length(legend_labels)),
                      title="Expression Level", cex=1.0, bty="n", pt.cex=1.2)

  extended_range <- GRanges("chr1", IRanges(start=x_start, end=x_end))

  tooltip_df <- data.frame(
    site       = data$site,
    frequency  = data$freq,
    label      = ifelse(data$expression == "Overexpressed", "Overexpressed", "Underexpressed"),
    color      = ifelse(data$expression == "Overexpressed", over_color, under_color),
    regulation = data$expression,
    stringsAsFactors = FALSE
  )

  res$setHeader("Content-Type", "image/svg+xml")
  render_svg_with_tooltips(
    plot_expr = lolliplot(
      all_lollis, features = features,
      xaxis = xaxis, yaxis = yaxis, cex = 0.6, label.cex = 0.7,
      ylab = "Underexpressed                                          Overexpressed",
      xlab = "DNA Sequence Position", main = "SNV Differential Expression Profile",
      col = all_lollis$color, lwd = 0.5, ranges = extended_range
    ),
    w = 25, h = 8, tooltip_df = tooltip_df, mar_vec = c(4,4,8,14)
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# /get_dna_methy_prof
# ─────────────────────────────────────────────────────────────────────────────
#* @serializer text
#* @post /get_dna_methy_prof
#* @param csv_b64
#* @param ax
function(csv_b64, ax, res) {

  ax   <- as.numeric(ax)
  data <- read_csv_from_b64(csv_b64)

  if ("Methylation_Site" %in% colnames(data) && "Frequency" %in% colnames(data)) {
    colnames(data)[colnames(data) == "Methylation_Site"] <- "site"
    colnames(data)[colnames(data) == "Frequency"]        <- "freq"
  } else if ("SNV" %in% colnames(data) && "Frequency" %in% colnames(data)) {
    colnames(data)[colnames(data) == "SNV"]       <- "site"
    colnames(data)[colnames(data) == "Frequency"] <- "freq"
  } else if (!("site" %in% colnames(data) && "freq" %in% colnames(data))) {
    stop("Error: Required columns missing.")
  }
  data$position <- as.numeric(gsub("[^0-9]", "", data$site))

  get_dynamic_break_interval <- function(ax) {
    if      (ax <= 10000)  return(2000)
    else if (ax <= 50000)  return(5000)
    else if (ax <= 100000) return(20000)
    else if (ax <= 200000) return(30000)
    else { base <- 10^(floor(log10(ax))-1); return(base*2) }
  }
  break_interval <- get_dynamic_break_interval(ax)

  lollipop_color <- "#f10c0c"; stem_color <- "grey"
  lollis              <- GRanges("chr1", IRanges(data$position, width=1, names=data$site), shape="diamond")
  lollis$color        <- lollipop_color
  lollis$border       <- stem_color
  lollis$dashline.col <- stem_color
  lollis$score        <- data$freq
  lollis$y0           <- 0.05

  x_margin <- ax*0.02; x_start <- max(1-x_margin,0); x_end <- ax+x_margin
  features <- GRanges("chr1", IRanges(start=x_start, end=x_end), fill="white")

  min_freq <- min(data$freq); max_freq <- max(data$freq); y_range <- max_freq-min_freq
  y_step   <- ifelse(y_range<=5,1,ifelse(y_range<=20,2,ifelse(y_range<=50,5,
              ifelse(y_range<=100,10,ifelse(y_range<=500,25,ceiling(y_range/8))))))
  y_start  <- floor(max(0,min_freq-y_range*0.05)/y_step)*y_step
  y_end    <- ceiling((max_freq+y_range*0.15)/y_step)*y_step
  yaxis    <- seq(y_start, y_end, by=y_step)
  xaxis    <- seq(0, ax, by=break_interval)

  legend_list <- list(labels="Methylation Sites", col=lollipop_color, pch=18,
                      title="Legend", cex=1.0, bty="n", pt.cex=1.2)
  extended_range <- GRanges("chr1", IRanges(start=x_start, end=x_end))

  tooltip_df <- data.frame(
    site      = data$site,
    frequency = data$freq,
    label     = "Methylation",
    color     = lollipop_color,
    stringsAsFactors = FALSE
  )

  res$setHeader("Content-Type", "image/svg+xml")
  render_svg_with_tooltips(
    plot_expr = lolliplot(
      lollis, features = features,
      xaxis = xaxis, yaxis = yaxis, cex = 0.4, label.cex = 0.7,
      ylab = "Frequency", xlab = "DNA Sequence Position", main = "Methylation Profile",
      col = lollis$color, lwd = 0.5, side = "top", ranges = extended_range
    ),
    w = 25, h = 6, tooltip_df = tooltip_df, mar_vec = c(4,4,3,14)
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# /get_dna_methy_diff
# ─────────────────────────────────────────────────────────────────────────────
#* @serializer text
#* @post /get_dna_methy_diff
#* @param csv_b64
#* @param ax
function(csv_b64, ax, res) {

  ax   <- as.numeric(ax)
  data <- read_csv_from_b64(csv_b64)

  if ("Methylation_Site" %in% colnames(data) && "Frequency" %in% colnames(data) && "Expression" %in% colnames(data)) {
    colnames(data)[colnames(data) == "Methylation_Site"] <- "site"
    colnames(data)[colnames(data) == "Frequency"]        <- "freq"
    colnames(data)[colnames(data) == "Expression"]       <- "expression"
  } else if ("SNV" %in% colnames(data) && "Frequency" %in% colnames(data) && "Expression" %in% colnames(data)) {
    colnames(data)[colnames(data) == "SNV"]        <- "site"
    colnames(data)[colnames(data) == "Frequency"]  <- "freq"
    colnames(data)[colnames(data) == "Expression"] <- "expression"
  } else if (!("site" %in% colnames(data) && "freq" %in% colnames(data) && "expression" %in% colnames(data))) {
    stop("Error: Required columns missing.")
  }
  data$position <- as.numeric(gsub("[^0-9]", "", data$site))

  get_dynamic_break_interval <- function(ax) {
    if      (ax <= 10000)  return(2000)
    else if (ax <= 50000)  return(5000)
    else if (ax <= 100000) return(20000)
    else if (ax <= 200000) return(30000)
    else { base <- 10^(floor(log10(ax))-1); return(base*2) }
  }
  break_interval <- get_dynamic_break_interval(ax)

  over_data  <- data[data$expression == "Overexpressed",  ]
  under_data <- data[data$expression == "Underexpressed", ]
  over_color <- "#D22B2B"; under_color <- "#0A1195"; stem_color <- "grey"

  make_lollis <- function(d, col, side) {
    if (nrow(d) == 0) return(GRanges())
    g <- GRanges("chr1", IRanges(d$position, width=1, names=d$site), shape="diamond")
    g$color <- col; g$border <- stem_color; g$dashline.col <- stem_color
    g$score <- d$freq; g$SNPsideID <- side; g
  }
  lollis_over  <- make_lollis(over_data,  over_color,  "top")
  lollis_under <- make_lollis(under_data, under_color, "bottom")
  all_lollis   <- if (length(lollis_over)>0 && length(lollis_under)>0) c(lollis_over,lollis_under) else if (length(lollis_over)>0) lollis_over else lollis_under

  x_margin <- ax*0.02; x_start <- max(1-x_margin,0); x_end <- ax+x_margin
  features <- GRanges("chr1", IRanges(start=x_start, end=x_end), fill="white")

  max_abs_freq <- max(abs(data$freq))
  y_max_pad    <- max_abs_freq * 1.2
  y_step       <- ifelse(y_max_pad<=10,1,ifelse(y_max_pad<=40,2,ifelse(y_max_pad<=100,5,
                  ifelse(y_max_pad<=200,10,ifelse(y_max_pad<=1000,25,ceiling(y_max_pad/10))))))
  yaxis <- seq(0, ceiling(y_max_pad/y_step)*y_step, by=y_step)
  xaxis <- seq(0, ax, by=break_interval)

  legend_labels <- c(); legend_colors <- c()
  if (nrow(over_data)>0)  { legend_labels <- c(legend_labels,"Hypermethylated");  legend_colors <- c(legend_colors,over_color)  }
  if (nrow(under_data)>0) { legend_labels <- c(legend_labels,"Hypomethylated");   legend_colors <- c(legend_colors,under_color) }
  legend_list <- list(labels=legend_labels, col=legend_colors, pch=rep(18,length(legend_labels)),
                      title="Methylation Level", cex=1.0, bty="n", pt.cex=1.2)

  extended_range <- GRanges("chr1", IRanges(start=x_start, end=x_end))

  tooltip_df <- data.frame(
    site       = data$site,
    frequency  = data$freq,
    label      = ifelse(data$expression == "Overexpressed", "Hypermethylated", "Hypomethylated"),
    color      = ifelse(data$expression == "Overexpressed", over_color, under_color),
    regulation = data$expression,
    stringsAsFactors = FALSE
  )

  res$setHeader("Content-Type", "image/svg+xml")
  render_svg_with_tooltips(
    plot_expr = lolliplot(
      all_lollis, features = features,
      xaxis = xaxis, yaxis = yaxis, cex = 0.6, label.cex = 0.7,
      ylab = "Hypomethylation                                     Hypermethylation",
      xlab = "DNA Sequence Position", main = "Methylation Differential Expression Profile",
      col = all_lollis$color, lwd = 0.5, ranges = extended_range
    ),
    w = 25, h = 8, tooltip_df = tooltip_df, mar_vec = c(4,4,8,14)
  )
}