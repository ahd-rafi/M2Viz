library(jsonlite)
library(aws.s3)
library(aws.ec2metadata)
library(limma)
library(trackViewer)
library(GenomicRanges)
library(plumber)

library(dotenv)
dotenv::load_dot_env()
Sys.setenv(
  AWS_ACCESS_KEY_ID = Sys.getenv("S3_ACCESS_ID"),
  AWS_SECRET_ACCESS_KEY = Sys.getenv("S3_SECRET_KEY"),
  AWS_DEFAULT_REGION = Sys.getenv("AWS_DEFAULT_REGION"),
  S3_BUCKET = Sys.getenv("S3_BUCKET")
)

#* @post /remove_batch_effect
#* @param batches
#* @param s3Object
function(batches, s3Object) {
  myfile <- s3read_using(FUN = read.csv, object = s3Object, bucket = Sys.getenv("S3_BUCKET"))
  df <- as.data.frame(myfile)
  df_m <- as.matrix(df)
  btc <- fromJSON(batches)
  batch <- c(btc)
  removeBatchEffect(df_m, batch)
}


#* @post /limma_diff_calc
#* @param matrix_li
#* @param s3Object_for_diff
function(matrix_li, s3Object_for_diff) {
  y <- s3read_using(FUN = read.csv, object = s3Object_for_diff, bucket = Sys.getenv("S3_BUCKET"))
  x2 <- log2(y)
  sample <- fromJSON(matrix_li)
  sample <- unlist(sample)
  sample <- factor(sample)
  designmatrix <- model.matrix(~ 0 + sample)
  
  something <- colnames(designmatrix)
  op <- list()
  
  for (j in something) {
    index_jjj <- which(something == j)
    contrastmatrix <- matrix(0, nrow = length(something), ncol = 1)
    contrastmatrix[1, 1] <- -1
    contrastmatrix[index_jjj, 1] <- 1
    
    rownames(contrastmatrix) <- something
    colnames(contrastmatrix) <- paste(j, "-", "samplecontrol")
    
    fit <- lmFit(x2, designmatrix)
    fit2 <- contrasts.fit(fit, contrastmatrix)
    fit3 <- eBayes(fit2)
    
    op <- append(op, list(fit3$p.value, fit3$coefficient))
  }
  
  df <- data.frame(op)
  df1 <- df[, -c(1, 2)]
  return(df1)
}



#* @serializer svg list(width = 25, height = 10)
#* @post /get_prot_ptm_prof
#* @param object_id
#* @param conf
function(object_id, conf) {
  
  # Load PTM data from S3
  ptm_data <- s3read_using(FUN = read.csv, object = object_id, bucket = Sys.getenv("S3_BUCKET"))
  print("PTM Data loaded from S3:")
  print(head(ptm_data))
  
  # Parse conf data (protein features)
  features_data <- fromJSON(toJSON(conf), flatten = TRUE)
  print("Features data:")
  print(head(features_data))
  
  # Extract accession ID (assuming all features have same accession)
  accession_id <- features_data$Accession[1]
  
  color_map_feat <- c(
    "Domain" = "#FF9999",
    "Region" = "#99CCFF", 
    "Compositional bias" = "#27ab9d",
    "Motif" = "#a26617",
    "Repeat" = "#4741a0",
    "Coiled coil" ="#a72fb8"
  )
  
  # PTM color mapping
  color_map_ptm <- c(
    "Phosphorylation" = "#f0b80a",  # Yellow/Gold
    "Acetylation" = "#76448a",     # Purple  
    "Ubiquitination" = "#DE3163",  # Cherry/Red
    "Methylation" = "#2E8B57",     # Sea Green
    "Sumoylation" = "#FF6347",     # Tomato
    "Nitrosylation" = "#4682B4"   # Steel Blue
  )
  
  # Process features data
  features_df <- features_data[, c("start", "end", "type", "description"), drop = FALSE]
  features_df$type <- as.character(features_df$type)
  features_df$description <- as.character(features_df$description)
  
  # Create numbered labels for features (1, 2, 3, etc.) and mapping for legend
  feature_numbers <- seq_len(nrow(features_df))
  features_df$feature_number <- feature_numbers
  
  # Create feature mapping for legend (number -> type: description)
  feature_mapping <- paste0(feature_numbers, ": ", features_df$type, " - ", features_df$description)
  
  # Get protein sequence length
  seq_length <- max(features_data$`Sequence Length`, na.rm = TRUE)
  
  # Calculate extended x-axis range for better visualization
  x_margin <- seq_length * 0.05  # Add 5% margin on each side
  x_start <- max(1 - x_margin, 0)  # Don't go below 0
  x_end <- seq_length + x_margin
  
  # Create features GRanges with numbered labels
  features_gr <- GRanges(
    seqnames = "chr1",
    ranges = IRanges(start = features_df$start, end = features_df$end),
    featureLayerID = features_df$type,
    fill = color_map_feat[features_df$type],
    featureLabel = as.character(feature_numbers),  # Use numbers instead of descriptions
    border = NA
  )
  mcols(features_gr)$height <- 0.02  # Height of feature blocks
  mcols(features_gr)$y <- -0.1  # Place features below baseline
  
  # Set names to numbers for display on plot
  names(features_gr) <- as.character(feature_numbers)
  
  # Process PTM data
  if (!"PTM_Site" %in% colnames(ptm_data)) {
    stop("Error: 'PTM_Site' column missing in input data.")
  }
  
  # Extract position and amino acid from PTM_Site (e.g., "S88" -> position 88, amino acid "S")
  ptm_data$amino_acid <- substr(ptm_data$PTM_Site, 1, 1)
  ptm_data$position <- as.numeric(substr(ptm_data$PTM_Site, 2, nchar(ptm_data$PTM_Site)))
  
  # Handle PTM column
  if (!"PTM" %in% colnames(ptm_data)) {
    ptm_data$PTM <- "Unknown"
  }
  
  # Handle Frequency column
  if (!"Frequency" %in% colnames(ptm_data)) {
    ptm_data$Frequency <- 1
  }
  
  # Assign colors based on PTM type
  ptm_data$color <- sapply(ptm_data$PTM, function(ptm) {
    if (ptm %in% names(color_map_ptm)) {
      return(color_map_ptm[[ptm]])
    } else {
      return("#808080")  # Gray for unknown PTMs
    }
  })
  
  stem_color <- "#A9A9A9"
  
  # Create GRanges for lollipops (PTMs)
  lollis <- GRanges(
    "chr1", 
    IRanges(ptm_data$position, width = 1, names = ptm_data$PTM_Site)
  )
  lollis$category <- ptm_data$PTM
  lollis$amino_acid <- ptm_data$amino_acid
  lollis$color <- ptm_data$color
  lollis$border <- stem_color  # Lighter color for stems/borders
  lollis$dashline.col <- stem_color  # Lighter color for connecting lines
  lollis$score <- ptm_data$Frequency  # Height based on frequency
  lollis$y0 <- 0  # Lollipop stems start at baseline
  
  # Create comprehensive legend
  # Get unique PTM types and their colors
  unique_ptms <- unique(ptm_data$PTM)
  ptm_legend_colors <- sapply(unique_ptms, function(ptm) {
    if (ptm %in% names(color_map_ptm)) {
      return(color_map_ptm[[ptm]])
    } else {
      return("#808080")
    }
  })
  
  # Combine PTM legend labels and feature mapping
  ptm_labels <- paste0(unique_ptms)
  all_legend_labels <- c(ptm_labels, feature_mapping)
  all_legend_colors <- c(ptm_legend_colors, color_map_feat[features_df$type])
  
  legend_list <- list(
    labels = all_legend_labels,
    col = all_legend_colors,
    pch = 16,
    title = "PTMs and Features",
    cex = 0.7,
    bty = "n",
    horiz = FALSE
  )
  
  # Set plotting parameters with more space for legend
  par(mar = c(5, 4, 4, 20) + 0.1)
  
  # Create extended range for better x-axis visualization
  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))
  
  # Create lollipop plot with extended x-axis
  lp <- lolliplot(
    lollis,
    features = features_gr,
    ylab = "Frequency",
    xlab = "Protein Sequence Position",
    main = sprintf("PTM Profile for %s (Length: %d aa)", accession_id, seq_length),
    col = lollis$color,
    cex = 0.6,
    type = "circle",
    featureLayerID = "default",
    label_on_feature = TRUE,
    lwd = 0.5,
    yaxis = TRUE,
    side = "top",  # Lollipops above baseline
    legend = legend_list,
    ranges = extended_range  # Use extended range for full x-axis coverage
  )
  
  # Add custom y-axis labels if needed
  max_freq <- max(ptm_data$Frequency, na.rm = TRUE)
  y_breaks <- pretty(c(0, max_freq), n = 5)
  
  return(lp)
}


