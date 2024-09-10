library("rjson")

GENERATED_FILES = "../generated_files"

JVM_DATA_DIR = "jvm_results"
JS_DATA_DIR = "js_results"
RESULT_CHECK = TRUE

MIN_RUNS = 30
MIN_RUNS_10H = 1

TIMEBUDGET = c("1h")
DATA_FILE = "../results/data_bb.csv"

EXCLUDED_TOOLS = c()
HLINE = "__HLINE__"
FAULTS_SUTS <- c("rest-faults", "rest-faults-local")

BEST_BB_TOOLS <- c("evomaster_bb_v2", "Schemathesis")

## init raw jvm+js coverage file to data_bb.csv based on results produced by jacoco
init <- function (){

  ## jvm jacoco
  TABLE = DATA_FILE
  unlink(TABLE)
  sink(TABLE, append=TRUE, split=TRUE)

  cat("SUT,TOOL,LINES,COVERED,FILENAME,TB,PLATFORM\n")

  for (tb in TIMEBUDGET){
    jvm_folder = paste0(JVM_DATA_DIR,"/TB_",tb, sep="")
    for(table in sort(list.files(jvm_folder,recursive=TRUE,full.names=TRUE,pattern="^.*jacoco.csv$")) ){

        # cat("Reading: ",table,"\n")

        tryCatch( {dt <- read.csv(table,header=T)} ,
                  error = function(e){
                    cat("Error in reading table ",table,"\n", paste(e), "\n")
                  })
        fileName = basename(table)
        tokens = strsplit(fileName, "__")
        sut = tokens[[1]][1]
        tool = tokens[[1]][2]
        cat(sut,",",tool,",",sep="")

        missed = sum(dt$LINE_MISSED)
        covered = sum(dt$LINE_COVERED)
        total = missed + covered
        cat(total,",",covered,",",fileName,",",tb,",JVM\n",sep="")
      }

      js_folder = paste0(JS_DATA_DIR,"/TB_",tb, sep="")
      for(table in sort(list.files(js_folder,recursive=TRUE,full.names=TRUE,pattern="^.*.json$")) ){

          # cat("Reading: ",table,"\n")

          tryCatch( {dt <- fromJSON(paste(readLines(table), collapse=""))},
                    error = function(e){
                      cat("Error in reading table ",table,"\n", paste(e), "\n")
                    })
          fileName = basename(table)
          tokens = strsplit(fileName, "__")
          sut = tokens[[1]][1]
          tool = tokens[[1]][2]

          covered = dt$total$lines$covered
          total = dt$total$lines$total

          if(strtoi(covered) > 0){
              #there can be issues with c8, so 0 happens if no coverage file was generated
              cat(sut,",",tool,",",sep="")
              cat(total,",",covered,",",fileName,",",tb,",JS\n",sep="")
          }
        }
  }

  sink()
}

toolLabel <- function(id){

  if(id == "evomaster_bb" || id == "evomaster_bb_v2" || id == "evomaster_bb_v3"){
      return("\\evo BB")
  }

  
  if(id == "wb"){
    return("\\evo WB")
  }
  
  if(id == "RestTestGenV2"){
    return(paste("\\RestTestGenVT",sep=""))
  }

  if(id == "Restler_v9_2_4"){
    return(paste("\\Restler",sep=""))
  }
  
  return(paste("\\",id,sep=""))
}

getMinRun <- function(sut, tool, tb){
  if(sut %in% FAULTS_SUTS)
    return(0)
  
  if(identical(tb, "1h"))
    return(MIN_RUNS)
  if(identical(tb, "6m")){
    if(tool %in% BEST_BB_TOOLS)
      return(MIN_RUNS)
    else
      return(0)
  }
  if(identical(tb, "10h")){
    if(tool %in% BEST_BB_TOOLS)
      return(MIN_RUNS_10H)
    else
      return(0)
  }
  return(0)
}

