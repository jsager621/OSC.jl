
"""
    matchOSC(address, patter)

Check whether the `address` matches the provided `pattern` as per the
OSC path specification.

# Examples

```julia-repl

julia> matchOSC("/test", "/test")
true

julia> matchOSC("/test", "/*")
true

julia> matchOSC("/some/long/addr", "//addr")
true

julia> matchOSC("/dont/match/me", "/*/match")
false

julia> matchOSC("/do/match/me", "/*/match/me")
true

julia> matchOSC("/do/match/me/5", "/*/match/me/[0-9]")
true

matchOSC("/wild/card", "/{card,wild}/{card,wild}")
true
```
"""
function matchOSC(address::String, pattern::String)::Bool
    if address == pattern
        return true
    end

    if startswith(pattern, "//")
        return match_ss(address, pattern)
    end

    return match_basic(address, pattern)
end

function match_basic(address::String, pattern::String)::Bool
    # can go element by element and ignore the first one (always empty)
    p_elems = split(pattern, "/")[2:end]
    a_elems = split(address, "/")[2:end]

    if length(p_elems) != length(a_elems)
        return false
    end

    for i in eachindex(p_elems)
        p = p_elems[i]
        a = a_elems[i]

        if isnothing(match(to_regex(String(p)), a))
            return false
        end
    end

    return true
end

function match_ss(address::String, pattern::String)::Bool
    """
    //foo - anything with "foo" in any branch

    i.e.: find a match for foo at the end of any address
    """

    # determine element length of the pattern
    n_elems = count("/", pattern) - 1

    # find all the address separators
    indices = findall("/", address)

    if length(indices) < n_elems
        return false
    end

    # match the n_elems elements of the address
    addr = address[indices[end-n_elems+1][1]:end]
    return match_basic(addr, pattern[2:end])
end

function to_regex(pattern::String)::Regex
    """
    ? - any single character
    * - any sequence of 0 or more characters
    [string] - any character in the string
        - '-': range (i.e. [a-Z]) in ASCII order
        - '!': negate the bracket list, i.e. match anything NOT in there
    {foo, bar} - any of the listed strings

    anything else: only matches that character
    """
    r_string = pattern
    r_string = replace(r_string, ("?" => "."))
    r_string = replace(r_string, ("!" => "^"))
    r_string = replace(r_string, ("{" => ""))
    r_string = replace(r_string, ("}" => ""))
    r_string = replace(r_string, ("," => "|"))
    r_string = replace(r_string, ("*" => ".*"))

    return Regex(r_string)
end