#* @serializer svg list(width = 25, height = 20)
#* @post /get_prot_ptm_diff
#* @param object_id
#* @param conf
function(object_id, conf) {
  
  # Load PTM data from S3
  ptm_data <- s3read_using(FUN = read.csv, object = object_id, bucket = Sys.getenv("S3_BUCKET"))
  print("PTM Data loaded from S3:")
  print(head(ptm_data))
  
  # Parse conf data (protein features)
  features_data <- fromJSON(toJSON(conf), flatten = TRUE)
  print("Features data:")
  print(head(features_data))
  
  # Extract accession ID (assuming all features have same accession)
  accession_id <- features_data$Accession[1]
  
  # Define color maps for features
  color_map_feat <- c(
    "Domain" = "#FF9999",
    "Region" = "#99CCFF", 
    "Compositional bias" = "#27ab9d",
    "Motif" = "#a26617",
    "Repeat" = "#4741a0",
    "Coiled coil" ="#a72fb8"
    
  )
  
  # Enhanced PTM color palette
  color_palette <- c(
    "#D81B60", "#1E88E5", "#FFC107", "#004D40",
    "#8E24AA", "#43A047", "#F57C00", "#3949AB",
    "#C0CA33", "#00ACC1", "#7CB342", "#FB8C00",
    "#5E35B1", "#039BE5", "#546E7A", "#6D4C41"
  )
  
  # Process features data
  features_df <- features_data[, c("start", "end", "type", "description"), drop = FALSE]
  features_df$type <- as.character(features_df$type)
  features_df$description <- as.character(features_df$description)
  
  # Create numbered labels for features (1, 2, 3, etc.) and mapping for legend
  feature_numbers <- seq_len(nrow(features_df))
  features_df$feature_number <- feature_numbers
  
  # Create feature mapping for legend (number -> type: description)
  feature_mapping <- paste0(feature_numbers, ": ", features_df$type, " - ", features_df$description)
  
  
  # Get protein sequence length
  seq_length <- max(features_data$`Sequence Length`, na.rm = TRUE)
  
  # Calculate extended x-axis range for better visualization
  x_margin <- seq_length * 0.05  # Add 5% margin on each side
  x_start <- max(1 - x_margin, 0)  # Don't go below 0
  x_end <- seq_length + x_margin
  
  # Create features GRanges with numbered labels
  features_gr <- GRanges(
    seqnames = "chr1",
    ranges = IRanges(start = features_df$start, end = features_df$end),
    featureLayerID = features_df$type,
    fill = color_map_feat[features_df$type],
    featureLabel = as.character(feature_numbers),  # Use numbers instead of descriptions
    border = NA
  )
  mcols(features_gr)$height <- 0.02  # Height of feature blocks
  mcols(features_gr)$y <- -0.1  # Place features below baseline
  
  # Set names to numbers for display on plot
  names(features_gr) <- as.character(feature_numbers)
  
  # Process PTM data
  if (!"PTM_Site" %in% colnames(ptm_data)) {
    stop("Error: 'PTM_Site' column missing in input data.")
  }
  
  # Extract position from PTM_Site (e.g., "S88" -> 88)
  extract_position <- function(site_string) {
    digits <- gsub("[^0-9]", "", site_string)
    return(as.numeric(digits))
  }
  
  ptm_data$position <- sapply(ptm_data$PTM_Site, extract_position)
  ptm_data$amino_acid <- substr(ptm_data$PTM_Site, 1, 1)
  
  # Handle PTM column
  if (!"PTM" %in% colnames(ptm_data)) {
    ptm_data$PTM <- "Unknown"
  }
  
  # Handle Frequency column
  if (!"Frequency" %in% colnames(ptm_data)) {
    ptm_data$Frequency <- 1
  }
  
  # Handle Regulation column
  if (!"Regulation" %in% colnames(ptm_data)) {
    ptm_data$Regulation <- "Unknown"
  }
  
  # Assign colors based on PTM type
  unique_ptms <- unique(ptm_data$PTM)
  ptm_color_map <- setNames(
    color_palette[1:min(length(unique_ptms), length(color_palette))],
    unique_ptms
  )
  
  # Handle case where there are more PTMs than colors
  if (length(unique_ptms) > length(color_palette)) {
    remaining_ptms <- unique_ptms[(length(color_palette) + 1):length(unique_ptms)]
    recycled_colors <- color_palette[1:length(remaining_ptms)]
    recycled_map <- setNames(recycled_colors, remaining_ptms)
    ptm_color_map <- c(ptm_color_map, recycled_map)
  }
  
  ptm_data$color <- sapply(ptm_data$PTM, function(ptm) {
    if (ptm %in% names(ptm_color_map)) {
      return(ptm_color_map[[ptm]])
    } else {
      return("#808080")  # Gray for unknown PTMs
    }
  })
  
  stem_color <- "#A9A9A9"
  
  # Create GRanges for lollipops (PTMs) with regulation-based positioning
  lollis <- GRanges(
    "chr1", 
    IRanges(ptm_data$position, width = 1, names = ptm_data$PTM_Site)
  )
  lollis$category <- ptm_data$PTM
  lollis$amino_acid <- ptm_data$amino_acid
  lollis$color <- ptm_data$color
  lollis$border <- stem_color  # Lighter color for stems/borders
  lollis$dashline.col <- stem_color  # Lighter color for connecting lines
  lollis$score <- ptm_data$Frequency  # Height based on frequency
  
  # CRITICAL: Set SNPsideID based on Regulation for up/down positioning
  lollis$SNPsideID <- ifelse(ptm_data$Regulation == "Upregulation", "top", "bottom")
  
  # Get protein sequence length
  seq_length <- max(features_data$`Sequence Length`, na.rm = TRUE)
  
  # Calculate axis range and ticks
  min_pos <- min(ptm_data$position)
  max_pos <- max(ptm_data$position)
  
  # Add padding to range
  padding <- max(1, round((max_pos - min_pos) * 0.1))
  range_start <- max(1, min_pos - padding)
  range_end <- max_pos + padding
  
  # Calculate x-axis ticks
  span <- max_pos - min_pos
  if (span <= 10) {
    tick_space <- 1
  } else if (span <= 50) {
    tick_space <- 5
  } else if (span <= 100) {
    tick_space <- 10
  } else if (span <= 500) {
    tick_space <- 50
  } else if (span <= 1000) {
    tick_space <- 100
  } else if (span <= 10000) {
    tick_space <- 1000
  } else {
    tick_space <- 10000
  }
  
  start_tick <- ceiling(min_pos / tick_space) * tick_space
  end_tick <- floor(max_pos / tick_space) * tick_space
  xaxis <- seq(start_tick, end_tick, by = tick_space)
  
  # Calculate y-axis range
  roundup <- function(x) ceiling(x / 10) * 10
  max_freq <- roundup(max(ptm_data$Frequency))
  
  y_breaks <- seq(0, 1, by = 0.2)
  yaxis <- as.integer(y_breaks * max_freq)
  
  # Create comprehensive legend
  # Get unique PTM types and their colors
  unique_ptms <- unique(ptm_data$PTM)
  ptm_legend_colors <- sapply(unique_ptms, function(ptm) {
    if (ptm %in% names(ptm_color_map)) {
      return(ptm_color_map[[ptm]])
    } else {
      return("#808080")
    }
  })
  
  # Combine PTM legend labels and feature mapping
  ptm_labels <- paste0(unique_ptms)
  all_legend_labels <- c(ptm_labels, feature_mapping)
  all_legend_colors <- c(ptm_legend_colors, color_map_feat[features_df$type])
  
  legend_list <- list(
    labels = all_legend_labels,
    col = all_legend_colors,
    pch = 16,
    title = "PTMs and Features",
    cex = 0.6,
    bty = "n",
    horiz = FALSE
  )
  
  # Set plotting parameters with more space for legend
  par(mar = c(5, 4, 4, 20) + 0.1)
  
  # Create extended range for better x-axis visualization
  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))
  
  # Create lollipop plot with regulation-based positioning
  main_title <- sprintf("PTM Regulation Profile for %s (Length: %d aa)", accession_id, seq_length)
  
  lp <- lolliplot(
    lollis,
    features = features_gr,
    xaxis = xaxis,
    yaxis = yaxis,
    main = main_title,
    col = lollis$color,
    cex = 0.6,
    type = "circle",  # Add this parameter
    featureLayerID = "default",  # Add this parameter
    label_on_feature = TRUE,  # Add this critical parameter
    lwd = 0.5,  # Add this parameter
    ylab = "Downregulation                                            Upregulation",  # Add y-axis label
    xlab = "Protein Sequence Position",  # Add x-axis label
    legend = legend_list,
    ranges = extended_range  # Set full range for better x-axis
  )
  
  # Add custom y-axis labels for upregulation/downregulation
  # Get the plot limits to position text properly
  plot_ylim <- par("usr")[3:4]  # Get y-axis limits
  plot_xlim <- par("usr")[1:2]  # Get x-axis limits
  
  
  return(lp)
}