resultPreCheck <- function(){
  dt <- read.csv(DATA_FILE, header = T)

  # dt <- dt[dt$PLATFORM == "JVM"]

  tools = selectedTools(sort(unique(dt$TOOL))) #sort(unique(dt$TOOL))
  suts = sort(unique(dt$SUT))
  
  RESULTS_PRE_CHECK = paste(GENERATED_FILES, "/results_pre_check.txt", sep = "")
  unlink(RESULTS_PRE_CHECK)
  sink(RESULTS_PRE_CHECK, append = TRUE, split = TRUE)
  
  cat("\n\n=================Summary=================\n")
  cat("SUT:",length(suts),"\n",sep="")
  cat("TBS:",length(TIMEBUDGET),"\n",sep="")
  cat("Tools:",length(tools),"\n",sep="")
  
  missing_runs_df <- data.frame(matrix(ncol = 4, nrow = 0))
  missing_runs_colums <- c("TB","tool", "sut", "runs")
  colnames(missing_runs_df) <- missing_runs_colums
  
  for (tb in TIMEBUDGET) {
    cat("\n\n=================TB:",tb,"=================\n", sep="")
    
    tbinfo <- paste(tb, sep="")
    for (j in 1:length(suts)) {
      cat("\n\n-------------------------------------\n")
      sut = suts[[j]]
      cat(sut, "\n")
      
      data <- vector(mode="list", length=length(tools))
      tot = max(dt$LINES[dt$SUT == sut])
      
      sutInfo <- paste(tbinfo, sut, sep=" ")
      for (i in 1:length(tools)){
        t = tools[i]
        cmin <- getMinRun(sut, t, tb)
        
        if(cmin > 0){
          cat(t, "\n")
          cov = dt$COVERED[dt$SUT==sut & dt$TOOL==t & dt$TB == tb]
          cat("Runs: ", length(cov), "\n")
          cov = cov[validateLine(cov,sut, t)]
          invalidMask = dt$SUT==sut & dt$TOOL==t & dt$TB == tb & !(validateLine(dt$COVERED, sut, t))
          for (msg in dt$FILENAME[invalidMask]) {
            cat(msg, "\n")
          }
          cat("Valid Runs: ", length(cov), "\n")
          cat("\n\n--------------\n")
          
          
          if(length(cov) < cmin){
            needed <- cmin - length(cov)
            #info <- c(t, sutInfo, needed)
            #missing_runs <- append(missing_runs, info)
            #missing_runs_df <- rbind(missing_runs_df, info)
            missing_runs_df[nrow(missing_runs_df) + 1,] <-  c(tb, t, sut, needed)
            
          }
        }
      }
      
    }
    
    cat("\n\n-------------------------------------\n")
    
  }
  
  if(nrow(missing_runs_df) > 0){
    cat("\n\n=================Needed Runs=================\n", sep="")
    for (nr in 1:nrow(missing_runs_df)) {
      for (cr in 1:ncol(missing_runs_df)) {
        cat(missing_runs_df[nr, cr], " ")
      }
      cat("\n")
    }
    
    cat("\n\n=================Commands=================\n", sep="")
    PORT_START = 26000
    
    mtbs <- sort(unique(missing_runs_df$TB))
    mruns <- sort(unique(missing_runs_df$runs))
    mtools <- sort(unique(missing_runs_df$tool))
    aa_exp_index <- 7
    aa_run_start <- 31
    for(mt in mtbs){
      for (mr in mruns) {
        for (mtool in mtools) {
          
          aa_dir <- paste("AA_TB",mt,"_R",mr,"_T_",mtool,"_",aa_exp_index, sep = "")
          cmddf <- missing_runs_df[missing_runs_df$TB==mt & missing_runs_df$runs==mr & missing_runs_df$tool==mtool,]
          if(nrow(cmddf) > 0){
            msutsinfo <- NULL
            for (msut in unique(cmddf$sut)) {
              if(!is.null(msutsinfo))
                msutsinfo <- paste(msutsinfo, ",", sep = "")
              msutsinfo <- paste(msutsinfo, msut, sep = "")
            }
            # mtoolsinfo <- NULL
            # for (mtool in unique(cmddf$tool)) {
            #   if(!is.null(mtoolsinfo))
            #     mtoolsinfo <- paste(mtoolsinfo, ",", sep = "")
            #   mtoolsinfo <- paste(mtoolsinfo, mtool, sep = "")
            # }
            ##TODO fix later, TB is hardcoded
            cat("generating ", strtoi(mr, base=0L) * nrow(cmddf), "task scripts \n")
            cat("python bb.py ",PORT_START," ",aa_dir," ",aa_run_start," ",aa_run_start+strtoi(mr, base=0L)-1," 36000 ",msutsinfo," ",mtool,"\n\n")
            
            PORT_START <- PORT_START + strtoi(mr, base=0L) * nrow(cmddf) * 10 + 1000
            aa_exp_index <- aa_exp_index + 1
          }
          
        }
      }
    }
  }
  sink()
}

