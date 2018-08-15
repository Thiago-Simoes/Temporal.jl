if VERSION >= v"0.7-"
    using Printf  # needed for @sprintf macro
end

# const SHOWROWS = 5  # number of rows to print at beginning and end
const DECIMALS = 4  # the maximum number of decimals to show
const PADDING = 2  # number of spaces minimum between fields
const SHOWINT = false  # whether to format integer columns without decimals

str_width(s::AbstractString) = length(s)
str_width(s::Symbol) = length(string(s))
str_width(n::Number) = length(string(n))
str_width(f::Function) = length(string(f))
str_width(b::Bool) = b ? 4 : 5
str_width(c::Char) = 1
str_width(::Missing) = 7

_round(x, n=4) = ismissing(x) ? missing : round(x, digits=n)

function print_summary(io::IO, x::TS{V,T}) where {V,T}
    if isempty(x)
        println(@sprintf("Empty %s", typeof(x)))
        return 0
    else
        println(@sprintf("%ix%i %s: %s to %s", size(x,1), size(x,2), typeof(x), x.index[1], x.index[end]))
        return 1
    end
end

function getshowrows(io::IO, x::TS{V,T}) where {V,T}
    nrow = size(x,1)
    dims = displaysize(io)
    if nrow > dims[1]
        row_chunk_size = fld(dims[1]-4, 2) - 1
        return (collect(1:row_chunk_size), collect(nrow-row_chunk_size:nrow))
    else
        return (collect(1:fld(nrow,2)), collect(fld(nrow,2)+1:nrow))
    end
end

function getwidths(io::IO, x::TS{V,T}) where {V,T}
    widths = [T==Date ? 10 : 19; str_width.(x.fields)]
    toprows, botrows = getshowrows(io, x)
    vals = [x.values[toprows,:]; x.values[botrows,:]]
    if V <: Bool
        widths[2:end] .= 5
    elseif V <: Number
        @inbounds for j in 1:size(x,2)
            widths[j+1] = max(widths[j+1], maximum(str_width.(_round.(vals[:,j], DECIMALS))))
        end
    else
        @inbounds for j in 1:size(x,2)
            widths[j+1] = max(widths[j+1], maximum(str_width.(vals[:,j])))
        end
    end
    return widths
end

hasnegs(v::Vector) = eltype(v)<:Number ? any(v.<zero(eltype(v))) : false

function getnegs(io::IO, x::TS)
    toprows, botrows = getshowrows(io, x)
    idx = [toprows; botrows]
    return [hasnegs(x.values[:,j]) for j in 1:size(x,2)]
end

print_header(x::TS, widths::Vector{Int}, negs::Vector{Bool}) = prod(rpad.(["Index"; lpad.(string.(x.fields), str_width.(x.fields).+negs)], widths))

pos_or_missing(x) = [(ismissing(x) || x >= 0.0) for x in x]

function print_row(x::TS{V,T}, row::Int, widths::Vector{Int}, negs::Vector{Bool}) where {V,T}
    if V <: Bool
        return prod(rpad.([string(x.index[row]); [" "].^(negs .* pos_or_missing(x.values[row,:])) .* string.(x.values[row,:])], widths))
    elseif V <: Number
        return prod(rpad.([string(x.index[row]); [" "].^(negs .* pos_or_missing(x.values[row,:])) .* string.(_round.(x.values[row,:], DECIMALS))], widths))
    else
        return prod(rpad.([string(x.index[row]); string.(x.values[row,:])], widths))
    end
end

function print_rows(io::IO, x::TS, widths::Vector{Int}=getwidths(io,x).+PADDING, negs::Vector{Bool}=getnegs(io,x))
    # negs = getnegs(io,x)
    # widths = getwidths(io,x) .+ PADDING
    nrow = size(x,1)
    ncol = size(x,2)
    toprows, botrows = getshowrows(io,x)
    if nrow > 1
        @inbounds for row in toprows
            println(io, print_row(x, row, widths, negs))
        end
        if toprows[end] < botrows[1] - 1
            println(io, "⋮")
        end
    end
    @inbounds for row in botrows[1:end-1]
        println(io, print_row(x, row, widths, negs))
    end
    print(io, print_row(x, botrows[end], widths, negs))
    nothing
end

function show(io::IO, x::TS{V,T}) where {V,T}
    if print_summary(io, x) == 0
        return nothing
    end
    # println()  # print whitespace before actualy data starts to improve readability
    widths = getwidths(io, x) .+ PADDING
    negs = getnegs(io, x)
    println(io, print_header(x, widths, negs))
    print_rows(io, x, widths, negs)
    nothing
end
