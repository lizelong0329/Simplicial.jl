
"""
The following type encodes a filtration of Z2 chain complexes.
    We are going to use this to compute the homology over Z2.
    Also, note that the conventions are a bit different here then in the GradedPoset type:
    * We do _not_ want to have a cell of dimension (-1) here, so the dimensions are all non-negative numbers.
    * The elements of the posets are ordered _first_ by weight and within the same weight by the dimension.
      In particular, higher-dimensional element may apear earlier if it's weigth is smaller.
    * the convention of how boundaries are reffered to is different from that in the GradedPoset type..

"""

type FiltrationOfZ2Complexes

  dimensions::Array{Int,1} # this is the list of dimensions of the graded poset.
                           # Here length(dimensions) is equal to the total number of elements in the poset.
                           # dimensions[i] is the dimension of the current element
                           # This can not be smaller then -1 (corresponding to the empty set)

  dim::Int   # the maximun of dimensions

  boundaries::Array{Array{Int,1},1} # this is a list of boundaries for each poset element.
                                    # For the i-th element, boundaries[i] lists all the boundaries, note that each element in boundaries[i] is smaller then i.
                                    # The length of this array is the same as length(dimensions)

  birth::Array{Int,1}               # The birth times of each element. The length of this array is the same as length(dimensions)

  depth::Int                        # this is the depth of filtration, i.e. the total  number of filtration levels

    function FiltrationOfZ2Complexes(FD::FiltrationOfDirectedComplexes);

      if isempty(FD.faces)
        return   new(Array{Int,1}(0), -2, 0, Array{Array{Int,1},1}(), Array{Int,1}(),0);
      end
      depth = FD.depth
      dim = maximum(FD.dimensions)
      faces = []
      birth = []
      dimensions = []

      if issorted(FD.birth)
         # the births are already sorted
         sorted_births = FD.birth;
         sorted_faces =FD.faces;
      else # the births are out of order
      sorted_births = sort(FD.birth)
      # sort FD.faces according to the birthtimes, from earliest to latest just in case they weren't sorted already
      # the next line is whree we sort faces,
      # we zip the births array with the faces array, then sort by the first columns, then extract the second column
      # Notice that we use the original births array to sort by the original births array, not the sorted one
      sorted_faces = getindex.(sort(collect(zip(FD.birth, FD.faces)), by=x -> x[1]),2)
      end

      # for each facet we extract all the subsequences, check whether they occur in previous filtrations, then add it to the list of faces if not
      # that's some real bad coding happening here
      for j in 1:length(sorted_faces)
        facet = sorted_faces[j]
        for len in 1:length(facet)-1
          for boundary in Combinatorics.combinations(facet, len)
            if !(boundary in faces)
              push!(faces, boundary)
              push!(birth, sorted_births[j])
              push!(dimensions, length(boundary)-1)
            end
          end
        end
      push!(faces, facet)
      push!(birth, sorted_births[j])
      push!(dimensions, length(facet)-1)
      end

      # "faces" is now an array of faces, ordered by filtration, and within filtration -- by dimension
      # now we go through that array, and for each face, find the boundaries in that array

      boundaries = Array{Array{Int,1}}(length(faces))

      for i in 1:length(faces)
        face = faces[i]
        boundaries[i] = []
        if length(face) > 1
             for b in Combinatorics.combinations(face, length(face)-1)
                  push!(boundaries[i],findfirst(faces,b))
             end
        end

      end

    new(dimensions,dim,boundaries,birth,depth)
    end
end  # type FiltrationOfZ2Complexes









"""
function PHATarray(Fz::FiltrationOfZ2Complexes)::Array{Int64,2};
This  utility function formats Fz::FiltrationOfZ2Complexes
into array that can be input into PHAT.
Usage:
A=PHATarray(Fz)
"""
function PHATarray(Fz::FiltrationOfZ2Complexes)::Array{Int64,2};
Nelements=length(Fz.dimensions)
cells=Array{Int,1}([]); # initialize as empty

# now we push the appropriate numbers into the array cells
        for currentcellnumber=1:Nelements;
            d=Fz.dimensions[currentcellnumber]
            if d==0;    append!(cells,[currentcellnumber,0,-1]);
            else        append!(cells,[currentcellnumber,d])
                        sort!(Fz.boundaries[currentcellnumber]); # sort the boundaries array first
                        append!(cells, Fz.boundaries[currentcellnumber]);
                        push!(cells,-1);
            end
        end

return reshape(cells, 1,length(cells))
end




function show(Fz::FiltrationOfZ2Complexes)
  depth=Fz.depth;
 print("A fitration of depth $depth of Z_2 Complexes in max dimention $(Fz.dim)\n");
 println("_________________________________________________")
 print_with_color(:blue, "facet # ") ;print(" |");
 print_with_color(:cyan, " birth time"); print(" |") ;
 print_with_color(:green, " dimension"); print(" |") ;
 print_with_color(:light_magenta, " boundaries");
 println();
 println("_________________________________________________")

for i=1:length(Fz.birth);
  print_with_color(:blue, "$i       ") ;print(" |");
  print_with_color(:cyan, " $(Fz.birth[i])         "); print(" |") ;
  print_with_color(:green, "$(Fz.dimensions[i])         "); print(" |") ;
  if ! isempty(Fz.boundaries[i])
    print_with_color(:light_magenta, " $((Fz.boundaries[i]))")
  else print_with_color(:light_magenta," emptyset  ")
  end


  println();
 end
println();
end