SUTS_INFO <- list(
  list(name="catwatch", endpoints=23,  minValidLine = 178, successValidLine = 200, lg="Java", files = 106, fileLoc=9636, instruLoc=1835),
  list(name="cwa-verification", endpoints=5, minValidLine = 156, successValidLine=200, lg="Java", files = 47, fileLoc=3955, instruLoc=711),
  list(name="features-service", endpoints=18,minValidLine = 96, successValidLine=150, lg="Java", files = 39, fileLoc=2275, instruLoc=457),
  list(name="gestaohospital-rest", endpoints=20, minValidLine = 210, successValidLine=227, lg="Java", files = 33, fileLoc=3506, instruLoc=1056),
  list(name="ind0", endpoints=20, minValidLine = 127, successValidLine=138, files = 75, lg="Java", fileLoc=5687, instruLoc=1674),
  list(name="languagetool", endpoints=2, minValidLine = 701, successValidLine=750, lg="Java", files = 1385, fileLoc=174781, instruLoc=45445),
  ### 192 from core/src/test/kotlin/org/evomaster/core/problem/rest/RestActionBuilderV3Test.kt
  list(name="ocvn-rest", endpoints=258,minValidLine = 694, successValidLine=1000, lg="Java", files = 526, fileLoc=45521, instruLoc=6868),
  list(name="proxyprint", endpoints=115, minValidLine = 125, successValidLine=128, lg="Java", files = 73, fileLoc=8338, instruLoc=2958),
  list(name="rest-ncs", endpoints=6, minValidLine = 14, successValidLine =100, lg="Java", files = 9, fileLoc=605, instruLoc=275),
  list(name="rest-news", endpoints=7, minValidLine = 20,  successValidLine=30, lg="Kotlin", files = 11, fileLoc=857, instruLoc=144),
  list(name="rest-scs", endpoints=11, minValidLine = 20, successValidLine=100, lg="Java", files = 13, fileLoc=862, instruLoc=295),
  list(name="restcountries",endpoints=22,  minValidLine = 19, successValidLine=100, lg="Java", files = 24, fileLoc=1977, instruLoc=543),
  list(name="scout-api", endpoints=49, minValidLine = 321, successValidLine=400, lg="Java", files = 93, fileLoc=9736, instruLoc=2673),
  

  list(name="genome-nexus", endpoints=23, minValidLine = 643, successValidLine=643, lg="Java", files = 405, fileLoc=30004, instruLoc=5008),
  list(name="reservations-api", endpoints=7, minValidLine = 73, successValidLine=73, lg="Java", files = 39, fileLoc=1853, instruLoc=279),
  list(name="bibliothek", endpoints=8, minValidLine = 94, successValidLine=94, lg="Java", files = 33, fileLoc=2176, instruLoc=267),
  list(name="gestaohospital-rest", endpoints=20, minValidLine = 227, successValidLine=227, lg="Java", files = 33, fileLoc=3506, instruLoc=1056),
  list(name="session-service", endpoints=8, minValidLine = 81, successValidLine=81, lg="Java", files = 15, fileLoc=1471, instruLoc=159),
  
  # fault
  list(name="rest-faults", endpoints=8, minValidLine = 1, successValidLine=1, lg="Java", files = 3, fileLoc=115, instruLoc=26),
  list(name="rest-faults-local", endpoints=8, minValidLine = 1, successValidLine=1, lg="Java", files = 3, fileLoc=115, instruLoc=26),
  
  #JS
  list(name="cyclotron", endpoints=50, minValidLine = 1015, successValidLine=1300, lg="JavaScript", files = 25, fileLoc=5803, instruLoc=2458),
  list(name="disease-sh-api", endpoints=34, minValidLine = 1450, successValidLine=1453, lg="JavaScript", files = 57, fileLoc=3343, instruLoc=2997),
  list(name="realworld-app", endpoints=19, minValidLine = 643, successValidLine=650, lg="TypeScript", files = 37, fileLoc=1229, instruLoc=1077),
  #list(name="realworld-app", minValidLine = 870, successValidLine=870, lg="TypeScript", files = 37, fileLoc=1229, instruLoc=1323),
  list(name="js-rest-ncs", endpoints=6, minValidLine = 340, successValidLine=400, lg="JavaScript", files = 8, fileLoc=775, instruLoc=768),
  list(name="js-rest-scs", endpoints=11, minValidLine = 565, successValidLine= 600, lg="JavaScript", files = 13, fileLoc=1046, instruLoc=1044),
  list(name="spacex-api", endpoints=94, minValidLine = 2393, successValidLine=2396, lg="JavaScript", files =63, fileLoc=4966, instruLoc=3144)
)


