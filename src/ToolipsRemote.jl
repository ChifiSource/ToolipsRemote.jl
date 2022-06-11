"""
Created in December, 2021 by
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
by team
[toolips](https://github.com/orgs/ChifiSource/teams/toolips)
This software is MIT-licensed.
### ToolipsRemote
**Extension for:**
- [Toolips](https://github.com/ChifiSource/Toolips.jl) \
This module provides the server extension RemoteExtension, as well as an
API to interact with it.
##### Module Composition
- [**ToolipsRemote**](https://github.com/ChifiSource/ToolipsRemote.jl)
"""
module ToolipsRemote

using Toolips
using Random
using ParseNotEval
using ReplMaker
import Toolips: ServerExtension
"""

"""
function make_key()
    Random.seed!( rand(1:100000) )
    randstring(32)
end

"""

"""
mutable struct RemoteExtension <: ServerExtension
    type::Vector{Symbol}
    session_id::String
    f::Function
    password::String
    validate::Bool
    valkey::String
    ip::String
    function RemoteExtension(; password::String = "", validate::Bool = true)
        if password == ""
            password = make_key()
        end
        valkey = ""
        f(r::Dict, e::Dict) = begin
            if :logger in keys(e)
                e[:logger].log(2, "Remote Key: $password")
            end

            r["/remote/connect"] = serve_remote
            e[:logger].log(1, "ToolipsRemote is active !")
        end
        new([:routing, :connection], "", f, password, validate, valkey, "")
    end
end

"""

"""
function serve_remote(c::Connection)
    # Get the re
    re = nothing
    for e in c.extensions
        if typeof(e[2]) == RemoteExtension
            re = e[2]
        end
    end
    # Check to see if key i provided
    args = getargs(c)
    if :key in keys(args)
        if args[:key] == re.password
            if re.validate
                valkey = make_key()
                c.valkey = valkey
                c[:logger].log(2, "key: $valkey")
                write!(c, """messsage : key""")
                 validate(c::Connection) = begin
                     args = getargs(c)
                     if :key in keys(args)
                         if args[:key] == re.valkey
                             url = "remote/connect/$valkey"
                             write!(c, Dict(url => "$url"))
                             c[url] = session
                         end
                     end
                end
                c["/remote/connect/validate"] = validate
            else
                valkey = make_key()
                url = "remote/connect/$valkey"
                write!(c, "message : connected, url : $url")
                ipadd = getip(c)
                re.ip = ipadd
                c[:logger].log(2, "$valkey Remote session created from $ipadd")
                c[url] = session
            end
        else
            write!(c, "error : 2")
        end
    else
        write!(c, "error : 1")
    end
end

"""
"""
function session(c::Connection)
    write!(c, "Hello world!")
    write!(c, getip(c))
end

"""

"""
function connect(url::String, key::String)
    errors = Dict(1 => "No key provided!",
    2 => "Key is incorrect!")
    connecturl = url * "remote/connect?key=$key"
    response = Toolips.get(connecturl)
    parse(Dict, response)
    if :message in keys(response)
        errorn = response["error"]
        errorm = errors[errorn]
        show("Encountered RemoteError: $errorn: $errorm")
    elseif :message in keys(response)
        if response[:message] == "connected"
            show("Connected!")
            show("URL recieved!")
            show(response[:url])
            connecturl = response[:url]
            connected_repl(url, connecturl)
        elseif response[:message] == "key"
            show("Please enter the verification password logged to your server.")
        end
    else
        throw("Could not get valid return from this request.")
    end
end

function connected_repl(name::String, url::String)
    send_up(s::String) = begin
        r = get("$url/?in=$s")
    end
    initrepl(send_up,
                    prompt_text="toolips@$name> ",
                    prompt_color = :lightblue,
                    start_key='-',
                    mode_name="toolips")
end

export RemoteExtension, connect
end # module
