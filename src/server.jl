abstract type OSCServer end

"""
OSC Server for handling OSC packages coming in via UDP.
Dispatches messages to callback functions defined by `match_callbacks`.

Additional flags:
- `invert_matching` - allow OSC address patterns in match_callbacks and receive addresses from client.
  This allows a callback like `"/addr/*" -> callback()` to be invoked by incoming messages with address
  `/addr/abc123` etc.
- `timed_callbacks` - if `true`, read the timestamps of incoming bundles and execute their contents at the
  provided time. Timestamps in the past are executed immediately.
"""
struct OSCServerUDP <: OSCServer
    host::IPAddr
    port::Integer
    socket::UDPSocket
    match_callbacks::Dict{String, Function}
    match_func::Function
    inverse::Bool
    timed_callbacks::Bool

    function OSCServerUDP(host::IPAddr, port::Integer, match_callbacks::Dict{String, Function}; 
                          invert_matching::Bool=false, timed_callbacks::Bool=false)
        sock = UDPSocket()
        bind(sock, host, port)

        if invert_matching
            match_func = (x,y) -> matchOSC(y, x)
        else
            match_func = (x,y) -> matchOSC(x, y)
        end

        return new(host, port, sock, match_callbacks, match_func, invert_matching, timed_callbacks)
    end
end

function Base.close(srv::OSCServerUDP)
    return close(srv.socket)
end

"""
    listenForever(srv)

Continuously try to read data from the `srv.socket`.
When a packet is read it is parsed to an `OSCMessage` or `OSCBundle`
and the message contents are dispatched via the `match_callbacks` dictionary.
"""
function listenForever(srv::OSCServerUDP)::Nothing
    try
        while true
            data = recv(srv.socket)
            Threads.@spawn dispatch(srv, data)
        end
    catch e
        if !isa(e, EOFError)
            @error "OSC UDP server encountered an unexpected error:" exception=(e, catch_backtrace())
        end
    finally
        @info "Closing OSC UDP server."
        close(srv.socket)
    end
end

function dispatch(srv::OSCServerUDP, data::Vector{UInt8})::Nothing
    try
        dispatch_message(srv, parseOSC(data))
    catch e
        if e isa OSCParseException
            @warn "Could not parse package to OSC, ignoring."
            showerror(stdout, e, catch_backtrace())
        else
            showerror(stdout, e, catch_backtrace())
            rethrow(e)
        end
    end

    return nothing
end

function dispatch_message(srv::OSCServer, msg::OSCMessage)::Nothing
    for k in keys(srv.match_callbacks)
        if srv.match_func(k, address(msg))
            srv.match_callbacks[k](srv, arguments(msg))
        end
    end

    return nothing
end

function dispatch_message(srv::OSCServer, bundle::OSCBundle)::Nothing
    # check timetag for timed execution
    if srv.timed_callbacks
        for e in bundle.elements
            Threads.@spawn dispatch_at_date(srv, toDate(bundle.timetag), e)
        end
    else
        for e in bundle.elements
            Threads.@spawn dispatch_message(srv, e.content)
        end
    end 

    return nothing
end

function dispatch_at_date(srv::OSCServer, date::DateTime, e::BundleElement)::Nothing
    t = now()
    if date > t
        sleep(date - t)
    end

    dispatch_message(srv, e.content)
end

# TODO TCP Server