findSutByName <- function(name) {
  for (i in  1:length(SUTS_INFO)) {
    if (identical(SUTS_INFO[[i]]$name, name)) {
      return(SUTS_INFO[[i]])
    }
  }
  return(NULL)
}


validateLine <- function(line, sut, tool){
  if (!RESULT_CHECK)
    return(TRUE)
  
  info <- findSutByName(sut)

  if (is.null(info)){
    stop("Fail to find info about the sut ", sut)
  }
  
  # if (is.null(toolInfo)){
  #   stop("Fail to find tool info about the sut ", sut)
  # }
  

  # valid = line >= info[["minValidLine"]]
  # if (is.null(success)){
  #   stop("Fail to find tool info ", tool)
  # }
  # 
  valid = (line >= info[["minValidLine"]])
  return(valid)
}

### dt is bb data.csv
orderSUTs <- function(dt, excluded=c()){
  JS_SUTS = sort(selectedSUTs(unique(dt$SUT[dt$PLATFORM == "JS"]), excluded)) 
  JVM_SUTS = sort(selectedSUTs(unique(dt$SUT[dt$PLATFORM == "JVM"]), excluded))
  
  return(list(seq=c(JS_SUTS, JVM_SUTS), sep=length(JS_SUTS)+1))
}

###
selectedTools <- function(tools){
  return(tools[!tools %in% EXCLUDED_TOOLS])
}


###
selectedSUTs <- function(all, excluded){
  return(all[!all %in% excluded])
}

### formatUtil
measureA <- function(a,b){
  
  if(length(a)==0 & length(b)==0){
    return(0.5)
  } else if(length(a)==0){
    ## motivation is that we have no data for "a" but we do for "b".
    ## maybe the process generating "a" always fail (eg out of memory)
    return(0)
  } else if(length(b)==0){
    return(1)
  }
  
  r = rank(c(a,b))
  r1 = sum(r[seq_along(a)])
  
  m = length(a)
  n = length(b)
  A = (r1/m - (m+1)/2)/n
  
  return(A)
}


## (a-b)/b
relative <- function(a, b, includePrecentage=T){
  relativev="Inf"
  if(mean(b) >0){
    relative = (mean(a) - mean(b))/mean(b) 
    indicator <- ""
    if(relative > 0)
      indicator <- "+"
    suffix <- ""
    if(includePrecentage)
      suffix <- "\\%"
    relativev = paste(indicator,formatC( relative *100, digits = 2, format = "f"), suffix,sep = "")
  }
  return(relativev)
}

diff <- function(a, b, rf = FALSE){
  d="Inf"
  if(b >0){
    diffValue = a-b
    relative = diffValue/b 
    indicator <- ""
    if(relative > 0)
      indicator <- "+"
    if(rf)
      dv = paste(indicator,formatC( relative *100, digits = 2, format = "f"), "\\%",sep = "")
    else
      dv = paste(indicator,formatC(diffValue, digits = 2, format = "f"), sep = "")
  }
  return(dv)
}

boldValue <- function(value){
  return(paste("\\textbf{", value,"}", sep=""))
}

