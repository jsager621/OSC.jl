"""
    validateOSC(msg, data)
    validateOSC(bundle, data)

Check whether the given `msg` or `bundle` matches the OSC output `data`.
"""
function validateOSC(msg::OSCMessage, data::Vector{UInt8})::Bool
    try
        new_msg = parseOSC(data)

        if new_msg == msg
            return true
        end
    
        println("Validation for message failed. Outputs:\n$msg\n$new_msg")
        return false
    catch err 
        if isa(err, OSCParseException)
            println("Validation for message: $msg failed with parse exception.")
            rethrow(err)
        end
        
        println("Validation failed with unexpected exception.")
        rethrow(err)
    end
end

function validateOSC(bundle::OSCBundle, data::Vector{UInt8})::Bool
    try
        new_bundle = parseOSC(data)

        if new_bundle == bundle
            return true
        end
    
        println("Validation for bundle failed. Outputs:\n$bundle\n$new_bundle")
        return false
    catch err 
        if isa(err, OSCParseException)
            println("Validation for bundle: $bundle failed with parse exception.")
            rethrow(err)
        end
        
        println("Validation failed with unexpected exception.")
        rethrow(err)
    end
end