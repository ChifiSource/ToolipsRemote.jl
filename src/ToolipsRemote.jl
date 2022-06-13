"""
Created in June, 2022 by
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
by team
[toolips](https://github.com/orgs/ChifiSource/teams/toolips)
This software is MIT-licensed.
### ToolipsRemote
**Extension for:**
- [Toolips](https://github.com/ChifiSource/Toolips.jl) \
This module provides the server extension RemoteExtension, an extension
that allows one to remotely call server commands from another Julia terminal.
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
    remote::Function
    function RemoteExtension(remote::Function; password::String = "", validate::Bool = true)
        if password == ""
            password = make_key()
        end
        valkey = ""
        f(r::Dict, e::Dict) = begin
            if has_extension(c, Logger)
                e[Logger].log(2, "Remote Key: $password")
            end

            r["/remote/connect"] = serve_remote
            e[Logger].log(1, "ToolipsRemote is active !")
        end
        new([:routing, :connection], "", f, password, validate, valkey, "", remote)
    end
end

"""

"""
function serve_remote(c::Connection)
    # Get the re
    re = e[RemoteExtension]
    # Check to see if key i provided
    args = getargs(c)
    if :key in keys(args)
        if args[:key] == re.password
            if re.validate
                valkey = make_key()
                c.valkey = valkey
                c[Logger].log(2, "key: $valkey")
                write!(c, """messsage : key""")
                 validate(c::Connection) = begin
                     args = getargs(c)
                     if :key in keys(args)
                         if args[:key] == re.valkey
                             url = "remote/connect/$valkey"
                             write!(c, Dict(url => "$url"))
                             c[url] = re.remote
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
                c[Logger].log(2, "$valkey Remote session created from $ipadd")
                c["/$url"] = session
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
    input = getarg(c, :in)
    exp = Meta.parse(input)
    ret = eval(exp)
    write!(c, string(ret))
    #==
    No, this is not done.. What I plan to do is basically make a macro evaluator
    It will be loaded into a dictionary, where basically we can decide what to do
    with incoming text, and of course just simply added to the connection via our
    extension! Pretty cool, right?
    ==#
end

"""

"""
function connect(url::String, key::String)
    errors = Dict(1 => "No key provided!",
    2 => "Key is incorrect!")
    connecturl = url * "remote/connect?key=$key"
    response = Toolips.get(connecturl)
    response = parse(Dict, response)
    if :error in keys(response)
        errorn = response[:error]
        errorm = errors[errorn]
        show("Encountered RemoteError: $errorn: $errorm")
    elseif :message in keys(response)
        if response[:message] == "connected"
            show("Connected!")
            show("URL recieved!")
            show(response[:url])
            connecturl = string(response[:url])
            connected_repl(url, connecturl)
        elseif response[:message] == "key"
            show("Please enter the verification password logged to your server.")
        end
    else
        throw("Could not get valid return from this request.")
    end
end

function connected_repl(name::AbstractString, url::AbstractString)
    send_up(s::String) = begin
        ur = name * url * "?in=$s"
        r = get(ur)
    end
    initrepl(send_up,
                    prompt_text="toolips@$name> ",
                    prompt_color = :cyan,
                    start_key='-',
                    mode_name="toolips")
end

export RemoteExtension, connect
end # module