formatedValue <- function(value, a12, p){
  if(is.nan(p) | p >= 0.05)
    return(value)
  if(a12 > 0.5)
    return(boldValue(value))
  return(paste("\\textcolor{red}{", value,"}", sep=""))
}

formatedPvalue <- function(p){
  if(is.nan(p)){
    return(p)
  } else if (p < 0.001) {
    return( "$\\le $0.001")
  } else {
    return(formatC(p, digits = 3, format = "f"))
  }
}

############## tables in the paper (TODO only contain fse tool comparison) ######################

tableSUTStat <- function(){
  
  dt <- read.csv(DATA_FILE, header = T)
  ordered = orderSUTs(dt, FAULTS_SUTS)
  suts = ordered[["seq"]]
  seqIndex = ordered[["sep"]]
  
  TABLE = paste(GENERATED_FILES, "/sut_info.tex", sep = "")
  unlink(TABLE)
  sink(TABLE, append = TRUE, split = TRUE)
  
  # cat("\\begin{tabular}{  l l r r r r }\\\\ \n")
  cat("\\begin{tabular}{  l r r r }\\\\ \n")
  
  cat("\\toprule \n")
  
  z <- function(x){return(paste(" & ", toolLabel(tools[x])))}
  # cat("SUT & Language & Endpoints & Files & File LOCs & c8/JaCoCo LOCs \\\\ \n", sep = "")
  cat("SUT & Endpoints & Files & File LOCs  \\\\ \n", sep = "")
  
  cat("\\midrule \n")
  
  totalEndpoints <- c(0,0)
  totalFiles <- c(0,0)
  totalFileLoc <-c(0,0)
  totalInstruLoc <-c(0,0)
  
  i <- 1
  
  for (j in 1:length(suts)) {
    sut = suts[[j]]
    
    if(j == seqIndex){
      i <-2
#       cat("\\hline \n")
    }
    
    
    sutinfo <- findSutByName(sut)
     
    cat("\\emph{", sut, "} ",
        # " & ", sutinfo[["lg"]],
        " & ", sutinfo[["endpoints"]],
        " & ", sutinfo[["files"]],
        " & ", sutinfo[["fileLoc"]],
        # " & ", sutinfo[["instruLoc"]],
        "\\\\ \n", sep = "")
    
    totalEndpoints[i] <- totalEndpoints[i] + sutinfo[["endpoints"]]
    totalFiles[i] <- totalFiles[i] + sutinfo[["files"]]
    totalFileLoc[i] <- totalFileLoc[i] + sutinfo[["fileLoc"]]
    totalInstruLoc[i] <- totalInstruLoc[i] + sutinfo[["instruLoc"]]
  }

  
  
  cat("\\midrule \n")
  
  cat("\\emph{Total} ",
      "& ", paste(totalEndpoints[1]+totalEndpoints[2], 
                  sep = ""),
      " & ",paste(totalFiles[1]+totalFiles[2], 
                  sep = ""),
      " & ", paste(totalFileLoc[1]+totalFileLoc[2], 
                   sep = ""),
      "\\\\ \n", sep = "")
  
  cat("\\bottomrule \n")
  cat("\\end{tabular} \n")
  
  sink()
}


