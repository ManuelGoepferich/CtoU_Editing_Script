# Define a class for the output
CtoUResult <- setClass("CtoUResult",
                      slots = list(
                        name = 'character',
                        valid =  'logical',
                        events = 'matrix', # not tested so far
                        CmatrixList = 'list',
                        UmatrixList = 'list',
                        RmatrixList = 'list'
                      ))
# Define the function
findBiocCtoU <- function(path,                 # path where the BAM files are
                         bamFiles,             # the names of BAM files
                         BS,                   # BS genome (reference sequence)
                         utr3Ref,              # 'GRangesList' (created by threeUTRsByTranscript)
                         queries,              # subset of transcript ids for the reference (given as character vector)
                         minPile = 10,         # min coverage of the nucleotide at a position
                         minConversion = 0.25  # min conversion frequency i.e. 25% of observed bases are T instead of C
                         ){

message(paste('Function "findBiocCtoU" started!', Sys.time()))
CmatrixList <- UmatrixList <- RmatrixList <- lapply(queries, function(x){ NA })
valid <- rep(TRUE, times = length(queries))
events <- matrix(0, nrow = length(queries), ncol = length(bamFiles))
out <- new("CtoUResult")

# for each UTR region
for(q in seq_along(queries) ){

  # query Transcript & sequence
  query <- queries[q]
  region <- unlist(utr3Ref[query])
  ori    <- as.character(decode(region@strand))
  seq <- unlist(strsplit( as.character( unlist(getSeq(BS, utr3Ref[query])) ), split = ''))

  # reverse-complement if refernce sequence is from the '-' strand
  if(sort(names(table(ori)), decreasing = TRUE)[1] == '-' ) seq <- rev( unlist(strsplit((chartr("ATGC","TACG", paste0(seq, collapse = ''))), split = '')) )

  # Transcript-specific output matrix
  emat <- matrix(NA, ncol = length(seq), nrow = length(bamFiles))
  rownames(emat)  <- bamFiles
  cmat <- umat <- emat

  #erate <- rep(0, times = length(cellPath))
  for(i in seq_along(bamFiles)){
    # for each bam file (single cell or condition)
    tmp <- paste(filePath, cellPath[i], sep = '/')
    # count nucleotides at each position
    afList <- lapply(region, function(x, tmp){ alphabetFrequencyFromBam(tmp, param = x, baseOnly = TRUE) }, tmp)
    af <- do.call('rbind', afList)

    # agreement of sequnce and UTR annotation
    if(nrow(af) != length(seq)){ valid[q] <- FALSE; next }

    # check the expression and mapping quality (coverage) for the region
    seq_af <- apply(af, 1, function(x){ c("A", "C", "G", "T", 'O')[which.max(x)] })
    ix <- which(rowSums(af) > minPile)
    if( length(which(seq[ix] == seq_af[ix])) < 0.9*length(seq[ix]) & length(ix) > 100 ){ valid[q] <- FALSE }
    if( length(which(seq[ix] == seq_af[ix])) < 0.98*length(seq[ix]) | length(ix) < 50) next

    # mark the edited bases in the output matrix
    # potential sites with a C
    cidx <- seq == 'C'
    # count C and T
    cmat[i, cidx] <- af[cidx, 'C']; umat[i, cidx] <- af[cidx, 'T']

    eidx <- (rowSums(af) >= minPile & cidx)
    emat[i, eidx] <- (af[ ,'T']/rowSums(af))[eidx]
    events[i, q] <- length(which((af[ ,'T']/rowSums(af))[eidx] >= minConversion))
  }
  # Output list for (UTR-, or Transcript-wise)
  CmatrixList[[q]] <- cmat
  UmatrixList[[q]] <- umat
  RmatrixList[[q]] <- emat
 } # query loop

out@name = queries
out@valid =  valid
out@events = events
out@CmatrixList = CmatrixList
out@UmatrixList = UmatrixList
out@RmatrixList = RmatrixList
message(paste('Function "findBiocCtoU" finished!', Sys.time()))
return(out)
} # end of function

## NOT RUN:
## load the annotations (BAM files plus reference genome)
## modify this (local dependencies!) 
require(Rsamtools)
require(GenomicFeatures)
library(TxDb.Mmusculus.UCSC.mm10.ensGene)
library(GenomicAlignments)
utr3Ref <- threeUTRsByTranscript(TxDb.Mmusculus.UCSC.mm10.ensGene, use.names = TRUE)
seqlevels(utr3Ref) <-   sub("chr", "", seqlevels(utr3Ref))
filePath <- '/Volumes/g381-daten2/sheng/Share_with_others/Manuel/Single_cell_Bam_files/STAR_bam'
anno <- read.csv('/Users/manuelgoepferich/CoExpression/NSCs_17_10_2016/NSCs_annotation.csv')
allf <- list.files(path = filePath)
fileidx <- vapply(as.character(anno$cell)[1:89], function(x, allf){ grep(paste(x, '_', sep =''), allf)[1] }, 1, allf)
youngFiles <- allf[fileidx]
fileidx <- grep('tap', allf)
tapFiles <- allf[fileidx][-1]
tapFiles <- tapFiles[ -grep('.bai', tapFiles)]
fileidx <- grep('PSA', allf)
psaFiles <-  allf[fileidx[seq(1, length(fileidx), 2)]]
cellPath <- c(youngFiles, tapFiles, psaFiles)
require(BSgenome)
require(BSgenome.Mmusculus.UCSC.mm10)
BS <- BSgenome.Mmusculus.UCSC.mm10
seqlevels(BS) <-   sub("chr", "", seqlevels(BS))
load("~/MMFEATURE/RNA_EDITING/threeUTR_NSC.RData")

res <- findBiocCtoU(
  path = filePath,
  bamFiles = cellPath,
  BS = BS,
  utr3Ref = utr3Ref,
  queries = threeUTR_NSC)

# Run from the command line
# source('~/SmartSeq_Script.R')