#* @serializer svg list(width = 25, height = 10)
#* @post /get_prot_saav_prof
#* @param object_id
#* @param conf
function(object_id, conf) {
  
  # Load SAAV data from S3
  saav_data <- s3read_using(FUN = read.csv, object = object_id, bucket = Sys.getenv("S3_BUCKET"))
  print("SAAV Data loaded from S3:")
  print(head(saav_data))
  
  # Parse conf data (protein features)
  features_data <- fromJSON(toJSON(conf), flatten = TRUE)
  print("Features data:")
  print(head(features_data))
  
  # Extract accession ID (assuming all features have same accession)
  accession_id <- features_data$Accession[1]
  
  # Define color map for protein features only
  color_map_feat <- c(
    "Domain" = "#FF9999",
    "Region" = "#99CCFF", 
    "Compositional bias" = "#27ab9d",
    "Motif" = "#a26617",
    "Repeat" = "#4741a0",
    "Coiled coil" ="#a72fb8"
    
  )
  
  # Process features data
  features_df <- features_data[, c("start", "end", "type", "description"), drop = FALSE]
  features_df$type <- as.character(features_df$type)
  features_df$description <- as.character(features_df$description)
  
  # Create numbered labels for features (1, 2, 3, etc.) and mapping for legend
  feature_numbers <- seq_len(nrow(features_df))
  features_df$feature_number <- feature_numbers
  
  # Create feature mapping for legend (number -> type: description)
  feature_mapping <- paste0(feature_numbers, ": ", features_df$type, " - ", features_df$description)
  
  # Get protein sequence length
  seq_length <- max(features_data$`Sequence Length`, na.rm = TRUE)
  
  # Calculate extended x-axis range for better visualization
  x_margin <- seq_length * 0.05  # Add 5% margin on each side
  x_start <- max(1 - x_margin, 0)  # Don't go below 0
  x_end <- seq_length + x_margin
  
  # Create features GRanges with numbered labels
  features_gr <- GRanges(
    seqnames = "chr1",
    ranges = IRanges(start = features_df$start, end = features_df$end),
    featureLayerID = features_df$type,
    fill = color_map_feat[features_df$type],
    featureLabel = as.character(feature_numbers),  # Use numbers instead of descriptions
    border = NA
  )
  mcols(features_gr)$height <- 0.02  # Height of feature blocks
  mcols(features_gr)$y <- -0.1  # Place features below baseline
  
  # Set names to numbers for display on plot
  names(features_gr) <- as.character(feature_numbers)
  
  # Process SAAV data
  if (!"SAAV_Site" %in% colnames(saav_data)) {
    stop("Error: 'SAAV_Site' column missing in input data.")
  }
  
  # Extract original amino acid, position, and variant amino acid from SAAV_Site (e.g., "S34A" -> original "S", position 34, variant "A")
  saav_data$original_aa <- substr(saav_data$SAAV_Site, 1, 1)
  saav_data$variant_aa <- substr(saav_data$SAAV_Site, nchar(saav_data$SAAV_Site), nchar(saav_data$SAAV_Site))
  saav_data$position <- as.numeric(substr(saav_data$SAAV_Site, 2, nchar(saav_data$SAAV_Site) - 1))
  
  # Handle Frequency column
  if (!"Frequency" %in% colnames(saav_data)) {
    saav_data$Frequency <- 1
  }
  
  # Use a single color for all SAAVs (you can change this color if desired)
  saav_color <- "#2E8B57"  # Sea Green for lollipop heads
  stem_color <- "#A9A9A9"  # Light green for lollipop stems (lighter version)
  saav_data$color <- saav_color
  
  # Create GRanges for lollipops (SAAVs)
  lollis <- GRanges(
    "chr1", 
    IRanges(saav_data$position, width = 1, names = saav_data$SAAV_Site),
    shape = "diamond",  # Use diamond shape
    
  )
  lollis$category <- "SAAV"
  lollis$original_aa <- saav_data$original_aa
  lollis$variant_aa <- saav_data$variant_aa
  lollis$saav_site <- saav_data$SAAV_Site
  lollis$color <- saav_data$color
  lollis$border <- stem_color  # Lighter color for stems/borders
  lollis$dashline.col <- stem_color  # Lighter color for connecting lines
  lollis$score <- saav_data$Frequency  # Height based on frequency
  lollis$y0 <- 0.05  # Lollipop stems start slightly above baseline
  
  # Get protein sequence length
  seq_length <- max(features_data$`Sequence Length`, na.rm = TRUE)
  
  # Create simplified legend
  # Only include SAAV color and feature mapping
  saav_label <- "Single Amino Acid Variants (SAAVs)"
  all_legend_labels <- c(saav_label, feature_mapping)
  all_legend_colors <- c(saav_color, color_map_feat[features_df$type])
  
  legend_list <- list(
    labels = all_legend_labels,
    col = all_legend_colors,
    pch = 16,
    title = "SAAVs and Features",
    cex = 0.7,
    bty = "n",
    horiz = FALSE
  )
  
  # Set plotting parameters with more space for legend
  par(mar = c(5, 4, 4, 20) + 0.1)
  
  # Create extended range for better x-axis visualization
  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))
  
  # Create lollipop plot
  lp <- lolliplot(
    lollis,
    features = features_gr,
    ylab = "Frequency",
    xlab = "Protein Sequence Position",
    main = sprintf("SAAV Profile for %s (Length: %d aa)", accession_id, seq_length),
    col = lollis$color,
    cex = 0.6,
    featureLayerID = "default",
    label_on_feature = TRUE,
    lwd = 0.5,
    yaxis = TRUE,
    side = "top",  # Lollipops above baseline
    legend = legend_list,
    ranges = extended_range  # Set full range for better x-axis
  )
  
  # Add custom y-axis labels if needed
  max_freq <- max(saav_data$Frequency, na.rm = TRUE)
  y_breaks <- pretty(c(0, max_freq), n = 5)
  
  return(lp)
}



