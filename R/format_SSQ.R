#' Construct standard format for data from Santo Stefano Quisquina, Italy.
#'
#' A pipeline to produce the standard format for the great and blue tit population
#' in Santo Stefano Quisquina, Sicly, Italy, administered by Camillo Cusimano
#' and Daniela Campobello.
#'
#' This section provides details on data management choices that are unique to
#' this data. For a general description of the standard format please see
#'\href{https://github.com/SPI-Birds/documentation/blob/master/standard_protocol/SPI_Birds_Protocol_v1.1.0.pdf}{here}.
#'
#' \strong{BroodID}: Unique BroodID is constructed using:
#' BreedingSeason_LocationID_LayDate (April days)
#'
#' \strong{Species}: In the individual data, there are some cases where an
#' IndvID is associated with >1 species. These are considered conflicted species.
#'
#' \strong{CaptureDate}: No exact capture date is currently given. For adults we
#' use the laying date of the nest as a proxy for capture date. Chicks were only
#' ever captured on the nest, we used laying date + clutch size + 15 days
#' incubation + 12 days. This is because chicks were ringed at 12 days old at
#' the latest.
#'
#' \strong{Age_calculated}: All ringed chicks were assumed to be ringed at EURING code
#' 1 (i.e. pre-fledging).
#'
#' \strong{Individual_data}: There are cases where chicks from different nests are
#' given the same ring number. Unsure if this is the rings being reused or a
#' typo. Currently, I leave it as is and assume this is a typo that needs to be
#' fixed in the primary data.
#'
#' \strong{StartSeason}: Some nest boxes were replaced over the course of
#' the study; however, these replacements were not explicitly recorded.
#' Therefore, we list all nestboxes as functioning for the full study period.
#'
#' @inheritParams pipeline_params
#'
#' @return Generates either 4 .csv files or 4 data frames in the standard format.
#' @export

