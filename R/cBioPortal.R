utils::globalVariables(c("clinicalAttributeId", "value", "sampleId"))

.handle_token <- function(token) {
    if (file.exists(token))
        token <- readLines(token)
    else if (grepl(.Platform$file.sep, token, fixed = TRUE))
        stop("The token filepath is not valid")
    token <- gsub("token: ", "", token)
    c(Authorization = paste("Bearer", token))
}

#' @rdname cBioPortal
#'
#' @aliases cBioPortal
#'
#' @title The R interface to the cBioPortal API Data Service
#'
#' @description This section of the documentation lists the functions that
#'     allow users to access the cBioPortal API. The main representation of the
#'     API can be obtained from the `cBioPortal` function. The supporting
#'     functions listed here give access to specific parts of the API and
#'     allow the user to explore the API with individual calls. Many of the
#'     functions here are listed for documentation purposes and are
#'     recommended for advanced usage only. Users should only need to use the
#'     `cBioPortalData` main function to obtain data.
#'
#' @param api An API object of class `cBioPortal` from the `cBioPortal`
#'     function
#'
#' @param hostname character(1) The internet location of the service
#'     (default: 'www.cbioportal.org')
#'
#' @param protocol character(1) The internet protocol used to access the
#'     hostname (default: 'https')
#'
#' @param api. character(1) The directory location of the API protocol within
#'     the hostname (default: '/api/api-docs')
#'
#' @param token character(1) The Authorization Bearer token e.g.,
#'     "63eba81c-2591-4e15-9d1c-fb6e8e51e35d" or a path to text file.
#'
#' @param studyId character(1) Indicates the "studyId" as taken from
#'     `getStudies`
#'
#' @param buildReport logical(1) Indicates whether to append the build
#'     information to the `getStudies()` table (default FALSE)
#'
#' @param keyword character(1) Keyword or pattern for searching through
#'     available operations
#'
#' @param molecularProfileId character(1) Indicates a molecular profile ID
#'
#' @param molecularProfileIds character() A vector of molecular profile IDs
#'
#' @param entrezGeneIds numeric() A vector indicating entrez gene IDs
#'
#' @param sampleIds character() Sample identifiers
#'
#' @param genes character() Either Entrez gene identifiers or Hugo gene
#'     symbols. When included, the 'by' argument indicates the type of
#'     identifier provided and 'genePanelId' is ignored. Preference is
#'     given to Entrez IDs due to faster query responses.
#'
#' @param genePanelId character(1) Identifies the gene panel, as obtained
#'     from the `genePanels` function
#'
#' @param by character(1) Either 'entrezGeneId' or 'hugoGeneSymbol' for row
#'     metadata (default: 'entrezGeneId')
#'
#' @return
#'
#'     cBioPortal: An API object of class 'cBioPortal'
#'
#'     cBioPortalData: A data object of class 'MultiAssayExperiment'
#'
#' @importFrom AnVIL Service
#'
#' @examples
#' cbio <- cBioPortal()
#'
#' getStudies(api = cbio)
#'
#' searchOps(api = cbio, keyword = "molecular")
#'
#' ## obtain clinical data
#' acc_clin <- clinicalData(api = cbio, studyId = "acc_tcga")
#' acc_clin
#'
#' molecularProfiles(api = cbio, studyId = "acc_tcga")
#'
#' genePanels(cbio)
#'
#' (gp <- getGenePanel(cbio, "AmpliSeq"))
#'
#' muts <- mutationData(
#'     api = cbio,
#'     molecularProfileIds = "acc_tcga_mutations",
#'     entrezGeneIds = 1:1000,
#'     sampleIds = c("TCGA-OR-A5J1-01", "TCGA-OR-A5J2-01")
#' )
#' exps <- molecularData(
#'     api = cbio,
#'     molecularProfileIds = c("acc_tcga_rna_seq_v2_mrna", "acc_tcga_rppa"),
#'     entrezGeneIds = 1:1000,
#'     sampleIds = c("TCGA-OR-A5J1-01", "TCGA-OR-A5J2-01")
#' )
#'
#' sampleLists(api = cbio, studyId = "acc_tcga")
#'
#' samplesInSampleLists(
#'     api = cbio,
#'     sampleListIds = c("acc_tcga_rppa", "acc_tcga_cnaseq")
#' )
#'
#' genePanels(api = cbio)
#'
#' getGenePanel(api = cbio, genePanelId = "IMPACT341")
#'
#' @export
cBioPortal <- function(
    hostname = "www.cbioportal.org",
    protocol = "https",
    api. = "/api/api-docs",
    token = character()
) {
    if (length(token))
        token <- .handle_token(token)

    apiUrl <- paste0(protocol, "://", hostname, api.)
    .cBioPortal(
        Service(
            service = "cBioPortal",
            host = hostname,
            config = httr::config(
                ssl_verifypeer = 0L, ssl_verifyhost = 0L, http_version = 0L
            ),
            authenticate = FALSE,
            api_reference_url = apiUrl,
            api_reference_md5sum = "6abc321feb60da3251620743b527bab9",
            api_reference_headers = token,
            package = "cBioPortalData",
            schemes = protocol
        ),
        api_header = token
    )
}

