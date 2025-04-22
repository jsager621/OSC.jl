
function Sockets.send(
    sock::Sockets.UDPSocket, 
    ip::IPAddr, 
    port::Integer, 
    msg::Union{OSCMessage, OSCBundle})
    send(sock, ip, port, encodeOSC(msg))
end

abstract type OSCClient end

"""
Client for sending OSC messages via UDP.
Creates its own UDP socket.
On send, it enforces that the packet does not excceed the `max_payload`.
"""
struct OSCClientUDP <: OSCClient
    socket::UDPSocket
    max_payload::Integer
    OSCClientUDP(max_payload::Integer) = new(UDPSocket(), max_payload)
end

function Sockets.send(
    client::OSCClientUDP,
    ip::IPAddr,
    port::Integer,
    msg::Vector{UInt8}
)
    if length(msg) > client.max_payload
        throw(ArgumentError("Client can not send message larger than max_payload."))
    end

    send(client.socket, ip, port, msg)
end

function Sockets.send(
    client::OSCClientUDP,
    ip::IPAddr,
    port::Integer,
    msg::Union{OSCMessage, OSCBundle}
)
    send(client, ip, port, encodeOSC(msg))
end