format_SSQ <- function(db = choose_directory(),
                       species = NULL,
                       pop = NULL,
                       path = ".",
                       output_type = "R"){

  #Force user to select directory
  force(db)

  SSQ_data <- paste0(db, "/SSQ_PrimaryData.xlsx")

  if(is.null(species)){

    species <- species_codes$Species

  }

  #Record start time to provide processing time to the user.
  start_time <- Sys.time()

  #Read in data with readxl
  all_data <- readxl::read_excel(SSQ_data) %>%
    #Clean all names with janitor to snake_case
    janitor::clean_names(case = "upper_camel") %>%
    #Remove the column 'Row'. This is just the row number, we have this already.
    dplyr::select(-.data$Row) %>%
    janitor::remove_empty(which = "rows") %>%
    #Change column names to match consistent naming
    ## TODO: Add uncertainty if needed.
    dplyr::mutate(BreedingSeason = as.integer(.data$Year), LayDate_observed = .data$Ld,
                  ClutchSize_observed = as.integer(.data$Cs), HatchDate_observed = .data$Hd,
                  BroodSize_observed = as.integer(.data$Hs), NumberFledged_observed = as.integer(.data$Fs),
                  FemaleID = .data$FId, MaleID = .data$MId, LocationID = .data$NestId,
                  Plot = .data$HabitatOfRinging,
                  Latitude = .data$YCoord, Longitude = .data$XCoord) %>%
    #Add species codes
    dplyr::mutate(Species = dplyr::case_when(.$Species == "Parus major" ~ species_codes[which(species_codes$SpeciesID == 14640), ]$Species,
                                             .$Species == "Cyanistes caeruleus" ~ species_codes[which(species_codes$SpeciesID == 14620), ]$Species)) %>%
    #Filter species
    dplyr::filter(.data$Species %in% species) %>%
    #Add other missing data:
    #- PopID
    #- BroodID (Year_LocationID_LayDate)
    #- ClutchType_observed
    #- FledgeDate_observed
    #Pad LocationID so they are all the same length
    dplyr::mutate(PopID = "SSQ",
                  LocationID = stringr::str_pad(.data$LocationID, width = 3, pad = "0"),
                  BroodID = paste(.data$BreedingSeason, .data$LocationID, stringr::str_pad(.data$LayDate_observed, width = 3, pad = "0"), sep = "_"),
                  ClutchType_observed = dplyr::case_when(.$Class == 1 ~ "first",
                                                         .$Class == 3 ~ "second",
                                                         .$Class == 2 ~ "replacement"),
                  FledgeDate_observed = as.Date(NA), AvgEggMass = NA_real_,
                  NumberEggs = NA_integer_, AvgChickMass = NA_real_,
                  NumberChicksMass = NA_integer_, AvgTarsus = NA_real_,
                  NumberChicksTarsus = NA_integer_, ExperimentID = NA_character_,
                  LayDate_observed = as.Date(paste(.data$BreedingSeason, "03-01", sep = "-"), format = "%Y-%m-%d") + .data$LayDate_observed - 1,
                  HatchDate_observed = as.Date(paste(.data$BreedingSeason, "03-01", sep = "-"), format = "%Y-%m-%d") + .data$HatchDate_observed - 1)

  # BROOD DATA

  message("Compiling brood information...")

  Brood_data <- create_brood_SSQ(all_data)

  # CAPTURE DATA

  message("Compiling capture information...")

  Capture_data <- create_capture_SSQ(all_data)

  # INDIVIDUAL DATA

  message("Compiling individual information...")

  Individual_data <- create_individual_SSQ(all_data, Capture_data, Brood_data)

  # LOCATION DATA

  message("Compiling nestbox information...")

  Location_data <- create_location_SSQ(all_data)

  # EXPORT DATA

  time <- difftime(Sys.time(), start_time, units = "sec")

  message(paste0("All tables generated in ", round(time, 2), " seconds"))

  if(output_type == "csv"){

    message("Saving .csv files...")

    utils::write.csv(x = Brood_data, file = paste0(path, "\\Brood_data_SSQ.csv"), row.names = F)

    utils::write.csv(x = Individual_data, file = paste0(path, "\\Individual_data_SSQ.csv"), row.names = F)

    utils::write.csv(x = Capture_data, file = paste0(path, "\\Capture_data_SSQ.csv"), row.names = F)

    utils::write.csv(x = Location_data, file = paste0(path, "\\Location_data_SSQ.csv"), row.names = F)

    invisible(NULL)

  }

  if(output_type == "R"){

    message("Returning R objects...")

    return(list(Brood_data = Brood_data,
                Capture_data = Capture_data,
                Individual_data = Individual_data,
                Location_data = Location_data))

  }

}

#' Create brood data table for Santo Stefano Quisquina, Italy.
#'
#' Create brood data table in standard format for data from Santo Stefano
#' Quisquina, Italy
#' @param data Data frame. Primary data from Santo Stefano Quisquina.
#'
#' @return A data frame.

create_brood_SSQ <- function(data){

  #Determine ClutchType_calculated
  clutchtype <- progress::progress_bar$new(total = nrow(data))

  Brood_data <- data %>%
    #Arrange data for use with ClutchType_calculated (should be chronological)
    dplyr::arrange(.data$BreedingSeason, .data$FemaleID, .data$LayDate_observed) %>%
    #Calculate clutch type
    dplyr::mutate(ClutchType_calculated = calc_clutchtype(data = ., na.rm = FALSE, protocol_version = "1.1"),
                  OriginalTarsusMethod = NA_character_) %>%
    ## Keep only necessary columns
    dplyr::select(dplyr::contains(names(brood_data_template))) %>%
    ## Add missing columns
    dplyr::bind_cols(brood_data_template[1, !(names(brood_data_template) %in% names(.))]) %>%
    ## Reorder columns
    dplyr::select(names(brood_data_template))

  return(Brood_data)

}

#' Create capture data table for Santo Stefano Quisquina, Italy.
#'
#' Create capture data table in standard format for data from Santo Stefano
#' Quisquina, Italy
#' @param data Data frame. Primary data from Santo Stefano Quisquina.
#'
#' @return A data frame.