.loadReportData <- function() {
    denv <- new.env(parent = emptyenv())
    api_file <- system.file(
        "extdata", "api", "api_build.rda",
        package = "cBioPortalData", mustWork = TRUE
    )
    pack_file <- system.file(
        "extdata", "pack", "pack_build.rda",
        package = "cBioPortalData", mustWork = TRUE
    )
    load(api_file, envir = denv)
    load(pack_file, envir = denv)

    denv
}

#' @name cBioPortal
#'
#' @section API Metadata:
#'     * getStudies - Obtain a table of studies and associated metadata and
#'     optionally include a `buildReport` status (default FALSE) for each
#'     study. When enabled, the 'api_build' and 'pack_build' columns will
#'     be added to the table and will show if `MultiAssayExperiment` objects
#'     can be generated for that particular study identifier (`studyId`). The
#'     'api_build' column corresponds to datasets obtained with
#'     `cBioPortalData` and the 'pack_build' column corresponds to datsets
#'     loaded via `cBioDataPack`.
#'
#' @export
getStudies <- function(api, buildReport = FALSE) {
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")

    query <- .invoke_fun(api, "getAllStudiesUsingGET")
    studies <- httr::content(query)
    studies <- lapply(studies, function(x) {
        if (is.null(x[["pmid"]]))
            x[["pmid"]] <- NA_character_
        if (is.null(x[["citation"]]))
            x[["citation"]] <- NA_character_
        x
    })
    studytable <- dplyr::bind_rows(studies)

    if (buildReport) {
        denv <- .loadReportData()
        suppressMessages({
            studytable <- dplyr::left_join(studytable, denv[["api_build"]])
            studytable <- dplyr::left_join(studytable, denv[["pack_build"]])
        })
    }

    studytable
}

#' @name cBioPortal
#'
#' @section Patient Data:
#'      * clinicalData - Obtain clinical data for a particular study identifier
#'      ('studyId')
#'
#' @export
clinicalData <- function(api, studyId = NA_character_) {
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")

    studyId <- force(studyId)
    digi <- digest::digest(list("clinicalData", api, studyId))
    cacheloc <- .getHashCache(digi)
    if (file.exists(cacheloc)) {
        load(cacheloc)
    } else {
        atts <- .invoke_bind(
            api = api, name = "fetchAllClinicalDataInStudyUsingPOST",
            use_cache = FALSE, clinicalDataType = "PATIENT", studyId = studyId
        )
        att_tab <- tidyr::pivot_wider(data = atts, id_cols = "patientId",
            names_from = "clinicalAttributeId", values_from = "value")
        clin <- .invoke_bind(
            api = api, name = "getAllClinicalDataInStudyUsingGET",
            use_cache = FALSE, studyId = studyId
        )
        clin_tab <- tidyr::pivot_wider(data = clin,
            id_cols = c("patientId", "sampleId"),
            names_from = "clinicalAttributeId", values_from = "value")
        full <-    dplyr::full_join(att_tab, clin_tab, by = "patientId")
        save(full, file = cacheloc)
    }
    full
}

#' @name cBioPortal
#'
#' @section Molecular Profiles:
#'      * molecularProfiles - Produce a molecular profiles dataset for a given
#'      study identifier ('studyId')
#'
#' @param projection character(default: "SUMMARY") Specify the projection
#'   type for data retrieval for details see API documentation
#'
#' @export
molecularProfiles <- function(api, studyId = NA_character_,
    projection = c("SUMMARY", "ID", "DETAILED", "META"))
{
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")

    projection <- match.arg(projection)
    mols <- .invoke_fun(
        api = api, name = "getAllMolecularProfilesInStudyUsingGET",
        use_cache = FALSE, studyId = studyId, projection = projection
    )
    cmols <- httr::content(mols)
    if (projection %in% c("SUMMARY", "ID"))
        dplyr::bind_rows(cmols)
    else
        cmols
}

