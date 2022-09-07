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
using ParseNotEval
using ReplMaker
using Random
using Markdown
using SHA
import Toolips: ServerExtension, AbstractRoute, AbstractConnection
import Toolips: write!

"""
### Remote <: Toolips.ServerExtension
- type::Vector{Symbol}
- remotefunction::Dict{Int64, Function}
- f::Function
- logins::Dict{String, Hash}
- users::Dict{Vector{UInt8}, String}
- access::Dict{String, Int64}
- motd::String - A message to be shown at the login screen.
The remote extension makes it possible to connect to your server from
another Julia REPL. Can be provided with an alternative remote function as the
first positional argument, as well as a new serving function as the second
positional argument. A remote function should take a Connection and a String.
A serving function should take only a Connection. `remotefunction` is a `Dict`
    which will take levels as keys and functions as values. We then set such keys
    in the `usernames` Vector. This Vector is a Vector{Pair{String, Pair{String, Int64}}}.
    See the constructors below for an example. The functions provided to `remotefunction`
    should take a `RemoteConnection` or `Toolips.AbstractConnection`
##### example
```
r = Remote()
st = ServerTemplate(extensions = [Remote()])
```
------------------
##### constructors
Remote(remotefunction::Function = Dict{Int64, Function}(1 => controller()),
usernames::Vector{Pair{String, Pair{String, Int64}}} = ["root" => "1234" => 1];
        motd::String, serving_f::Function)
"""
mutable struct Remote <: ServerExtension
    type::Vector{Symbol}
    remotefunction::Dict{Int64, Function}
    f::Function
    logins::Dict{String, Vector{UInt8}}
    users::Dict{Vector{UInt8}, String}
    access::Dict{String, Int64}
    motd::String
    function Remote(
        remotefunction::Dict{Int64, Function} = Dict{Int64, Function}(1 => controller()),
        users::Vector{Pair{String, Pair{String, Int64}}} = ["root" => "1234" => 1];
        motd::String = """### login to toolips remote session""",
        serving_f::Function = serve_remote)
        logins::Dict{String, Vector{UInt8}} = Dict(
        [n[1] => sha256(n[2][1]) for n in users])
        access::Dict{String, Int64} = Dict([client[1] => client[2][2] for client in users])
        users = Dict{Vector{UInt8}, String}()
        f(r::Vector{AbstractRoute}, e::Vector{ServerExtension}) = begin
            r["/remote/connect"] = serving_f
        end
        new([:routing, :connection], remotefunction, f, logins, users,
         access, motd)::Remote
    end
end

"""
**Remote**
### set_pwd!(::Connection, ::Pair{String, String}) -> _
------------------
Changes the connected user's Remote password.
#### example
```
# this function will just set the password to whatever
 # the replica sends.
myremote(c::RemoteConnection) = begin
    set_pwd!(c, c.name => c.message)
end
```
"""
function set_pwd!(c::Connection, usrpwd::Pair{String, String})
    c[:Remote].logins[usrpwd[1]] = sha256(usrpwd[2])
end

"""
**Remote**
### serve_remote(c::Connection) -> _
------------------
Servers a remote login via the connect() method. This is the method that handles
remote logins, so if you would like to change the remote method itself, do not do
so by replacing this function, instead replace the first positional argument
    `remotefunction` on the `Remote` extension.
"""
function serve_remote(c::Connection)
    message = getpost(c)
    keybeg = findall(":SESSIONKEY:", message)
    if length(keybeg) == 1
            keystart = keybeg[1][2] + 11
            key = message[keystart:length(message)]
            # cut out the session key if provided.
            message = message[1:keybeg[1][1] - 1]
        if sha256(key) in keys(c[:Remote].users)
            uname::String = c[:Remote].users[sha256(key)]
            userinfo::Pair{String, Int64} = uname => c[:Remote].access[uname]
            newc = RemoteConnection(c, userinfo, message)
            c[:Remote].remotefunction[userinfo[2]](newc)
        else
            write!(c, "Key invalid.")
        end
    else
        if message == "login"
            write!(c, c[:Remote].motd)
        elseif contains(message, ":")
            usrpwd = split(message, ":")
            if string(usrpwd[1]) in keys(c[:Remote].logins)
                if sha256(usrpwd[2]) == c[:Remote].logins[string(usrpwd[1])]
                    key = randstring(16)
                    c[:Remote].users[sha256(key)] = usrpwd[1]
                    write!(c, "$(usrpwd[1]):$key")
                else
                    c[:Logger].log(string(usrpwd[2]))
                    c[:Logger].log(string(sha256(usrpwd[2])))
                    c[:Logger].log(string(c[:Remote].logins[string(usrpwd[1])]))
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
**Remote**
### connect(url::String) -> _
------------------
Connects to a toolips session extension at the given URL. Ensure http:// is
provided prior to the URL.
#### example
```
connect("http://127.0.0.1:8000")
```
"""
function connect(url::String)
    message = post("$url/remote/connect", "login")
    display(Markdown.parse(message))
    print("user: "); u = readline()
    pwd = Base.getpass("password for $u")
    data = pwd.data
    namekey = post("$url/remote/connect", "$u:$(string(data))")
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

#==
TODO Peer connect
==#
function peer_connect(url::String)

end

"""
### RemoteConnection
- routes::Vector{Toolips.AbstractRoute}
- http::Any
- extensions::Vector{Toolips.ServerExtension}
- group::Int64
- name::String
- message::String\n
The `RemoteConnection` is passed through the `remotefunction` of a Remote
extension. It contains the username, user group, and the regular Connection data
along with whatever input the client has given last.
##### example
```
uname::String = c[:Remote].users[sha256(key)]
userinfo::Pair{String, Int64} = uname => c[:Remote].access[uname]
newc = RemoteConnection(c, userinfo, message)
c[:Remote].remotefunction[userinfo[2]](newc)
```
------------------
##### constructors
- RemoteConnection(c::Connection, userdata::Pair{String, Int64},
    message::AbstractString = "")