create_capture_SSQ <- function(data){

  Adult_captures <- data %>%
    dplyr::select(.data$BreedingSeason, .data$PopID, .data$Plot, .data$LocationID,
                  .data$Species, .data$LayDate_observed, .data$FemaleID, .data$FAge,
                  .data$MaleID, .data$MAge) %>%
    #Combine column FemaleID and MaleID
    tidyr::pivot_longer(cols = c("FemaleID", "MaleID"), values_to = "IndvID", names_to = "variable") %>%
    #Remove all NAs, we're only interested in cases where parents were ID'd.
    dplyr::filter(!is.na(.data$IndvID)) %>%
    #Make a single Age column. If variable == "FemaleID", then use FAge and visa versa
    dplyr::rowwise() %>%
    dplyr::mutate(Age = ifelse(variable == "FemaleID", as.integer(.data$FAge), as.integer(.data$MAge))) %>%
    dplyr::ungroup() %>%
    #Convert these age values to current EURING codes
    #If NA, we know it's an adult but don't know it's age
    #We don't want to assume anything here
    dplyr::mutate(Age_observed = dplyr::case_when(.$Age == 1 ~ 5L,
                                                  .$Age == 2 ~ 6L)) %>%
    dplyr::rename(CapturePopID = .data$PopID, CapturePlot = .data$Plot) %>%
    #Treat CaptureDate of adults as the Laying Date
    dplyr::mutate(ReleasePopID = .data$CapturePopID, ReleasePlot = .data$CapturePlot,
                  CaptureDate = .data$LayDate_observed,
                  CaptureTime = NA_character_) %>%
    dplyr::select(-.data$variable, -.data$LayDate_observed, -.data$FAge, -.data$MAge)

  #Also extract chick capture information
  Chick_captures <- data %>%
    dplyr::select(.data$BreedingSeason, .data$Species, .data$PopID, .data$Plot, .data$LocationID,
                  .data$LayDate_observed, .data$ClutchSize_observed, .data$Chick1Id:Chick13Id) %>%
    #Create separate rows for every chick ID
    tidyr::pivot_longer(cols = c(.data$Chick1Id:.data$Chick13Id), names_to = "variable", values_to = "IndvID") %>%
    #Remove NAs
    dplyr::filter(!is.na(.data$IndvID)) %>%
    dplyr::rename(CapturePopID = .data$PopID, CapturePlot = .data$Plot) %>%
    #For chicks, we currently don't have the version of the individual level capture data.
    #For now, we use LayDate + ClutchSize + 15 (incubation days in SSQ) + 12.
    #Chicks were captured and weighed at 12 days old at the latest
    dplyr::mutate(ReleasePopID = .data$CapturePopID, ReleasePlot = .data$CapturePlot,
                  CaptureDate = .data$LayDate_observed + ClutchSize_observed + 27,
                  CaptureTime = NA_character_, Age_observed = 1, Age = 1L) %>%
    dplyr::select(-.data$variable, -.data$LayDate_observed, -.data$ClutchSize_observed)

  #Combine Adult and chick data
  Capture_data <- dplyr::bind_rows(Adult_captures, Chick_captures) %>%
    dplyr::arrange(.data$IndvID, .data$CaptureDate) %>%
    #Add NA for morphometric measures and chick age
    #ChickAge (in days) is NA because we have no exact CaptureDate
    dplyr::mutate(Mass = NA_real_, Tarsus = NA_real_, OriginalTarsusMethod = NA_character_,
                  WingLength = NA_real_,
                  ChickAge = NA_integer_, ObserverID = NA_character_) %>%
    calc_age(ID = .data$IndvID, Age = .data$Age, Date = .data$CaptureDate, Year = .data$BreedingSeason) %>%
    ## Keep only necessary columns
    dplyr::select(dplyr::contains(names(capture_data_template))) %>%
    ## Add missing columns
    dplyr::bind_cols(capture_data_template[1, !(names(capture_data_template) %in% names(.))]) %>%
    ## Reorder columns
    dplyr::select(names(capture_data_template))

  return(Capture_data)

}