.sampleMolIds <- function(molecularProfileIds, sampleIds)
{
    SampMolIds <- S4Vectors::expand.grid(
        molecularProfileId = sort(molecularProfileIds),
        sampleId = sort(sampleIds)
    )
    SampMolIds[order(SampMolIds[["molecularProfileId"]]), ]
}

#' @name cBioPortal
#'
#' @section Mutation Data:
#'     * mutationData - Produce a dataset of mutation data using
#'     `molecularProfileId`, `entrezGeneIds`, and `sampleIds`
#'
#' @export
mutationData <- function(api, molecularProfileIds = NA_character_,
    entrezGeneIds = NULL, sampleIds = NULL)
{
    endpoint <-
        if (length(molecularProfileIds) == 1L)
            "fetchMutationsInMolecularProfileUsingPOST"
        else
            "fetchMutationsInMultipleMolecularProfilesUsingPOST"

    if (length(molecularProfileIds) > 1L) {
        SampMolIds <- .sampleMolIds(molecularProfileIds, sampleIds)
    }
    args <- list(api = api, name = endpoint, use_cache = FALSE)

    if (length(molecularProfileIds) == 1L)
        args <- c(args, list(
            molecularProfileId = molecularProfileIds,
            entrezGeneIds = sort(entrezGeneIds),
            sampleIds = sort(sampleIds)
        ))
    else
        args <- c(args, list(
            molecularProfileIds = molecularProfileIds,
            sampleMolecularIdentifiers = SampMolIds
        ))

    byGene <- do.call(.invoke_bind, args)

    if ("message" %in% names(byGene) || !length(byGene)) {
        msg <- byGene[["message"]]
        if (length(msg))
            warning(msg)
        else
            warning(
                "No data found for molecularProfileId: ", molecularProfileIds
            )
        dplyr::tibble()
    } else {
        split(byGene, byGene[["molecularProfileId"]])
    }
}

#' @name cBioPortal
#'
#' @section Molecular Profiles:
#'     * molecularData - Produce a dataset of molecular profile data based on
#'     `molecularProfileId`, `entrezGeneIds`, and `sampleIds`
#'
#' @export
molecularData <- function(api, molecularProfileIds = NA_character_,
    entrezGeneIds = NULL, sampleIds = NULL)
{
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")
    if (is.null(entrezGeneIds))
        stop("Provide a character vector of 'entrezGeneIds'")
    if (is.null(sampleIds))
        stop("Provide a character vector of 'sampleIds'")

    byGeneList <- vector("list", length(molecularProfileIds))
    names(byGeneList) <- molecularProfileIds

    mutation <- grepl("mutation", molecularProfileIds)
    if (any(mutation))
        byGeneList[mutation] <- mutationData(
            api, molecularProfileIds[mutation], entrezGeneIds, sampleIds
        )
    molecularProfileIds <- molecularProfileIds[!mutation]

    if (length(molecularProfileIds) == 1L) {
        endpoint <- "fetchAllMolecularDataInMolecularProfileUsingPOST"
        byGene <- .invoke_bind(api,
            endpoint,
            use_cache = FALSE,
            molecularProfileId = molecularProfileIds,
            entrezGeneIds = sort(entrezGeneIds),
            sampleIds = sort(sampleIds)
        )
    } else if (length(molecularProfileIds)) {
        endpoint <- "fetchMolecularDataInMultipleMolecularProfilesUsingPOST"
        byGene <- .invoke_bind(api,
            endpoint,
            use_cache = FALSE,
            projection = "SUMMARY",
            entrezGeneIds = sort(entrezGeneIds),
            sampleMolecularIdentifiers = .sampleMolIds(
                molecularProfileIds, sampleIds
            )
        )
    } else {
        byGene <- dplyr::tibble(molecularProfileId = NA_character_)
    }

    byGene <- split(byGene, byGene[["molecularProfileId"]])
    byGeneList[names(byGene)] <- byGene
    ## remove empty responses (e.g., in ov_tcga_pub_mirna)
    byGeneList <- Filter(length, byGeneList)

    for (gnames in names(byGeneList)) {
        byG <- byGeneList[[gnames]]
        if ("message" %in% names(byG) || !length(byG)) {
            msg <- byG[["message"]]
            if (length(msg))
                warning(msg)
            else
                warning(
                    "No data found for molecularProfileId: ",
                )
            byGeneList[[gnames]] <- dplyr::tibble()
        }
    }
    byGeneList
}

