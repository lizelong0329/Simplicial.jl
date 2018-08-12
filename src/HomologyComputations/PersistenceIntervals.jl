

"""
    BettiNumbers(K::SimplicialComplex)::Array{Int,1}
    This computes the Betti numbers of the simplicial complex over the field F_2
    Usage: betti=BettiNumbers(K)
    Here betti[i] is the dimension of the (i-1)-dimensional homology group
"""
function BettiNumbers(K::AbstractSimplicialComplex)::Array{Int,1}
I=PersistenceIntervals(FiltrationOfSimplicialComplexes(K));
L=length(I);
betti=Array{Int,1}(L);
for i=1:L
    betti[i]=size(I[i],1);
end
return betti
end



function MySortRows(x::SingleDimensionPersistenceIntervalsType,columnnumber::Int)
  # this function sorts the rows of the matrix x by the elements of the columnnumber-th column
         return x[sortperm([x[i,columnnumber] for i=1:size(x,1)]),:]
end


"""
  Usage: Intervals=PersistenceIntervals(FilteredComplex,maxdim,baseFileName);

  This function computes Persistance intervals (over F_2) of a Filtered complex
  The inputs are
  (1) a filtered complex of type FiltrationOfSimplicialComplexes,
  (2) an upper bound for the computation of considered dimensions H_k
  (i.e. we only compute H_k for k less than or equal to maxdim)
  The output is an array, whose ith entry is the (i-1)-dimensional persistence intervals.

"""
function PersistenceIntervals(FilteredComplex::FiltrationOfSimplicialComplexes, maxdim=Inf, baseFileName::String="Temp")::PersistenceIntervalsType

    maxdim_in_filtration=maximum(FilteredComplex.dimensions);
    if isinf(maxdim); maxdim=maxdim_in_filtration;

    elseif any(FilteredComplex.dimensions.>maxdim+1) # i.e. if any of the facets' dimensions  exeeds one that is necessary to compute H_k for k<=maxdim
         return PersistenceIntervals(Skeleton(FilteredComplex,maxdim+1),maxdim,baseFileName)
    end
    # need to include time as well such as Dates.unix2datetime(time())
    WritePerseusSimplexFile(FilteredComplex, baseFileName);
    ## Use perseusWin.exe to compute the persistence intervals and store them in txt files
    TheLocationOfPerseusExecutable=PATHOF_Simplicial*"/HomologyComputations/perseus/"
    print("Computing simplicial homology. This may take some time and memory..")
    if is_windows()
        run(`$(TheLocationOfPerseusExecutable*"perseusWin.exe") nmfsimtop $baseFileName.txt $baseFileName`)
    elseif is_linux()
        perseus=TheLocationOfPerseusExecutable*"perseusLin"
        run(`chmod +x $(TheLocationOfPerseusExecutable*"perseusLin")`)
    elseif is_apple()
        perseus=TheLocationOfPerseusExecutable*"perseusMac"
        run(`chmod +x $perseus`)
    else
         error("Unsupported operating system: currently supported OSs are linux, mac os and windows. Cannot run perseus on this machine.")
    end
     run(`$perseus nmfsimtop $baseFileName.txt $baseFileName`)
     println("..done!")
    ## Read from the result txt files the persistence intervals and store them into the array Intervals
    Intervals=PersistenceIntervalsType(maxdim+1); for i=1:maxdim+1; Intervals[i]=SingleDimensionPersistenceIntervalsType(0,0); end
    for k=0:maxdim
        try
            k_dimensional_persistent_intervals=readdlm("$baseFileName"*"_$k.txt");
            # We next sort the rows of k_dimensional_persistent_intervals by the birthtimes (the first column)
            Intervals[k+1]= MySortRows(k_dimensional_persistent_intervals,1);
            catch nothing 
        end
    end

    ## Remove the files generated by write_perseus_simplex_file and perseusWin.exe
    k=0
    while k>=0
        try
            rm("$baseFileName"*"_$k.txt")
            k=k+1
        catch
            break
        end
    end
    rm("$baseFileName.txt")
    rm("$baseFileName"*"_betti.txt")

    # Finally, we replace '-1' with Inf in the interval deaths
    # The reason why -1 stands for 'utill the end' is the artifact of perseus conventions
    for i=1:length(Intervals)
          if !isempty(Intervals[i])
          Intervals[i]= map( x->((x==-1) ? Inf : x ), Intervals[i])
          end
    end

    ## Return the desired resulting array
    return Intervals
end


""" The following function transfomrs the information of filtered complex into a fixed format:
  The first row indicates how many "coordinates" are used to represent a vertex
  From the 2nd row on, each row represents a simplex, and in each row,
  (*) the first entry indicates the dimension of the simplex,
  (*) in-between the first and last entry (exclusively) are the vertex indices of the simplex.
  (*) the last entry indicates the birth time of the simplex,
"""


function WritePerseusSimplexFile(FilteredComplex::FiltrationOfSimplicialComplexes, baseFileName::String)
  # See https://www.sas.upenn.edu/~vnanda/perseus/ for file formet
         outfile = open("$baseFileName.txt", "w");
         writedlm(outfile, "1");  # dimension of data points for perseus -- ignore but leave here
         for i=1:length(FilteredComplex.faces);
             writedlm(outfile, [(length(FilteredComplex.faces[i])-1) collect(FilteredComplex.faces[i])' (FilteredComplex.birth[i])  ], ' ');
         end
         close(outfile);
end



"""
    DowkerPersistentintervals(A,maxdensity=1,maxdim=Inf,baseFileName="Temp")

    Usage: Intervals, GraphDensity=DowkerPersistentintervals(A, maxdensity,maxdim);

    This function computes persistent intervals of a Dowker complex of a matrix A
    maxdensity is a real number in the interval (0,1] that 'truncates' the filtration at the graph density maxdensity
    maxdim is the maximal dimension of the homology that we want to compute
"""
function  DowkerPersistentintervals(A,maxdensity=1,maxdim=Inf,baseFileName::String="Temp")
  N_vertices=size(A,1);
  D, GraphDensity=DowkerComplex(A,maxdensity);
  return PersistenceIntervals(D, maxdim, baseFileName),  GraphDensity;
end









"""
Usage:  Bettis = Intervals2Bettis(Intervals, NumberOfFiltrationSteps, maxdim)
This function transforms Persistent intervals to Betti Curves. Beta_0 is discarded.
The output is therefore Bettis[d,s]= the betti number \beta_d


"""
function Intervals2Bettis(Intervals::PersistenceIntervalsType, NumberOfFiltrationSteps::Int, maxdim::Int=-2)::Matrix{Int}
    # NumberOfFiltrationSteps=length(Rhos)
    if maxdim==-2 ; maxdim=length(Intervals)-1 ;end
    Bettis=zeros(Int,maxdim,NumberOfFiltrationSteps);
    for d=1:maxdim
        if size(Intervals[d+1],1)!=0
        for step=1:NumberOfFiltrationSteps
                  for k=1: size( Intervals[d+1],1)
                    if (step>=Intervals[d+1][k,1]) &&  (step<=Intervals[d+1][k,2])
                      Bettis[d, step ]+=1
                    end
                  end
        end # for step=1:NumberOfFiltrationSteps
        end
    end #   for d=1:maxdim
    return Bettis
end