#' Create individual data table for Santo Stefano Quisquina, Italy.
#'
#' Create individual data table in standard format for data from Santo Stefano
#' Quisquina, Italy
#' @param data Data frame. Primary data from Santo Stefano Quisquina.
#' @param Capture_data Data frame. Generate by \code{\link{create_capture_SSQ}}.
#' @param Brood_data Data frame. Generate by \code{\link{create_brood_SSQ}}.
#'
#' @return A data frame.

create_individual_SSQ <- function(data, Capture_data, Brood_data){

  #Create a list of all chicks
  Chick_IDs <- data %>%
    dplyr::select(.data$BroodID, .data$Chick1Id:.data$Chick13Id) %>%
    tidyr::pivot_longer(cols = c(-.data$BroodID), names_to = "variable", values_to = "IndvID") %>%
    dplyr::filter(!is.na(.data$IndvID)) %>%
    dplyr::select(-.data$variable, BroodIDLaid = .data$BroodID)

  #Determine summary data for every captured individual
  Individual_data <- Capture_data %>%
    dplyr::arrange(.data$IndvID, .data$CaptureDate) %>%
    dplyr::group_by(.data$IndvID) %>%
    dplyr::summarise(Species = dplyr::case_when(length(unique(.data$Species)) == 2 ~ "CCCCCC",
                                                TRUE ~ dplyr::first(.data$Species)),
                     RingSeason = as.integer(min(lubridate::year(.data$CaptureDate))),
                     RingAge = dplyr::case_when(is.na(first(.data$Age_observed)) ~ "adult",
                                                first(.data$Age_observed) == 1 ~ "chick",
                                                first(.data$Age_observed) > 1 ~ "adult")) %>%
    dplyr::mutate(Sex_calculated = dplyr::case_when(.$IndvID %in% Brood_data$FemaleID ~ "F",
                                                    .$IndvID %in% Brood_data$MaleID ~ "M",
                                                    .$IndvID %in% Brood_data$MaleID & .$IndvID %in% Brood_data$FemaleID ~ "C")) %>%
    #Join in BroodID from the reshaped Chick_IDs table
    dplyr::left_join(Chick_IDs, by = "IndvID") %>%
    dplyr::mutate(BroodIDFledged = .data$BroodIDLaid,
                  PopID = "SSQ") %>%
    ## Keep only necessary columns
    dplyr::select(dplyr::contains(names(individual_data_template))) %>%
    ## Add missing columns
    dplyr::bind_cols(individual_data_template[1, !(names(individual_data_template) %in% names(.))]) %>%
    ## Reorder columns
    dplyr::select(names(individual_data_template))

}

#' Create location data table for Santo Stefano Quisquina, Italy.
#'
#' Create location data table in standard format for data from Santo Stefano
#' Quisquina, Italy
#' @param data Data frame. Primary data from Santo Stefano Quisquina.
#'
#' @return A data frame.

create_location_SSQ <- function(data){

  Location_data <- data %>%
    dplyr::group_by(.data$LocationID) %>%
    dplyr::summarise(LocationType = "NB",
                     PopID = "SSQ",
                     StartSeason = 1993L, EndSeason = NA_integer_) %>%
    dplyr::mutate(NestboxID = .data$LocationID) %>%
    #Join in first latitude and longitude data recorded for this box.
    #It's not clear why these are ever different, need to ask.
    dplyr::left_join(data %>% group_by(.data$LocationID) %>% slice(1) %>% select(.data$LocationID, .data$Latitude, .data$Longitude), by = "LocationID") %>%
    ## Keep only necessary columns
    dplyr::select(dplyr::contains(names(location_data_template))) %>%
    ## Add missing columns
    dplyr::bind_cols(location_data_template[1, !(names(location_data_template) %in% names(.))]) %>%
    ## Reorder columns
    dplyr::select(names(location_data_template))

}