#* @serializer svg list(width = 25, height = 20)
#* @post /get_prot_saav_diff
#* @param object_id
#* @param conf
function(object_id, conf) {
  
  # Load SAAV data from S3
  saav_data <- s3read_using(FUN = read.csv, object = object_id, bucket = Sys.getenv("S3_BUCKET"))
  print("SAAV Data loaded from S3:")
  print(head(saav_data))
  
  # Parse conf data (protein features)
  features_data <- fromJSON(toJSON(conf), flatten = TRUE)
  print("Features data:")
  print(head(features_data))
  
  # Extract accession ID (assuming all features have same accession)
  accession_id <- features_data$Accession[1]
  
  # Define color maps for features
  color_map_feat <- c(
    "Domain" = "#FF9999",
    "Region" = "#99CCFF", 
    "Compositional bias" = "#27ab9d",
    "Motif" = "#a26617",
    "Repeat" = "#4741a0",
    "Coiled coil" ="#a72fb8"
    
  )
  
  # Single color for all SAAVs (no need for multiple colors since no PTM types)
  saav_color <- "#2E8B57"  # Single color for all SAAV variants
  
  # Process features data
  features_df <- features_data[, c("start", "end", "type", "description"), drop = FALSE]
  features_df$type <- as.character(features_df$type)
  features_df$description <- as.character(features_df$description)
  
  # Create numbered labels for features (1, 2, 3, etc.) and mapping for legend
  feature_numbers <- seq_len(nrow(features_df))
  features_df$feature_number <- feature_numbers
  
  # Create feature mapping for legend (number -> type: description)
  feature_mapping <- paste0(feature_numbers, ": ", features_df$type, " - ", features_df$description)
  
  
  # Get protein sequence length
  seq_length <- max(features_data$`Sequence Length`, na.rm = TRUE)
  
  # Calculate extended x-axis range for better visualization
  x_margin <- seq_length * 0.05  # Add 5% margin on each side
  x_start <- max(1 - x_margin, 0)  # Don't go below 0
  x_end <- seq_length + x_margin
  
  # Create features GRanges with numbered labels
  features_gr <- GRanges(
    seqnames = "chr1",
    ranges = IRanges(start = features_df$start, end = features_df$end),
    featureLayerID = features_df$type,
    fill = color_map_feat[features_df$type],
    featureLabel = as.character(feature_numbers),  # Use numbers instead of descriptions
    border = NA
  )
  mcols(features_gr)$height <- 0.02  # Height of feature blocks
  mcols(features_gr)$y <- -0.1  # Place features below baseline
  
  # Set names to numbers for display on plot
  names(features_gr) <- as.character(feature_numbers)
  
  # Process SAAV data
  if (!"SAAV_Site" %in% colnames(saav_data)) {
    stop("Error: 'SAAV_Site' column missing in input data.")
  }
  
  # Extract position from SAAV_Site (e.g., "S34A" -> 34)
  extract_position <- function(site_string) {
    # Remove first and last character, keep the middle numbers
    middle_part <- substr(site_string, 2, nchar(site_string) - 1)
    return(as.numeric(middle_part))
  }
  
  saav_data$position <- sapply(saav_data$SAAV_Site, extract_position)
  saav_data$original_aa <- substr(saav_data$SAAV_Site, 1, 1)  # First character (original amino acid)
  saav_data$variant_aa <- substr(saav_data$SAAV_Site, nchar(saav_data$SAAV_Site), nchar(saav_data$SAAV_Site))  # Last character (variant amino acid)
  
  # Handle Frequency column
  if (!"Frequency" %in% colnames(saav_data)) {
    saav_data$Frequency <- 1
  }
  
  # Handle Regulation column
  if (!"Regulation" %in% colnames(saav_data)) {
    saav_data$Regulation <- "Unknown"
  }
  
  # Assign single color to all SAAVs
  stem_color <- "#A9A9A9"
  saav_data$color <- saav_color
  
  # Create GRanges for lollipops (SAAVs) with regulation-based positioning
  lollis <- GRanges(
    "chr1", 
    IRanges(saav_data$position, width = 1, names = saav_data$SAAV_Site),
    shape = 'diamond'
  )
  lollis$category <- "SAAV"  # Single category for all variants
  lollis$original_aa <- saav_data$original_aa
  lollis$variant_aa <- saav_data$variant_aa
  lollis$color <- saav_data$color
  lollis$border <- stem_color
  lollis$dashline.col <- stem_color  # Lighter color for connecting lines
  lollis$score <- saav_data$Frequency  # Height based on frequency
  
  # CRITICAL: Set SNPsideID based on Regulation for up/down positioning
  lollis$SNPsideID <- ifelse(saav_data$Regulation == "Upregulation", "top", "bottom")
  
  # Get protein sequence length
  seq_length <- max(features_data$`Sequence Length`, na.rm = TRUE)
  
  # Calculate axis range and ticks
  min_pos <- min(saav_data$position)
  max_pos <- max(saav_data$position)
  
  # Add padding to range
  padding <- max(1, round((max_pos - min_pos) * 0.1))
  range_start <- max(1, min_pos - padding)
  range_end <- max_pos + padding
  
  # Calculate x-axis ticks
  span <- max_pos - min_pos
  if (span <= 10) {
    tick_space <- 1
  } else if (span <= 50) {
    tick_space <- 5
  } else if (span <= 100) {
    tick_space <- 10
  } else if (span <= 500) {
    tick_space <- 50
  } else if (span <= 1000) {
    tick_space <- 100
  } else if (span <= 10000) {
    tick_space <- 1000
  } else {
    tick_space <- 10000
  }
  
  start_tick <- ceiling(min_pos / tick_space) * tick_space
  end_tick <- floor(max_pos / tick_space) * tick_space
  xaxis <- seq(start_tick, end_tick, by = tick_space)
  
  # Calculate y-axis range
  roundup <- function(x) ceiling(x / 10) * 10
  max_freq <- roundup(max(saav_data$Frequency))
  
  y_breaks <- seq(0, 1, by = 0.2)
  yaxis <- as.integer(y_breaks * max_freq)
  
  # Create simplified legend
  # Only include SAAV color and feature mapping
  saav_label <- "SAAV (Single Amino Acid Variant)"
  all_legend_labels <- c(saav_label, feature_mapping)
  all_legend_colors <- c(saav_color, color_map_feat[features_df$type])
  
  legend_list <- list(
    labels = all_legend_labels,
    col = all_legend_colors,
    pch = 16,
    title = "SAAVs and Features",
    cex = 0.6,
    bty = "n",
    horiz = FALSE
  )
  
  # Set plotting parameters with more space for legend
  par(mar = c(5, 4, 4, 20) + 0.1)
  
  # Create extended range for better x-axis visualization
  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))
  
  # Create lollipop plot with regulation-based positioning
  main_title <- sprintf("SAAV Regulation Profile for %s (Length: %d aa)", accession_id, seq_length)
  
  lp <- lolliplot(
    lollis,
    features = features_gr,
    xaxis = xaxis,
    yaxis = yaxis,
    main = main_title,
    col = lollis$color,
    cex = 0.6,
    type = "circle",  # Add this parameter
    featureLayerID = "default",  # Add this parameter
    label_on_feature = TRUE,  # Add this critical parameter
    lwd = 0.5,  # Add this parameter
    ylab = "Downregulation                                            Upregulation",  # Add y-axis label
    xlab = "Protein Sequence Position",  # Add x-axis label
    legend = legend_list,
    ranges = extended_range
  )
  
  # Add custom y-axis labels for upregulation/downregulation
  # Get the plot limits to position text properly
  plot_ylim <- par("usr")[3:4]  # Get y-axis limits
  plot_xlim <- par("usr")[1:2]  # Get x-axis limits
  
  
  return(lp)
}





