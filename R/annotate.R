#' Annotate Virulence Factors and Antibiotic Resistance Genes
#'
#' This function annotate virulence factors and the antibiotic resitance genes
#' of the genomes (\code{files}). The annotation is performed using
#' \strong{mmseqs2} software (\link{https://github.com/soedinglab/MMseqs2}) and the
#' databases \strong{Virulence Factor DataBase}
#' (\link{http://www.mgc.ac.cn/cgi-bin/VFs/v5/main.cgi}) and \strong{ResFinder}
#' (\link{https://cge.cbs.dtu.dk/services/ResFinder/}). The function can re-use the
#' previous computational steps of \code{mmseqs} or create a new index database from
#' the files. Re-use option shorten the computational time. This method use the algorithm
#' \strong{search} of \strong{mmseqs2} so it olny return high identity matchs.
#'
#'
#' @param data A \code{mmseq} object
#' @param type user must be specified if the data set is nucleotide or protein.
#' @param database A vector with the query databases:
#' \itemize{
#' \item \emph{AbR}: Antibiotic resistance database (ResFinder)
#' \item \emph{VF_A} VFDB core dataset (genes associated with experimentally verified VFs only)
#' \item \emph{VF_B} VFDB full dataset (all genes related to known and predicted VFs)
#' \item \emph{bacmet} BacMet dataset (genes associated with Biocide and Metal resistance)
#' }
#' @param query "all" or "accessory". It perform the annotation from whole
#' protein dataset or just from the accessory
#'
#' @return A \code{data.frame} with the annotation information\cr
#' \itemize{
#'  \item \emph{Genome}: Genome query
#'  \item \emph{Protein}: Proteins query
#'  \item \emph{target}: Protein subject (AbR o VF)
#'  \item \emph{pident}: Percentage of identical matches
#'  \item \emph{alnlen}: Alingment length
#'  \item \emph{mismatch}: number of mismatchs
#'  \item \emph{gapopen}: number of gaps
#'  \item \emph{qstart}: query start alingment
#'  \item \emph{qend}: query end alingment
#'  \item \emph{tstart}: target start alingment
#'  \item \emph{tend}:  target end alingment
#'  \item \emph{evalue}: evalue
#'  \item \emph{bits}: Bitscore
#'  \item \emph{DataBase}: Database (AbR, VF_A or VF_B, bacmet)
#'  \item \emph{Gene}: Gene name
#'  \item \emph{Description}: Functional annotation (VF) or category (AbR)
#' }
#' @note Keep in mind that the results from \emph{accesory} are based on the
#' annotation of the representative protein of the homologous cluster and therefore
#' does not mean that all the genomes have the same allele of the gene.
#'
#' @export
#'
#' @import dplyr
#' @import tidyr
#' @import tibble
#'
annotate <- function(data, type = "nucl", database =c("AbR","VF_A","VF_B"), query = "all")
{

  if(!is(data,"mmseq"))
  {
    stop("Error data must be a mmseq object")
  }

  if(!dir.exists(data$path))
  {
    stop("There is an error with the input data. Please be sure that you are in the right path or re-do de mmseq object")
  }

  if(grepl('linux',Sys.getenv("R_PLATFORM"))) ## Linux
  {
    proc_cpu = readLines("/proc/cpuinfo")

    if(sum(grep("avx2",proc_cpu,ignore.case = TRUE)))
    {
      mmseqPath = system.file("mmseqs.avx2", package = "pato")
    }else{
      mmseqPath = system.file("mmseqs.sse41", package = "pato")
    }
  }else if(grepl('apple',Sys.getenv("R_PLATFORM"))){ ##MacOS


    if(grepl("AVX2",system("sysctl -a | grep 'AVX2'", intern = T)))
    {
      mmseqPath = system.file("mmseqs.macos.avx2", package = "pato")
    }else{
      mmseqPath = system.file("mmseqs.macos.sse41", package = "pato")
    }
  }else{
    stop("Error, OS not supported.")
  }

  n_cores = detectCores()

  if(type == "prot")
  {
    resfinder_path <- system.file("annotation/resfinder_prot", package = "pato")
    vf_A_path <- system.file("annotation/VFDB_setA_prot", package = "pato")
    vf_B_path <- system.file("annotation/VFDB_setB_prot", package = "pato")
    bacmet <- system.file("annotation/bacmet", package = "pato")
    annot <- read.delim(system.file("annotation/annot.data", package = "pato"), stringsAsFactors = FALSE, header = TRUE, sep = "\t")
  }else if(type =="nucl")
  {
    resfinder_path <- system.file("annotation/resfinder_nucl", package = "pato")
    vf_A_path <- system.file("annotation/VFDB_setA_nucl", package = "pato")
    vf_B_path <- system.file("annotation/VFDB_setB_nucl", package = "pato")
    bacmet <- system.file("annotation/bacmet", package = "pato")
    annot <- read.delim(system.file("annotation/annot.data", package = "pato"), stringsAsFactors = FALSE, header = TRUE, sep = "\t")
  }else{
    stop("Error in data type selection: please specify 'nucl' or 'prot'")
  }

  origin <- getwd()
  setwd(data$path)
  on.exit(setwd(origin))



  if(query =="all")
  {

    rep = "all.mmseq"

  }else if (query == "accessory")
  {

    print(paste(mmseqPath," createdb all.representatives.fasta all.representatives.mm",sep = "",collapse = "")) %>% system()
    print(paste(mmseqPath," createindex all.representatives.mm tmpDir",sep = "",collapse = "")) %>% system()
    rep = "all.representatives.mm"
  }else{
    stop("Error: query must be 'all' or 'accessory'")
  }

  results <- data.frame()

  if("AbR" %in% database)
  {
    if(file.exists("abr.out.1"))
    {
      system("rm abr.out*")
    }
    if(type =="nucl")
    {

      print(paste(mmseqPath," search ",rep," ",resfinder_path," abr.out tmpDir --search-type 3", sep = "", collapse = "")) %>% system()
      Sys.sleep(1)
    }else{
      print(paste(mmseqPath," map ",rep," ",resfinder_path," abr.out tmpDir", sep = "", collapse = "")) %>% system()
      Sys.sleep(1)
    }
    print(paste(mmseqPath," convertalis ",rep," ",resfinder_path," abr.out abr.tsv", sep = "", collapse = "")) %>% system()
    Sys.sleep(1)
    tmp<- read.table("abr.tsv", header = FALSE, stringsAsFactors = FALSE,comment.char = "")

    Sys.sleep(1)
    colnames(tmp) <- c("query","target","pident","alnlen","mismatch","gapopen","qstart","qend","tstart","tend","evalue","bits")
    tmp <- tmp %>% mutate(target = gsub("_\\d+$","",target))
    results <- bind_rows(results,tmp)
  }
  if("VF_A" %in% database)
  {
    if(file.exists("vf_a.out.1"))
    {
      system("rm vf_a.out*")
    }

    if(type =="nucl")
    {
      print(paste(mmseqPath," search ",rep," ",vf_A_path," vf_a.out tmpDir --search-type 3", sep = "", collapse = "")) %>% system()
      Sys.sleep(1)
    }else{
      print(paste(mmseqPath," map ",rep," ",vf_A_path," vf_a.out tmpDir", sep = "", collapse = "")) %>% system()
      Sys.sleep(1)
    }

    print(paste(mmseqPath," convertalis ",rep," ",vf_A_path," vf_a.out vf_a.tsv", sep = "", collapse = "")) %>% system()
    Sys.sleep(1)
    tmp <- read.table("vf_a.tsv", header = FALSE, stringsAsFactors = FALSE,comment.char = "")
    Sys.sleep(1)
    colnames(tmp) <- c("query","target","pident","alnlen","mismatch","gapopen","qstart","qend","tstart","tend","evalue","bits")

    Sys.sleep(1)
    results <- bind_rows(results,tmp)

  }
  if("VF_B" %in% database)
  {
    if(file.exists("vf_b.out.1"))
    {
      system("rm vf_b.out*")
    }
    if(type =="nucl")
    {
      print(paste(mmseqPath," search ",rep," ",vf_B_path," vf_b.out tmpDir --search-type 3 ", sep = "", collapse = "")) %>% system()
      Sys.sleep(1)
    }else{
      print(paste(mmseqPath," map ",rep," ",vf_B_path," vf_b.out tmpDir", sep = "", collapse = "")) %>% system()
      Sys.sleep(1)
    }


    print(paste(mmseqPath," convertalis ",rep," ",vf_B_path," vf_b.out vf_b.tsv", sep = "", collapse = "")) %>% system()
    Sys.sleep(1)
    tmp <- read.table("vf_b.tsv", header = FALSE, stringsAsFactors = FALSE,comment.char = "")
    Sys.sleep(1)
    colnames(tmp)<- c("query","target","pident","alnlen","mismatch","gapopen","qstart","qend","tstart","tend","evalue","bits")
    Sys.sleep(1)
    results <- bind_rows(results,tmp)
  }
  if("bacmet" %in% database)
  {
    if(file.exists("bacmet.out.1"))
    {
      system("rm bacmet.out*")
    }
    if(type =="nucl")
    {
      print(paste(mmseqPath," search ",rep," ",bacmet," bacmet.out tmpDir --search-type 3 ", sep = "", collapse = "")) %>% system()
      Sys.sleep(1)
    }else{
      print(paste(mmseqPath," map ",rep," ",bacmet," bacmet.out tmpDir", sep = "", collapse = "")) %>% system()
      Sys.sleep(1)
    }


    print(paste(mmseqPath," convertalis ",rep," ",bacmet," bacmet.out bacmet.tsv", sep = "", collapse = "")) %>% system()
    Sys.sleep(1)
    tmp <- read.table("bacmet.tsv", header = FALSE, stringsAsFactors = FALSE,comment.char = "")
    Sys.sleep(1)
    colnames(tmp)<- c("query","target","pident","alnlen","mismatch","gapopen","qstart","qend","tstart","tend","evalue","bits")
    Sys.sleep(1)
    results <- bind_rows(results,tmp)
  }



  results <- inner_join(results,annot, by = c("target" = "ID")) %>% separate(query,c("Genome","Protein"), sep = "#")
  if(!("VF_B" %in% database)){
    results <- results %>% filter(DataBase != "VFB")
  }

  return(results)
}


