# Encoding and Parsing

# Encoding

`OSCMessage`s can be created as julia structs.

```julia
using OSC

msg = OSCMessage("/my/address", "ifs", UInt32(15), Float32(3.45), "string")
```

`OSCBundle`s consist of a `timetag` and a numer of `OSCBundleElement`s where a `OSCBundleElement` can either contain an `OSCMessage` or another `OSCBundle`.

```julia
using OSC

msg = OSCMessage("/my/address", "ifs", UInt32(15), Float32(3.45), "string")

bundle_element = OSCBundleElement(msg)
bundle = OSCBundle(UInt64(123456), [bundle_element, bundle_element])
```

Both `OSCBundle` and `OSCMessage` can be encoded to their `Vector{UInt8}` representation via the `encodeOSC` function.

```julia
using OSC

msg = OSCMessage("/my/address", "ifs", UInt32(15), Float32(3.45), "string")
bundle_element = OSCBundleElement(msg)
bundle = OSCBundle(UInt64(123456), [bundle_element, bundle_element])

encodeOSC(msg)
encodeOSC(bundle)
```

# Parsing

Any incoming message buffer of the correct format can be parsed to an `OSCMessage` or `OSCBundle` struct via the `parseOSC` function.

```julia
using OSC

msg = OSCMessage("/my/address", "ifs", UInt32(15), Float32(3.45), "string")
bundle_element = OSCBundleElement(msg)
bundle = OSCBundle(UInt64(123456), [bundle_element, bundle_element])

e_msg = encodeOSC(msg)
e_bundle = encodeOSC(bundle)

parseOSC(e_msg)
parseOSC(e_bundle)
```