tableUTests <- function(target,tb="1h"){

  dt <- read.csv(DATA_FILE, header = T)

  # tools = sort(unique(dt$TOOL))
  tools = selectedTools(sort(unique(dt$TOOL)))
  tools = tools[tools != target]

  # suts = sort(unique(dt$SUT))
  ordered = orderSUTs(dt)
  suts = ordered[["seq"]]
  seqIndex = ordered[["sep"]]

  TABLE = paste(GENERATED_FILES, "/tableUTests_",tb,"_",target,".tex", sep = "")
  unlink(TABLE)
  sink(TABLE, append = TRUE, split = TRUE)

  cat("\\begin{tabular}{ l ",paste(rep("r ", length(tools)),collapse = '' ), "  }\\\\ \n")
  cat("\\toprule \n")

  z <- function(x){return(paste(" & ", toolLabel(tools[x])))}
  cat("SUT ", paste(lapply(1:length(tools), z), collapse = '')," \\\\ \n", sep = "")


  cat("\\midrule \n")

  for (j in 1:length(suts)) {
    sut = suts[[j]]
    
    if(j == seqIndex){
      cat("\\hline \n")
    }

    cat("\\emph{", sut, "}", sep = "")

    x = dt$COVERED[dt$SUT==sut & dt$TOOL==target & dt$TB == tb]
    x = x[validateLine(x, sut, target)]

    for (i in 1:length(tools)){
      t = tools[i]
      raw_cov = dt$COVERED[dt$SUT==sut & dt$TOOL==t & dt$TB == tb]
      y = raw_cov[validateLine(raw_cov,sut, t)]

      w = wilcox.test(x, y)
      p = w$p.value

      cat(" & ")
      if(is.nan(p)){
        cat(p)
      } else if (p < 0.001) {
        cat( "{\\bf 0.001}")
      } else {
        if(p <= 0.05){
          cat("{\\bf ")
        }
        cat(formatC(p, digits = 3, format = "f"))
        if(p <= 0.05){
          cat("}")
        }
      }
    }
    cat(" \\\\ \n")
  }

  cat("\\bottomrule \n")
  cat("\\end{tabular} \n")

  sink()
}

tableUTestsAll <- function(){

  tools = c("evomaster_bb_v2","Schemathesis")

 for(tool in tools){
  #for (tb in TIMEBUDGET) {
#     tableUTests(tool,tb)
    tableUTests(tool)
  #}
 }
}

tableBBAll <- function(){
  for (tb in TIMEBUDGET) {
    tableBB(tb)
  }
}

tableBB <- function(tb="1h"){

  dt <- read.csv(DATA_FILE, header = T)

  tools = selectedTools(sort(unique(dt$TOOL)))
  
  
  # suts = sort(unique(dt$SUT))
  ordered = orderSUTs(dt, FAULTS_SUTS)
  suts = ordered[["seq"]]
  seqIndex = ordered[["sep"]]

  TABLE = paste(GENERATED_FILES, "/tableBB_",tb,".tex", sep = "")
  unlink(TABLE)
  sink(TABLE, append = TRUE, split = TRUE)

  cat("\\begin{tabular}{ l ",paste(rep("r ", length(tools)),collapse = '' ), "  }\\\\ \n")
  cat("\\toprule \n")

  z <- function(x){return(paste(" & ", toolLabel(tools[x])))}
  cat("SUT ", paste(lapply(1:length(tools), z), collapse = '')," \\\\ \n", sep = "")

  avgs = matrix(nrow = length(suts), ncol = length(tools))
  ranks = matrix(nrow = length(suts), ncol = length(tools))

  cat("\\midrule \n")

  for (j in 1:length(suts)) {
    sut = suts[[j]]
    
    if(j == seqIndex){
      cat("\\hline \n")
    }

    cat("\\emph{", sut, "}", sep = "")

    data <- vector(mode="list", length=length(tools))
    tot = max(dt$LINES[dt$SUT == sut])

    for (i in 1:length(tools)){
      t = tools[i]
      raw_cov = dt$COVERED[dt$SUT==sut & dt$TOOL==t & dt$TB == tb]
      cov = raw_cov[validateLine(raw_cov,sut, t)]
      cov = ( cov / tot) * 100
      data[[i]] = cov
      avgs[j,i] = mean(cov)
    }

    ranks[j,] = rank(-avgs[j,])

    for (i in 1:length(tools)){
      cov = data[[i]]
      a = mean(cov)

      cat(" & ")

      if (a == max(avgs[j,])){
        cat("{\\bf ")
      }

      cat(formatC(a, digits = 1, format = "f"))
      cat(" [",formatC(min(cov), digits = 1, format = "f"), sep = "")
      cat(",", formatC(max(cov), digits = 1, format = "f"), sep = "")
      cat("]")
      cat(" (",ranks[j,i],")",sep="")

      if (a == max(avgs[j,])){
        cat("}")
      }
    }
    cat(" \\\\ \n")
  }

  cat("\\midrule \n")

  cat("Average ")
  for (i in 1:length(tools)){
    cat(" & ")
    cat(formatC(mean(avgs[,i]), digits = 1, format = "f"))
    cat(" (",formatC(mean(ranks[,i]), digits = 1, format = "f"),")",sep="")
  }
  cat(" \\\\ \n")
  cat("\\hline \n")
  
  fr = friedman.test(ranks)
  csr = formatC(fr$statistic, digits = 3, format = 'f')
  better <- 0
  if(fr$p.value < 0.05){
    better <- 1
  }
  
  fresult = formatedValue(paste("$\\chi^2$ = ",csr,", $p$-value = ",formatedPvalue(fr$p.value), sep = ""), better, fr$p.value)
  #\\chi^2$=
  cat("Friedman Test & \\multicolumn{",length(tools),"}{r}{",fresult," }", sep = "")
  cat(" \\\\ \n")
  cat("\\bottomrule \n")
  cat("\\end{tabular} \n")

  sink()
}


