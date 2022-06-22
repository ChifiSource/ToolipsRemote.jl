"""
Created in June, 2022 by
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
by team
[toolips](https://github.com/orgs/ChifiSource/teams/toolips)
This software is MIT-licensed.
### ToolipsRemote
**Extension for:**
- [Toolips](https://github.com/ChifiSource/Toolips.jl) \
This module provides the server extension Remote, an extension
that allows one to remotely call server commands from another Julia terminal.
You can connect to a served Remote extension using the connect method.
##### Module Composition
- [**ToolipsRemote**](https://github.com/ChifiSource/ToolipsRemote.jl)
"""
module ToolipsRemote

using Toolips
using Random
using ParseNotEval
using ReplMaker
using Markdown
import Toolips: ServerExtension

"""
### Hash
- f::Function \
Creates an anonymous hashing function for a string of length(n). Can be
    indexed with nothing to retrieve Hash.
##### example
```
# 64-character hash
h = Hash(64)          #    vv getindex(::Hash)
buffer = Base.SecretBuffer(hash[])
if String(buffer.data) == "Password"
```
------------------
##### field info
- f::Function - The f function is used to return the Hash's value.
------------------
##### constructors
- Hash(n::Integer = 32)
- Hash(s::String)
"""
struct Hash
    f::Function
    function Hash(n::Integer = 32)
        seed = rand(1:100000000)
        f() = begin
            Random.seed!(seed); randstring(n)
        end
        new(f)
    end
    function Hash(s::String)
        seed = rand(1:100000000)
        replacechars = randstring(32)
        d = Dict([char => ])
        f() = begin

        end
        f(s::String) = begin

        end
    end
end

"""
**Session**
### getindex(h::Hash) -> ::String
------------------
Retrieves the value of the hashed data.
#### example
```
pwd = h[]
```
"""
getindex(h::Hash) = h.f()

"""
### Remote <: Toolips.ServerExtension
- type::Vector{Symbol}
- remotefunction::Function
- f::Function
- logins::Dict{String, Hash}
- users::Dict
- motd::String \
The remote extension makes it possible to connect to your server from
another Julia REPL.
##### example
```

```
------------------
##### field info

------------------
##### constructors

"""
mutable struct Remote <: ServerExtension
    type::Vector{Symbol}
    remotefunction::Function
    f::Function
    logins::Dict{String, Hash}
    users::Dict
    motd::String
    function Remote(remotefunction::Function = evaluator,
        usernames::Vector{String} = ["root"];
        motd::String = """### login to toolips remote session"""
        )
        logins::Dict{String, Hash} = Dict([n => Hash() for n in usernames])
        users::Dict = Dict()
        f(r::Dict, e::Dict) = begin
            r["/remote/connect"] = serve_remote
            if has_extension(e, Logger)
                e[:Logger].log(1, "ToolipsRemote is active !")
                for user in logins
                    login = user[1]
                    pwrd = user[2].f()
                    e[:Logger].log(2, "|Remote Key for $login: $pwrd")
                end
            end
        end
        new([:routing, :connection], remotefunction, f, logins, users,
            motd)::Remote
    end
end
getindex(r::Remote, s::String) = r.users
"""

"""
function serve_remote(c::Connection)
    message = getpost(c)
    keybeg = findall(":SESSIONKEY:", message)
    if length(keybeg) == 1
            keystart = keybeg[1][2] + 11
            key = message[keystart:length(message)]
            # cut out the session key if provided.
            message = message[1:keybeg[1][1] - 1]
            print(message)
        if key in [v.f() for v in keys(c[:Remote].users)]
            c[:Remote].remotefunction(c, message)
        else
            write!(c, "Key invalid.")
        end
    else
        if message == "login"
            write!(c, c[:Remote].motd)
        elseif contains(message, ":")
            usrpwd = split(message, ":")
            if string(usrpwd[1]) in keys(c[:Remote].logins)
                if string(usrpwd[2]) == c[:Remote].logins[string(usrpwd[1])].f()
                    newhash = Hash()
                    c[:Remote].users[newhash] = string(usrpwd[1])
                    name = string(usrpwd[1])
                    key = newhash.f()
                    write!(c, "$name:$key")
                else
                    write!(c, "Your password was not found.")
                end
            else
                write!(c, "Your username was not found.")
            end
        else
            write!(c, "Not a valid request.")
        end
    end
end

"""

"""
function connect(url::String)
    message = post("$url/remote/connect", "login")
    display(Markdown.parse(message))
    print("user: "); u = readline()
    pwd = Base.getpass("password for $u")
    namekey = post("$url/remote/connect", "$u:$(string(pwd.data))")
    Base.shred!(pwd)
    if contains(namekey, ":")
        display(md"#### connection successful!")
        namekey = split(namekey, ":")
        name, key = string(namekey[1]), string(namekey[2])
        connected_repl(name, url, key)
    else
        display(md"$namekey")
    end
end

function connected_repl(name::AbstractString, url::String, key::String)
    send_up(s::String) = begin
        r = post("$url/remote/connect", s * ":SESSIONKEY:$key")
        display(Markdown.parse(r))
    end
    initrepl(send_up,
                    prompt_text="🔗 $name> ",
                    prompt_color = :cyan,
                    start_key='[',
                    mode_name="remote")
end

"""
"""
function evaluator(c::Connection, m::String)
    write!(c, string(eval(Meta.parse(m))))
end

function controller(c::Connection, m::String,
                commands::Dict{String, Function} = Dict("?" => helpme,
                "log" => log))
    args = [string(arg) for arg in split(m, " ")]
    cmd = args[1]
    write!(c, commands[cmd](args))
end

function helpme(args::Vector{String})
    if length(args) > 2
        return("""### Not a correct number of arguments!
        Try ? for more information.
        """)
    elseif length(args) == 1
        return("""### ?
        The ? command allows one to explore the various capabilities
        of the toolips session. Inside of this REPL, commands are issued with
        their arguments followed by spaces. The ? application, as an example
        takes one argument. The one argument is the
        ```

        ```
        ##### Command
        - **Command** **arg1::Type (Required)** arg2::Type arg3::Type
        - **?** command::String
        - **log** **message::String** level::Int64
        - More commands coming soon.
        """)
    else
        input = args[2]
    end
end

function log(c::Connection, args::AbstractString ...)
    if length(args) > 2
        write!(c, "### Not a correct number of arguments!\n")
        write!(c, "You can send ? log to find out more information.")
        return
    end
    if length(args) == 2
        level = parse(Int64, string(args[2]))
        c[:Logger].log(level, string(args[1]))
    else
        c[:logger].log(string(args[1]))
    end
end

function reroute(c::Connection, args::AbstractString ...)

end

export Remote, connect
end # module
