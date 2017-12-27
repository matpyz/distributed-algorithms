# Copyright 2017 Mateusz K. Pyzik, all rights reserved.
# Algorithm finds the leader in a bidirectional ring network
# Time complexity: O(n)
# Message complexity: O(n log n) (asymptoptically optimal)
# Implementation follows the presentation of BULLY algorithm from:
# http://compalg.inf.elte.hu/~tony/Informatikai-Konyvtar/03-Algorithms%20of%20Informatics%201,%202,%203/Distributedf29May.pdf

# julia> leaderElection([88,11,66,22,99,55,33,77,44])
# [99,99,99,99,99,99,99,99,99]
function leaderElection(ids :: Vector{Int})
  n = length(ids)
  channels = [Channel{Tuple{Symbol,Int,Int,Int,Symbol}}(n) for i=1:n]
  leader = Vector{Int}(n)
  @sync for i=1:n
    CCW = channels[i == 1 ? n : i - 1]
    CW = channels[i == n ? 1 : i + 1]
    @async leader[i] = process(ids[i], CCW, channels[i], CW)
  end
  return leader
end

# each process returns the highest id of all processes
function process(id, CCW, inbox, CW)
  replied = Dict(:CW => false, :CCW => false)
  box = Dict(:CW => CW, :CCW => CCW)
  inv = Dict(:CW => :CCW, :CCW => :CW)
  put!(CW, (:probe, id, 0, 0, :CCW))
  put!(CCW, (:probe, id, 0, 0, :CW))
  leader = nothing
  while leader == nothing
    (tag, ids, phase, ttl, from) = take!(inbox)
    if tag == :probe
      if id == ids
        put!(CCW, (:terminate, id, phase, 0, :CW))
        leader = id
      elseif ids > id && ttl > 0
        put!(box[inv[from]], (:probe, ids, phase, ttl-1, from))
      elseif ids > id && ttl == 0
        put!(box[from], (:reply, ids, phase, 0, inv[from]))
      end
    elseif tag == :reply
      if id != ids
        put!(box[inv[from]], (:reply, ids, phase, 0, from))
      else
        replied[from] = true
        if replied[:CW] && replied[:CCW]
          replied[:CW] = replied[:CCW] = false
          phase += 1
          ttl = 2 ^ phase - 1
          put!(CW, (:probe, id, phase, ttl, :CCW))
          put!(CCW, (:probe, id, phase, ttl, :CW))
        end
      end
    elseif tag == :terminate
      put!(CCW, (:terminate, ids, 0, 0, :CW))
      leader = ids
    end
  end
  return leader
end
