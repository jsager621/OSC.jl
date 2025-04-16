# "#bundle"
const BUNDLE_VEC = UInt8[0x23, 0x62, 0x75, 0x6e, 0x64, 0x6c, 0x65, 0x00]
const BUNDLE_ID = unsafe_load(Ptr{UInt64}(Base.pointer(BUNDLE_VEC)), 1)

#-------------------------------------------
# Helper Functions
#-------------------------------------------
# set x to the next 32 bit aligned starting index
# i.e. x = 3 => align_32(x) = 5
align_32(x) = 4 - (x - 1) % 4 + x

# put UInt32 into big endian byte array
function encode_uint32!(data::Vector{UInt8}, idx::Int64, val::Union{UInt32, Int32, Float32})::Nothing
    ptr = pointer(reinterpret(UInt8, [val]))
    @inbounds data[idx+3] = unsafe_load(ptr)
    @inbounds data[idx+2] = unsafe_load(ptr+1)
    @inbounds data[idx+1] = unsafe_load(ptr+2)
    @inbounds data[idx] = unsafe_load(ptr+3)
    return nothing
end

# read uint32 from big endian vector
function decode_uint32(data::Vector{UInt8})::UInt32
    return (UInt32(data[4]) << 0) | (UInt32(data[3]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[1]) << 24)
end

# put UInt64 into big endian byte array
function encode_uint64!(data::Vector{UInt8}, idx::Int64, val::Union{UInt64, Float64, Int64})::Nothing
    ptr = pointer(reinterpret(UInt8, [val]))
    @inbounds data[idx+7] = unsafe_load(ptr)
    @inbounds data[idx+6] = unsafe_load(ptr+1)
    @inbounds data[idx+5] = unsafe_load(ptr+2)
    @inbounds data[idx+4] = unsafe_load(ptr+3)
    @inbounds data[idx+3] = unsafe_load(ptr+4)
    @inbounds data[idx+2] = unsafe_load(ptr+5)
    @inbounds data[idx+1] = unsafe_load(ptr+6)
    @inbounds data[idx] = unsafe_load(ptr+7)
    return nothing
end

# read uint64 from big endian vector
function decode_uint64(data::Vector{UInt8})::UInt64
    return ((UInt64(data[8]) << 0) | (UInt64(data[7]) << 8) | (UInt64(data[6]) << 16) | (UInt64(data[5]) << 24) |
            (UInt64(data[4]) << 32) | (UInt64(data[3]) << 40) | (UInt64(data[2]) << 48) | (UInt64(data[1]) << 56))
end

# extend data buffer
function extend_buffer!(data::Vector{UInt8})::Nothing
    new_buf = zeros(UInt8, 2 * length(data))
    new_buf[1:length(data)] = data
    data = new_buf
    return nothing
end