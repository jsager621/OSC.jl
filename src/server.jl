using Sockets

abstract type OSCServer end

"""
OSC Server for handling OSC packages coming in via UDP.
Dispatches messages to callback functions defined by `match_callbacks`.
"""
struct OSCServerUDP <: OSCServer
    host::IPAddr
    port::Integer
    socket::UDPSocket
    match_callbacks::Dict{String, Function}
    match_func::Function
    inverse::Bool

    function OSCServerUDP(host::IPAddr, port::Integer, match_callbacks::Dict{String, Function}; invert_matching=false)
        sock = UDPSocket()
        bind(sock, host, port)

        if invert_matching
            match_func = (x,y) -> matchOSC(y, x)
        else
            match_func = (x,y) -> matchOSC(x, y)
        end

        return new(host, port, sock, match_callbacks, match_func, invert_matching)
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

function dispatch(srv::OSCServerUDP, data::Vector{UInt8})
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
end

function dispatch_message(srv::OSCServer, msg::OSCMessage)
    for k in keys(srv.match_callbacks)
        if srv.match_func(k, address(msg))
            srv.match_callbacks[k](srv, arguments(msg))
        end
    end
end

function dispatch_message(srv::OSCServer, msg::OSCBundle)
    for e in msg.elements
        dispatch_message(srv, e.content)
    end
end


# TODO TCP Server