#* @serializer svg list(width = 25, height = 10)
#* @post /get_dna_snv_prof
#* @param object_id
#* @param ax
function(object_id, ax) {
  library(trackViewer)
  library(aws.s3)
  
  ax <- as.numeric(ax)
  print(paste("X-axis limit:", ax))
  
  data <- s3read_using(FUN = read.csv, object = object_id, bucket = Sys.getenv("S3_BUCKET"), stringsAsFactors = FALSE)
  
  print("Data loaded from S3:")
  print(head(data))
  
  if ("SNV" %in% colnames(data) && "Frequency" %in% colnames(data)) {
    colnames(data)[colnames(data) == "SNV"] <- "site"
    colnames(data)[colnames(data) == "Frequency"] <- "freq"
  } else if (!("site" %in% colnames(data) && "freq" %in% colnames(data))) {
    stop("Error: Required columns ('site'/'freq' or 'SNV'/'Frequency') are missing from the input data.")
  }
  
  data$position <- as.numeric(gsub("[^0-9]", "", data$site))
  
  get_dynamic_break_interval <- function(ax) {
    if (ax <= 10000) {
      return(2000)
    } else if (ax <= 50000) {
      return(5000)
    } else if (ax <= 100000) {
      return(20000)
    } else if (ax <= 200000) {
      return(30000)
    } else {
      base <- 10^(floor(log10(ax)) - 1)
      return(base * 2)
    }
  }
  
  break_interval <- get_dynamic_break_interval(ax)
  
  print(paste("ax:", ax, "Break Interval:", break_interval))
  print("Processed data with numeric positions:")
  print(head(data))
  
  SNP <- data$position
  height <- data$freq
  
  # Colors
  lollipop_color <- "#f10c0c"  # Sea Green for lollipop heads
  stem_color <- "grey"         # Grey for stems
  
  # Create GRanges object for lollipops with proper trackViewer structure
  lollis <- GRanges(
    "chr1", 
    IRanges(SNP, width = 1, names = data$site),
    shape = "diamond"  # Diamond shape for lollipops
  )
  
  # Set lollipop properties
  lollis$color <- lollipop_color
  lollis$border <- stem_color        # Grey stems/borders
  lollis$dashline.col <- stem_color  # Grey connecting lines
  lollis$score <- height             # Height based on frequency
  lollis$y0 <- 0.05                 # Lollipop stems start slightly above baseline
  
  # Calculate extended x-axis range for better visualization
  x_margin <- ax * 0.02  # Add 2% margin on each side
  x_start <- max(1 - x_margin, 0)  # Don't go below 0
  x_end <- ax + x_margin
  
  # Create features (the baseline/track)
  features <- GRanges("chr1", IRanges(start = x_start, end = x_end), fill = "white")
  
  # Improved Y-axis range calculation
  min_freq <- min(data$freq)
  max_freq <- max(data$freq)
  
  # Calculate a more appropriate Y-axis range
  y_range <- max_freq - min_freq
  
  # Add some padding (15% on top, 5% on bottom)
  top_padding <- y_range * 0.15
  bottom_padding <- y_range * 0.05
  y_min <- max(0, min_freq - bottom_padding)  # Don't go below 0
  y_max <- max_freq + top_padding
  
  # Create better spaced Y-axis breaks
  if (y_range <= 5) {
    y_step <- 1
  } else if (y_range <= 20) {
    y_step <- 2
  } else if (y_range <= 50) {
    y_step <- 5
  } else if (y_range <= 100) {
    y_step <- 10
  } else if (y_range <= 500) {
    y_step <- 25
  } else {
    y_step <- ceiling(y_range / 8)  # Aim for ~8 breaks
  }
  
  # Generate Y-axis breaks
  y_start <- floor(y_min / y_step) * y_step
  y_end <- ceiling(y_max / y_step) * y_step
  yaxis <- seq(y_start, y_end, by = y_step)
  
  # Generate X-axis breaks
  xaxis <- seq(0, ax, by = break_interval)
  
  print(paste("Y-axis range:", y_min, "to", y_max, "with step:", y_step))
  
  # Create legend
  legend_list <- list(
    labels = c("Single Nucleotide Variations"),
    col = c(lollipop_color),
    pch = c(18),  # Diamond shape symbol
    title = "Legend",
    cex = 0.8,
    bty = "n",
    pt.cex = 1.2
  )
  
  # Set plotting parameters with space for legend
  par(mar = c(5, 4, 4, 12) + 0.1)
  
  # Create extended range for x-axis
  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))
  
  # Create the lollipop plot
  lp <- lolliplot(
    lollis, 
    features = features,
    xaxis = xaxis, 
    yaxis = yaxis, 
    cex = 0.4, 
    label.cex = 0.7,
    ylab = "Frequency",
    xlab = "DNA Sequence Position", 
    main = "SNV Profile",
    col = lollis$color,
    lwd = 0.5,
    side = "top",  # Lollipops above baseline
    ranges = extended_range  # Set full range for x-axis
  )
  
  print("Plot generated with improved Y-axis scaling, grey stems, diamond shapes, and legend.")
  
  return(lp)
}



