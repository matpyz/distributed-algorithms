# Copyright (c) 2018 Mateusz K. Pyzik, all rights reserved.
# Lamport's Bakery algorithm
threads = 5
entering = [false for i=1:threads]
number = [0 for i=1:threads]
channels = [Channel{Any}(1) for i=1:threads]
conditions = [Condition() for i=1:threads]

macro atomic(expr)
  :(begin
    put!(channels[$(esc(:id))], $(string(expr)))
    wait(conditions[$(esc(:id))])
    $(esc(expr))
  end)
end

function prologue(id :: Int)
  @atomic entering[id] = true
  @atomic number[id] = 1 + maximum(number)
  @atomic entering[id] = false
  for thread = 1:threads
    if @atomic thread != id
      while @atomic entering[thread]
      end
      while (@atomic(number[thread] != 0) && (
            @atomic(number[thread] < number[id]) ||
              @atomic(number[thread] == number[id]) &&
              @atomic(thread < id)
          ))
      end
    end
  end
end

function epilogue(id :: Int)
  @atomic number[id] = 0
end

function criticalSection(id :: Int)
  @atomic println("Critical section at process #$(id)")
end

function thread(id :: Int)
  for iteration = 1:5
    prologue(id)
    criticalSection(id)
    epilogue(id)
  end
  put!(channels[id], nothing)
end

begin
  tasks = [@async thread(i) for i = 1:threads]
  state = Dict{Int,String}((i => take!(channels[i])) for i = 1:threads)
  while !isempty(state)
    chosen = rand(collect(keys(state)))
    println("$(chosen): $(state[chosen])")
    notify(conditions[chosen])
    result = take!(channels[chosen])
    if result == nothing
      delete!(state, chosen)
    else
      state[chosen] = result
    end
  end
end