#' @name cBioPortal
#'
#' @section API Metadata:
#'     * searchOps - Search through API operations with a keyword
#'
#' @export
searchOps <- function(api, keyword) {
    grep(keyword, names(AnVIL::operations(api)),
        value = TRUE, ignore.case = TRUE)
}

#' @name cBioPortal
#'
#' @section API Metadata:
#'     * geneTable - Get a table of all genes by 'entrezGeneId' or
#'     'hugoGeneSymbol'
#'
#' @param pageSize numeric(1) The number of rows in the table to return
#'
#' @param pageNumber numeric(1) The pagination page number
#'
#' @param ... Additional arguments to lower level API functions
#'
#' @export
geneTable <- function(api, pageSize = 1000, pageNumber = 0, ...) {
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")

    .invoke_bind(api, "getAllGenesUsingGET", TRUE, pageSize = pageSize,
        pageNumber = pageNumber, ...)
}

#' @name cBioPortal
#'
#' @section Sample Data:
#'     * samplesInSampleLists - get all samples associated with a 'sampleListId'
#'
#' @param sampleListIds character() A vector of 'sampleListId' as obtained from
#'     `sampleLists`
#'
#' @export
samplesInSampleLists <-
    function(api, sampleListIds = NA_character_) {
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")
    sampleListIds <- sort(sampleListIds)
    sampleListIds <- setNames(sampleListIds, sampleListIds)

    meta <- structure(vector("list", length(sampleListIds)),
        .Names = sampleListIds)
    res <- lapply(sampleListIds, function(x) {
        res <- .invoke_fun(
            api, "getSampleListUsingGET", FALSE, sampleListId = x
        )
        res2 <- httr::content(res)
        meta[[x]] <<- res2[names(res2) != "sampleIds"]
        unlist(res2[["sampleIds"]])
    })
    res <- IRanges::CharacterList(res)
    meta <- dplyr::bind_rows(meta)
    metadata(res) <- meta

    res
}

#' @name cBioPortal
#'
#' @section API Metadata:
#'     * sampleLists - obtain all `sampleListIds` for a particular `studyId`
#'
#' @export
sampleLists <- function(api, studyId = NA_character_) {
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")
    .invoke_bind(api, "getAllSampleListsInStudyUsingGET", FALSE,
        studyId = studyId)
}

#' @name cBioPortal
#'
#' @section API Metadata:
#'     * allSamples - obtain all samples within a particular `studyId`
#'
#' @export
allSamples <- function(api, studyId = NA_character_) {
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")
    .invoke_bind(api, "getAllSamplesInStudyUsingGET", FALSE,
        studyId = list(studyId = studyId))
}

#' @name cBioPortal
#'
#' @section API Metadata:
#'     * genePanels - Show all available gene panels
#'
#' @export
genePanels <- function(api) {
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")

    .invoke_bind(api, "getAllGenePanelsUsingGET", FALSE)
}

#' @name cBioPortal
#'
#' @section Gene Panels:
#'     * getGenePanels - Obtain the gene panel for a particular 'genePanelId'
#'
#' @export
getGenePanel <- function(api, genePanelId = NA_character_) {
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")

    res <- .invoke_fun(api, "getGenePanelUsingGET", FALSE,
        genePanelId = genePanelId)
    res <- httr::content(res)[["genes"]]
    dplyr::bind_rows(res)
}

#' @name cBioPortal
#'
#' @section Gene Panels:
#'     * genePanelMolecular - get gene panel data for a paricular
#'     `molecularProfileId` and `sampleListId` combination
#'
#' @param sampleListId character(1) A sample list identifier as obtained from
#'     `sampleLists()``
#'
#' @export
genePanelMolecular <-
    function(api, molecularProfileId = NA_character_, sampleListId = NULL,
        sampleIds = NULL)
{
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")

    if (!is.null(sampleListId))
        .invoke_bind(api, "getGenePanelDataUsingPOST", use_cache = FALSE,
            molecularProfileId = molecularProfileId,
            sampleListId = list(sampleListId = sampleListId)
        )
    else if (!is.null(sampleIds))
        .invoke_bind(api, "getGenePanelDataUsingPOST", use_cache = FALSE,
            molecularProfileId = molecularProfileId,
            sampleIds = list(sampleIds = sort(sampleIds))
        )
    else
        stop("Provide either 'sampleIds' or a 'sampleListId'")
}