#* @serializer svg list(width = 25, height = 10)
#* @post /get_dna_snv_diff
#* @param object_id
#* @param ax
function(object_id, ax) {
  
  ax <- as.numeric(ax)
  print(paste("X-axis limit:", ax))
  
  data <- s3read_using(FUN = read.csv, object = object_id, bucket = Sys.getenv("S3_BUCKET"), stringsAsFactors = FALSE)
  
  print("Data loaded from S3:")
  print(head(data))
  
  # Standardize column names
  if ("SNV" %in% colnames(data) && "Frequency" %in% colnames(data) && "Expression" %in% colnames(data)) {
    colnames(data)[colnames(data) == "SNV"] <- "site"
    colnames(data)[colnames(data) == "Frequency"] <- "freq"
    colnames(data)[colnames(data) == "Expression"] <- "expression"
  } else if (!("site" %in% colnames(data) && "freq" %in% colnames(data) && "expression" %in% colnames(data))) {
    stop("Error: Required columns ('site'/'freq'/'expression' or 'SNV'/'Frequency'/'Expression') are missing from the input data.")
  }
  
  # Extract position from site
  data$position <- as.numeric(gsub("[^0-9]", "", data$site))
  
  get_dynamic_break_interval <- function(ax) {
    if (ax <= 10000) {
      return(2000)
    } else if (ax <= 50000) {
      return(5000)
    } else if (ax <= 100000) {
      return(20000)
    } else if (ax <= 200000) {
      return(30000)
    } else {
      base <- 10^(floor(log10(ax)) - 1)
      return(base * 2)
    }
  }
  
  break_interval <- get_dynamic_break_interval(ax)
  
  print(paste("ax:", ax, "Break Interval:", break_interval))
  print("Processed data with numeric positions:")
  print(head(data))
  
  # Separate overexpressed and underexpressed data
  overexpressed_data <- data[data$expression == "Overexpressed", ]
  underexpressed_data <- data[data$expression == "Underexpressed", ]
  
  # Colors
  overexpressed_color <- "#D22B2B"  # Red for overexpressed
  underexpressed_color <- "#0A1195"  # Green for underexpressed
  stem_color <- "grey"               # Grey for stems
  
  # Create GRanges for overexpressed (above baseline)
  if (nrow(overexpressed_data) > 0) {
    lollis_over <- GRanges(
      "chr1", 
      IRanges(overexpressed_data$position, width = 1, names = overexpressed_data$site),
      shape = "diamond"
    )
    lollis_over$color <- overexpressed_color
    lollis_over$border <- stem_color
    lollis_over$dashline.col <- stem_color
    lollis_over$score <- overexpressed_data$freq
    lollis_over$SNPsideID <- "top"  # Above baseline
  } else {
    lollis_over <- GRanges()
  }
  
  # Create GRanges for underexpressed (below x-axis)
  if (nrow(underexpressed_data) > 0) {
    lollis_under <- GRanges(
      "chr1", 
      IRanges(underexpressed_data$position, width = 1, names = underexpressed_data$site),
      shape = "diamond"
    )
    lollis_under$color <- underexpressed_color
    lollis_under$border <- stem_color
    lollis_under$dashline.col <- stem_color
    lollis_under$score <- underexpressed_data$freq
    lollis_under$SNPsideID <- "bottom"  # Below x-axis
  } else {
    lollis_under <- GRanges()
  }
  
  # Combine both GRanges
  if (length(lollis_over) > 0 && length(lollis_under) > 0) {
    all_lollis <- c(lollis_over, lollis_under)
  } else if (length(lollis_over) > 0) {
    all_lollis <- lollis_over
  } else if (length(lollis_under) > 0) {
    all_lollis <- lollis_under
  } else {
    stop("No valid data found for plotting")
  }
  
  # Calculate extended x-axis range for better visualization
  x_margin <- ax * 0.02  # Add 2% margin on each side
  x_start <- max(1 - x_margin, 0)  # Don't go below 0
  x_end <- ax + x_margin
  
  # Create features (the baseline/track)
  features <- GRanges("chr1", IRanges(start = x_start, end = x_end), fill = "white")
  
  # Y-axis range calculation - Handle both sides without negative axis labels
  max_freq <- max(data$freq)
  min_freq <- min(data$freq)
  
  # Use the maximum frequency for both sides, but keep axis labels positive
  max_abs_freq <- max(abs(c(max_freq, min_freq)))
  
  # Add padding (20% on each side)
  padding <- max_abs_freq * 0.2
  y_max <- max_abs_freq + padding
  y_min <- 0  # Keep minimum at 0 for cleaner axis
  
  # Create Y-axis breaks (only positive values shown)
  y_range <- y_max - y_min
  if (y_range <= 10) {
    y_step <- 1
  } else if (y_range <= 40) {
    y_step <- 2
  } else if (y_range <= 100) {
    y_step <- 5
  } else if (y_range <= 200) {
    y_step <- 10
  } else if (y_range <= 1000) {
    y_step <- 25
  } else {
    y_step <- ceiling(y_range / 10)  # Aim for ~10 breaks total
  }
  
  # Generate Y-axis breaks (only positive, but plot will handle negative side internally)
  max_y_break <- ceiling(y_max / y_step) * y_step
  yaxis <- seq(0, max_y_break, by = y_step)
  
  # Generate X-axis breaks
  xaxis <- seq(0, ax, by = break_interval)
  
  print(paste("Y-axis range:", y_min, "to", y_max, "with step:", y_step))
  
  # Create legend with same shapes
  legend_labels <- c()
  legend_colors <- c()
  
  if (nrow(overexpressed_data) > 0) {
    legend_labels <- c(legend_labels, "Overexpressed")
    legend_colors <- c(legend_colors, overexpressed_color)
  }
  
  if (nrow(underexpressed_data) > 0) {
    legend_labels <- c(legend_labels, "Underexpressed")
    legend_colors <- c(legend_colors, underexpressed_color)
  }
  
  legend_list <- list(
    labels = legend_labels,
    col = legend_colors,
    pch = rep(18, length(legend_labels)),  # Diamond shape symbols
    title = "Expression Level",
    cex = 0.8,
    bty = "n",
    pt.cex = 1.2
  )
  
  # Set plotting parameters with space for legend
  par(mar = c(5, 4, 4, 12) + 0.1)
  
  # Create extended range for x-axis
  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))
  
  # Create the lollipop plot
  lp <- lolliplot(
    all_lollis,
    features = features,
    xaxis = xaxis,
    yaxis = yaxis,
    cex = 0.6,
    label.cex = 0.7,
    ylab = "Underexpressed                                          Overexpressed",
    xlab = "DNA Sequence Position",
    main = "SNV Differential Expression Profile",
    col = all_lollis$color,
    lwd = 0.5,
    ranges = extended_range  # Set full range for x-axis
  )
  
  print("Differential expression plot generated with overexpressed above and underexpressed below x-axis, positive Y-axis labels only.")
  
  return(lp)
}




