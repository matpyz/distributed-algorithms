# Copyright 2017 Mateusz K. Pyzik, all rights reserved.
# Algorithm builds a spanning tree using BFS
# Time: O(|V|)
# Messages: 2|E|

Graph = Vector{Set{Int}}
Parents = Vector{Int}
Children = Vector{Set{Int}}

function spanningTree(G :: Graph) :: Tuple{Parents, Children}
  n = length(G)
  root = 1
  channels = [Channel{Tuple{Symbol, Int}}(length(G[i])) for i=1:n]
  parents = zeros(n)
  children = [Set{Int}() for i=1:n]
  @sync for id = 1:n
    if id == root
      @async rootProcess(id, G, channels, parents, children)
    else
      @async regularProcess(id, G, channels, parents, children)
    end
  end
  return parents, children
end

function rootProcess(myid, G, chnnl, prnt, chld)
  prnt[myid] = myid
  for id ∈ G[myid]
    put!(chnnl[id], (:search, myid))
  end
  received = 0
  expected = 2length(G[myid])
  while received < expected
    (msg, sender) = take!(chnnl[myid])
    received += 1
    if msg == :search
      put!(chnnl[sender], (:no, myid))
    elseif msg == :yes
      push!(chld[myid], sender)
    end
  end
end

function regularProcess(myid, G, chnnl, prnt, chld)
  received = 0
  expected = 2length(G[myid])
  while received < expected
    (msg, sender) = take!(chnnl[myid])
    received += 1
    if msg == :search
      if prnt[myid] == 0
        put!(chnnl[sender], (:yes, myid))
        prnt[myid] = sender
        for id ∈ G[myid]
          put!(chnnl[id], (:search, myid))
        end
      else
        put!(chnnl[sender], (:no, myid))
      end
    elseif msg == :yes
      push!(chld[myid], sender)
    end
  end
end