#' @name cBioPortal
#'
#' @section Gene Panels:
#'     * getGenePanelMolecular - get gene panel data for a combination of
#'     `molecularProfileId` and `sampleListId` vectors
#'
#' @export
getGenePanelMolecular <-
    function(api, molecularProfileIds = NA_character_, sampleIds)
{
    if (missing(sampleIds))
        stop(
            "Provide valid 'sampleIds' from 'samplesInSampleLists()'",
            " or 'allSamples()'"
        )

    SampMolIds <- S4Vectors::expand.grid(
        molecularProfileId = sort(molecularProfileIds),
        sampleId = sort(sampleIds)
    )
    SampMolIds <- SampMolIds[order(SampMolIds[["molecularProfileId"]]), ]

    .invoke_bind(
        api = api,
        name = "fetchGenePanelDataInMultipleMolecularProfilesUsingPOST",
        use_cache = FALSE,
        sampleMolecularIdentifiers =
            list(sampleMolecularIdentifiers = SampMolIds)
    )
}

#' @name cBioPortal
#'
#' @section Sample Data:
#'     * getSampleInfo - Obtain sample metadata for a particular `studyId` or
#'     `sampleListId`
#' @export
getSampleInfo <-
    function(api, studyId = NA_character_, sampleListIds = NULL,
        projection = c("SUMMARY", "ID", "DETAILED", "META"))
{
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")
    projection <- match.arg(projection)
    if (!is.null(sampleListIds))
        queryobj <- list(sampleListIds = sampleListIds)
    else
        queryobj <- list(sampleIdentifiers =
            as.data.frame(
                allSamples(api, studyId)[, c("sampleId", "studyId")]
            )
        )

    .invoke_bind(api = api, name = "fetchSamplesUsingPOST", use_cache = FALSE,
        projection = projection, sampleIdentifiers = queryobj
    )
}

.resolveFeatures <- function(api, by, genes, genePanelId) {
    isSingleNA <- function(x) { length(x) == 1L && is.na(x) }

    if (isSingleNA(genes) && isSingleNA(genePanelId))
        stop("Provide either 'genes' or 'genePanelId'")

    geneIdType <- switch(
        by, entrezGeneId = "ENTREZ_GENE_ID", 'HUGO_GENE_SYMBOL'
    )

    feats <- genes
    if (identical(by, "hugoGeneSymbol") && !is.na(genes))
        feats <- .invoke_bind(api, "fetchGenesUsingPOST", TRUE,
            geneIdType = geneIdType, geneIds = as.character(genes))
    else
        feats <- tibble::tibble(entrezGeneId = genes)

    if (isSingleNA(genes))
        feats <- getGenePanel(api, genePanelId = genePanelId)

    feats
}

#' @name cBioPortal
#'
#' @section Genes:
#'     * getDataByGenes - Download data for a number of genes within
#'     `molecularProfileId` indicators, optionally a `sampleListId` can be
#'     provided.
#'
#' @examples
#'
#' getDataByGenes(
#'     cbio, studyId = "acc_tcga", genes = 1:3,
#'     by = c("entrezGeneId", "hugoGeneSymbol"),
#'     molecularProfileId = "acc_tcga_rppa",
#'     sampleListId = "acc_tcga_rppa"
#' )
#'
#' @export
getDataByGenes <-
    function(api, studyId = NA_character_, genes = NA_character_,
        genePanelId = NA_character_, by = c("entrezGeneId", "hugoGeneSymbol"),
        molecularProfileIds = NULL, sampleListId = NULL, sampleIds = NULL, ...)
{
    if (missing(api))
        stop("Provide a valid 'api' from 'cBioPortal()'")
    if (!is.null(sampleListId))
        sampleIds <- samplesInSampleLists(api, sampleListId)[[1L]]
    else if (is.null(sampleIds))
        sampleIds <- allSamples(api, studyId)[["sampleId"]]

    by <- match.arg(by)

    feats <- .resolveFeatures(api, by, genes, genePanelId)

    digi <- digest::digest(
        list("getDataByGenes", api, studyId, feats, sampleIds,
            molecularProfileIds)
    )
    cacheloc <- .getHashCache(digi)
    if (file.exists(cacheloc)) {
        load(cacheloc)
    } else {
        molData <- molecularData(api = api,
            molecularProfileIds = molecularProfileIds,
            entrezGeneIds = feats[["entrezGeneId"]],
            sampleIds = sampleIds
        )
        molData <- lapply(molData, function(x) suppressMessages({
            dplyr::left_join(x, feats)
            })
        )
        save(molData, file = cacheloc)
    }
    molData
}