#* @serializer svg list(width = 25, height = 10)
#* @post /get_dna_methy_prof
#* @param object_id
#* @param ax
function(object_id, ax) {
  library(trackViewer)
  library(aws.s3)
  
  ax <- as.numeric(ax)
  print(paste("X-axis limit:", ax))
  
  data <- s3read_using(FUN = read.csv, object = object_id, bucket = Sys.getenv("S3_BUCKET"), stringsAsFactors = FALSE)
  
  print("Data loaded from S3:")
  print(head(data))
  
  # Updated column name handling for methylation data
  if ("Methylation_Site" %in% colnames(data) && "Frequency" %in% colnames(data)) {
    colnames(data)[colnames(data) == "Methylation_Site"] <- "site"
    colnames(data)[colnames(data) == "Frequency"] <- "freq"
  } else if ("SNV" %in% colnames(data) && "Frequency" %in% colnames(data)) {
    # Keep backward compatibility with SNV data
    colnames(data)[colnames(data) == "SNV"] <- "site"
    colnames(data)[colnames(data) == "Frequency"] <- "freq"
  } else if (!("site" %in% colnames(data) && "freq" %in% colnames(data))) {
    stop("Error: Required columns ('site'/'freq', 'Methylation_Site'/'Frequency', or 'SNV'/'Frequency') are missing from the input data.")
  }
  
  data$position <- as.numeric(gsub("[^0-9]", "", data$site))
  
  get_dynamic_break_interval <- function(ax) {
    if (ax <= 10000) {
      return(2000)
    } else if (ax <= 50000) {
      return(5000)
    } else if (ax <= 100000) {
      return(20000)
    } else if (ax <= 200000) {
      return(30000)
    } else {
      base <- 10^(floor(log10(ax)) - 1)
      return(base * 2)
    }
  }
  
  break_interval <- get_dynamic_break_interval(ax)
  
  print(paste("ax:", ax, "Break Interval:", break_interval))
  print("Processed data with numeric positions:")
  print(head(data))
  
  SNP <- data$position
  height <- data$freq
  
  # Colors - Updated for methylation context
  lollipop_color <- "#f10c0c"  # Blue for methylation sites
  stem_color <- "grey"         # Grey for stems
  
  # Create GRanges object for lollipops with proper trackViewer structure
  lollis <- GRanges(
    "chr1", 
    IRanges(SNP, width = 1, names = data$site),
    shape = "diamond"  # Diamond shape for lollipops
  )
  
  # Set lollipop properties
  lollis$color <- lollipop_color
  lollis$border <- stem_color        # Grey stems/borders
  lollis$dashline.col <- stem_color  # Grey connecting lines
  lollis$score <- height             # Height based on frequency
  lollis$y0 <- 0.05                 # Lollipop stems start slightly above baseline
  
  # Calculate extended x-axis range for better visualization
  x_margin <- ax * 0.02  # Add 2% margin on each side
  x_start <- max(1 - x_margin, 0)  # Don't go below 0
  x_end <- ax + x_margin
  
  # Create features (the baseline/track)
  features <- GRanges("chr1", IRanges(start = x_start, end = x_end), fill = "white")
  
  # Improved Y-axis range calculation
  min_freq <- min(data$freq)
  max_freq <- max(data$freq)
  
  # Calculate a more appropriate Y-axis range
  y_range <- max_freq - min_freq
  
  # Add some padding (15% on top, 5% on bottom)
  top_padding <- y_range * 0.15
  bottom_padding <- y_range * 0.05
  y_min <- max(0, min_freq - bottom_padding)  # Don't go below 0
  y_max <- max_freq + top_padding
  
  # Create better spaced Y-axis breaks
  if (y_range <= 5) {
    y_step <- 1
  } else if (y_range <= 20) {
    y_step <- 2
  } else if (y_range <= 50) {
    y_step <- 5
  } else if (y_range <= 100) {
    y_step <- 10
  } else if (y_range <= 500) {
    y_step <- 25
  } else {
    y_step <- ceiling(y_range / 8)  # Aim for ~8 breaks
  }
  
  # Generate Y-axis breaks
  y_start <- floor(y_min / y_step) * y_step
  y_end <- ceiling(y_max / y_step) * y_step
  yaxis <- seq(y_start, y_end, by = y_step)
  
  # Generate X-axis breaks
  xaxis <- seq(0, ax, by = break_interval)
  
  print(paste("Y-axis range:", y_min, "to", y_max, "with step:", y_step))
  
  # Create legend - Updated for methylation context
  legend_list <- list(
    labels = c("Methylation Sites"),
    col = c(lollipop_color),
    pch = c(18),  # Diamond shape symbol
    title = "Legend",
    cex = 0.8,
    bty = "n",
    pt.cex = 1.2
  )
  
  # Set plotting parameters with space for legend
  par(mar = c(5, 4, 4, 12) + 0.1)
  
  # Create extended range for x-axis
  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))
  
  # Create the lollipop plot
  lp <- lolliplot(
    lollis, 
    features = features,
    xaxis = xaxis, 
    yaxis = yaxis, 
    cex = 0.4, 
    label.cex = 0.7,
    ylab = "Frequency",
    xlab = "DNA Sequence Position", 
    main = "Methylation Profile",  # Updated title
    col = lollis$color,
    lwd = 0.5,
    side = "top",  # Lollipops above baseline
    ranges = extended_range  # Set full range for x-axis
  )
  
  print("Plot generated with improved Y-axis scaling, grey stems, diamond shapes, and legend for methylation data.")
  
  return(lp)
}