"""
mutable struct RemoteConnection <: Toolips.AbstractConnection
    routes::Vector{Toolips.AbstractRoute}
    http::Any
    extensions::Vector{Toolips.ServerExtension}
    group::Int64
    name::String
    message::String
    function RemoteConnection(c::Connection, userdata::Pair{String, Int64},
        message::AbstractString = "")
        new(c.routes, c.http, c.extensions, userdata[2], userdata[1],
        string(message))::RemoteConnection
    end
end

macro R_str(s)
    s
end

function write!(c::RemoteConnection, s::Component{<:Any})
    write!(c, s[:text])
end

function write!(c::RemoteConnection, s::Component{:div})
    write!(c, "---" * R"\n")
    [write!(c, child) for child in s[:children]]
    write!(c, "---" * R"\n")
end



write!(c::RemoteConnection, s::Component{:h1}) = write!(c, "# $(s[:text])" * R"\n")
write!(c::RemoteConnection, s::Component{:h2}) = write!(c, "## $(s[:text]))" * R"\n")
write!(c::RemoteConnection, s::Component{:h3}) = write!(c, "### $(s[:text])" * R"\n")
write!(c::RemoteConnection, s::Component{:h4}) = write!(c, "#### $(s[:text])" * R"\n")
write!(c::RemoteConnection, s::Component{:b}) = write!(c, "**$(s[:text])**")
write!(c::RemoteConnection, s::Component{:a}) = write!(c, "[$(s[:text])]($(s[:href]))")


"""
**Remote**
### getindex(h::Hash) -> ::String
------------------
Creates the linked remote REPL.
#### example
```
connectedrepl("myrepl", "http://127.0.0.1:8000", key::String)
```
"""
function connected_repl(name::AbstractString, url::String, key::String)
    send_up(s::String) = begin
        r = post("$url/remote/connect", s * ":SESSIONKEY:$key")
        display(Markdown.parse(replace(r, R"\n" => "\n")))
    end
    initrepl(send_up,
                    prompt_text="🔗 $name> ",
                    prompt_color = :cyan,
                    start_key='[',
                    mode_name="remote")
end

"""
**Remote**
### getindex(h::Hash) -> ::String
------------------
Runs eval on any incoming connection strings.
#### example
```
connectedrepl("myrepl", "http://127.0.0.1:8000", key::String)
```
"""
function evaluator(c::RemoteConnection)
    write!(c, string(eval(Meta.parse(c.message))))
end

function controller(commands::Dict{String, Function} = Dict("?" => helpme,
                    "logit" => logit))
    f(c::RemoteConnection) = begin
        m = c.message
        args = [string(arg) for arg in split(m, ";")]
        cmd = args[1]
        if length(args) != 1
            args = args[2:length(args)]
        else
            args = Vector{String}()
        end
        write!(c, commands[cmd](args, c))
    end
    f
end

"""
helpme(args::Vector{String}) -> ::String
---------------------
This is one of the default controller() functions. All of these functions are
going to take args::Vector{String}. This will be the only function with this
sort of documentation, as the rest will contain arg usage.
"""
function helpme(args::Vector{String}, c::RemoteConnection)
    doc_lookup = Dict("logit" => """ ### logit !
    The logit function is used to log things to your server remotely. The first
        argument should be a message in the form of a string. The second is an
        optional level.
    ###
    ```
    logit;This message is logged
    logit;This message is logged, and written to a file;2
    ```
    """
    )
    if length(args) == 1
        return(doc_lookup[args[1]])
    else
        return("""### ?
        The ? command allows one to explore the various capabilities
        of the toolips session. Inside of this REPL, commands are issued with
        their arguments seperated by semi-colons. The ? application, as an
        example takes one argument. The one argument is the application you wish
        to call docs for.
        ```
        ?;logit
        ```
        ##### Command
        - **Command** **arg1::Type (Required)** arg2::Type arg3::Type
        - **?** command::String
        - **logit** **message::String** level::Int64
        - More commands coming soon.
        """)
    end
end


function logit(args::Vector{String}, c::RemoteConnection)
    if length(args) == 1
        c[:Logger].log(string(args[1]))
        return("Your message was written!")
    end
    if length(args) == 2
        level = parse(Int64, string(args[2]))
        c[:Logger].log(level, string(args[1]))
        return("Your message was written!")
    else
        return("### Not a correct number of arguments!")
    end
end

export Remote, connect, controller
end # module
