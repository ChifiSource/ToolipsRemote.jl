module ToolipsRemote
using Toolips
using Random

import Toolips: ServerExtension

function make_key()
    Random.seed!( rand(1:100000) )
    randstring(32)
end

mutable struct RemoteExtension <: ServerExtension
    type::Vector{Symbol}
    session_id::String
    f::Function
    password::String
    validate::Bool
    valkey::String
    function RemoteExtension(; password::String = "", validate::Bool = true)
        if password == ""
            password = make_key()
        end
        valkey = ""
        f(r::Dict, e::Dict) = begin
            if contains(keys(e), :logger)
                e[:logger].log(2, "Remote Key: $password")
            end

            r["/remote/connect"] = serve_remote
            e[:logger].log(1, "ToolipsRemote is active !")
        end
        new([:routing, :connection], "", f, password, validate, valkey)
    end
end

function serve_remote(c::Connection)
    # Get the re
    re = nothing
    for e in c.extensions
        if typeof(c[e]) == RemoteExtension
            re = c[e]
        end
    end
    # Check to see if key i provided
    args = getargs(c)
    if contains(args, :key)
        if args[:key] == re.password
            if re.validate
                valkey = make_key()
                c.valkey = valkey
                c[:logger].log(2, "key: $valkey")
                write!("""{"messsage" = "key"}""")
                 validate(c::Connection) = begin

                end
                c["/remote/connect/validate"] = validate
            else
                write!(c, """{"message" = "connected"}""")
            end
        else
            write!(c, """{"error" : 2}""")
        end
    else
        write!(c, """{"error" : 1}""")
    end
end

function connect(url::String, key::Integer)
    errors = Dict(1 => "No key provided!",
    2 => "Key is incorrect!")
    connecturl = url * "/remote/connect?key=$key"
    response = get(connecturl)
    if contains(keys(response), "error")
        errorn = response["error"]
        errorm = errors[errorn]
        show("Encountered RemoteError: $errorn: $errorm")
    elseif contains(keys(response), "message")
        if response["message"] == "connected"
            show("Connected!")
        elseif response["message"] == "key"
            show("You must enter a key.")
        end
    else
        throw("Could not get valid return from this request.")
    end
end

export RemoteExtension, connect
end # module