#* @serializer svg list(width = 25, height = 10)
#* @post /get_dna_methy_diff
#* @param object_id
#* @param ax
function(object_id, ax) {
  library(trackViewer)
  library(aws.s3)
  
  ax <- as.numeric(ax)
  print(paste("X-axis limit:", ax))
  
  data <- s3read_using(FUN = read.csv, object = object_id, bucket = Sys.getenv("S3_BUCKET"), stringsAsFactors = FALSE)
  
  print("Data loaded from S3:")
  print(head(data))
  
  # Updated column name handling for methylation data
  if ("Methylation_Site" %in% colnames(data) && "Frequency" %in% colnames(data) && "Expression" %in% colnames(data)) {
    colnames(data)[colnames(data) == "Methylation_Site"] <- "site"
    colnames(data)[colnames(data) == "Frequency"] <- "freq"
    colnames(data)[colnames(data) == "Expression"] <- "expression"
  } else if ("SNV" %in% colnames(data) && "Frequency" %in% colnames(data) && "Expression" %in% colnames(data)) {
    # Keep backward compatibility with SNV data
    colnames(data)[colnames(data) == "SNV"] <- "site"
    colnames(data)[colnames(data) == "Frequency"] <- "freq"
    colnames(data)[colnames(data) == "Expression"] <- "expression"
  } else if (!("site" %in% colnames(data) && "freq" %in% colnames(data) && "expression" %in% colnames(data))) {
    stop("Error: Required columns ('site'/'freq'/'expression', 'Methylation_Site'/'Frequency'/'Expression', or 'SNV'/'Frequency'/'Expression') are missing from the input data.")
  }
  
  # Extract position from site
  data$position <- as.numeric(gsub("[^0-9]", "", data$site))
  
  get_dynamic_break_interval <- function(ax) {
    if (ax <= 10000) {
      return(2000)
    } else if (ax <= 50000) {
      return(5000)
    } else if (ax <= 100000) {
      return(20000)
    } else if (ax <= 200000) {
      return(30000)
    } else {
      base <- 10^(floor(log10(ax)) - 1)
      return(base * 2)
    }
  }
  
  break_interval <- get_dynamic_break_interval(ax)
  
  print(paste("ax:", ax, "Break Interval:", break_interval))
  print("Processed data with numeric positions:")
  print(head(data))
  
  # Separate overexpressed and underexpressed data
  overexpressed_data <- data[data$expression == "Overexpressed", ]
  underexpressed_data <- data[data$expression == "Underexpressed", ]
  
  # Colors - Updated for methylation context
  overexpressed_color <- "#D22B2B"  # Red for overexpressed methylation
  underexpressed_color <- "#0A1195"  # Green for underexpressed methylation
  stem_color <- "grey"               # Grey for stems
  
  # Create GRanges for overexpressed (above baseline)
  if (nrow(overexpressed_data) > 0) {
    lollis_over <- GRanges(
      "chr1", 
      IRanges(overexpressed_data$position, width = 1, names = overexpressed_data$site),
      shape = "diamond"
    )
    lollis_over$color <- overexpressed_color
    lollis_over$border <- stem_color
    lollis_over$dashline.col <- stem_color
    lollis_over$score <- overexpressed_data$freq
    lollis_over$SNPsideID <- "top"  # Above baseline
  } else {
    lollis_over <- GRanges()
  }
  
  # Create GRanges for underexpressed (below x-axis)
  if (nrow(underexpressed_data) > 0) {
    lollis_under <- GRanges(
      "chr1", 
      IRanges(underexpressed_data$position, width = 1, names = underexpressed_data$site),
      shape = "diamond"
    )
    lollis_under$color <- underexpressed_color
    lollis_under$border <- stem_color
    lollis_under$dashline.col <- stem_color
    lollis_under$score <- underexpressed_data$freq
    lollis_under$SNPsideID <- "bottom"  # Below x-axis
  } else {
    lollis_under <- GRanges()
  }
  
  # Combine both GRanges
  if (length(lollis_over) > 0 && length(lollis_under) > 0) {
    all_lollis <- c(lollis_over, lollis_under)
  } else if (length(lollis_over) > 0) {
    all_lollis <- lollis_over
  } else if (length(lollis_under) > 0) {
    all_lollis <- lollis_under
  } else {
    stop("No valid data found for plotting")
  }
  
  # Calculate extended x-axis range for better visualization
  x_margin <- ax * 0.02  # Add 2% margin on each side
  x_start <- max(1 - x_margin, 0)  # Don't go below 0
  x_end <- ax + x_margin
  
  # Create features (the baseline/track)
  features <- GRanges("chr1", IRanges(start = x_start, end = x_end), fill = "white")
  
  # Y-axis range calculation - Handle both sides without negative axis labels
  max_freq <- max(data$freq)
  min_freq <- min(data$freq)
  
  # Use the maximum frequency for both sides, but keep axis labels positive
  max_abs_freq <- max(abs(c(max_freq, min_freq)))
  
  # Add padding (20% on each side)
  padding <- max_abs_freq * 0.2
  y_max <- max_abs_freq + padding
  y_min <- 0  # Keep minimum at 0 for cleaner axis
  
  # Create Y-axis breaks (only positive values shown)
  y_range <- y_max - y_min
  if (y_range <= 10) {
    y_step <- 1
  } else if (y_range <= 40) {
    y_step <- 2
  } else if (y_range <= 100) {
    y_step <- 5
  } else if (y_range <= 200) {
    y_step <- 10
  } else if (y_range <= 1000) {
    y_step <- 25
  } else {
    y_step <- ceiling(y_range / 10)  # Aim for ~10 breaks total
  }
  
  # Generate Y-axis breaks (only positive, but plot will handle negative side internally)
  max_y_break <- ceiling(y_max / y_step) * y_step
  yaxis <- seq(0, max_y_break, by = y_step)
  
  # Generate X-axis breaks
  xaxis <- seq(0, ax, by = break_interval)
  
  print(paste("Y-axis range:", y_min, "to", y_max, "with step:", y_step))
  
  # Create legend with same shapes - Updated for methylation context
  legend_labels <- c()
  legend_colors <- c()
  
  if (nrow(overexpressed_data) > 0) {
    legend_labels <- c(legend_labels, "Hypermethylated")
    legend_colors <- c(legend_colors, overexpressed_color)
  }
  
  if (nrow(underexpressed_data) > 0) {
    legend_labels <- c(legend_labels, "Hypomethylated")
    legend_colors <- c(legend_colors, underexpressed_color)
  }
  
  legend_list <- list(
    labels = legend_labels,
    col = legend_colors,
    pch = rep(18, length(legend_labels)),  # Diamond shape symbols
    title = "Methylation Level",
    cex = 0.8,
    bty = "n",
    pt.cex = 1.2
  )
  
  # Set plotting parameters with space for legend
  par(mar = c(5, 4, 4, 12) + 0.1)
  
  # Create extended range for x-axis
  extended_range <- GRanges("chr1", IRanges(start = x_start, end = x_end))
  
  # Create the lollipop plot
  lp <- lolliplot(
    all_lollis,
    features = features,
    xaxis = xaxis,
    yaxis = yaxis,
    cex = 0.6,
    label.cex = 0.7,
    ylab = "Hypomethylation                                     Hypermethylation",
    xlab = "DNA Sequence Position",
    main = "Methylation Differential Expression Profile",
    col = all_lollis$color,
    lwd = 0.5,
    ranges = extended_range  # Set full range for x-axis
  )
  
  print("Differential methylation plot generated with hypermethylated above and hypomethylated below x-axis, positive Y-axis labels only.")
  
  return(lp)
}