barPlotAvgTB <- function(){
  
  dt <- read.csv(DATA_FILE, header = T)
  tools = selectedTools(sort(BEST_BB_TOOLS))
  ordered = orderSUTs(dt, FAULTS_SUTS)

  suts = ordered[["seq"]]

  TBinfo <- c("6m", "1h", "10h")

  for (t in tools) {


    bilanM <- matrix(rep(0, length(TBinfo) * length(suts)),nrow = length(TBinfo), ncol = length(suts))
    stdevM <- matrix(rep(0, length(TBinfo) * length(suts)),nrow = length(TBinfo), ncol = length(suts))

    rowIndex <-1
    for (tb in TBinfo) {

      colIndex <- 1
      for (i in 1:length(suts)) {
        sut <- suts[i]
        tot = max(dt$LINES[dt$SUT == sut & dt$TB == tb])
        raw_cov = dt$COVERED[dt$SUT==sut & dt$TOOL==t & dt$TB == tb]
        cov = raw_cov[validateLine(raw_cov,sut, t)]
        cov = ( cov / tot) * 100
        a = formatC(mean(cov), digits = 2, format = "f")
        std = formatC(sd(cov), digits = 2, format = "f")

        bilanM[rowIndex, colIndex] = as.numeric(a)
        stdevM[rowIndex, colIndex] = as.numeric(std)

        colIndex <- colIndex+1
      }

      rowIndex <- rowIndex + 1
    }
    
    colnames(bilanM) = suts
    rownames(bilanM) = TBinfo
    lim <- 1.2*max(bilanM)
    
    # error.bar <- function(x, y, upper, lower=upper, length=0.1,...){
    #   arrows(x,y+upper, x, y-lower, angle=90, code=3, length=length, ...)
    # }
    
    colnames(stdevM) = suts
    rownames(stdevM) = TBinfo
    #stdevM <- stdevM * 1.96 / 10
    
    n <- length(suts)
    
    pdf(paste(GENERATED_FILES, "/",t,"_plot.pdf", sep = ""),width=20, height=4)
    
    par(mar = c(4, 2, 0.5, 0))
    mbar <- barplot(as.numeric(bilanM), beside=TRUE, 
                          density=rep(c(15,15,15), n), angle=rep(c(30,0,120), n), col="black", space = rep(c(1,0.5,0.5), n),
                          ylim=c(0,110), ylab="Coverage",cex.names=0.8, cex.axis=0.8, xlim=c(4, 92))
    
    
    #error.bar(mbar,bilanM, stdevM)
    
    
    text(mbar, par("usr")[3] - 1.5, srt = 30, adj = 1,
         labels = c(t(matrix(c(rep("", n), suts, rep("",n)), nrow = n, ncol = 3))),
         xpd = TRUE, cex = 0.8)
    
    # text(x=-1, as.numeric(bilanM)[1]+3, "coverage", cex=0.7)
    # text(x=-1, as.numeric(bilanM)[1]+9, "std", cex=0.7, font=2)
    
    text(mbar, as.numeric(bilanM)+3, as.numeric(bilanM), cex=0.7)
    text(mbar, as.numeric(bilanM)+9, as.numeric(stdevM), cex=0.7, font=2)
    legend(92, 95, TBinfo, cex = 0.8, density=c(20,20,20) , angle=c(30,0,120) , col = "black")
    dev.off()
    
  }
  
}

