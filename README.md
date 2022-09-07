<img src = "https://github.com/ChifiSource/image_dump/blob/main/toolips/toolipsremote.png"></img>

- [Documentation](doc.toolips.app/extensions/toolips_remote)
- [Toolips](https://github.com/ChifiSource/Toolips.jl)
- [Extension Gallery](https://toolips.app/?page=gallery&selected=remote)\
Toolips Remote allows you to connect to your server from the Julia REPL. Simply load the `Remote` extension into your server, and then use the `connect` function to connect to it. You will then be prompted to login!
#### quick start
First, inside of your toolips project's source file, add `Remote` to your `Vector{ServerExtension}`.
```julia
routes = [route("/", home), fourofour]
extensions = Vector{ServerExtension}([Logger(), Remote(Dict{Int64, Function}(1 => home))])
"""
start(IP::String, PORT::Integer, ) -> ::ToolipsServer
--------------------
The start function starts the WebServer.
"""
function start(IP::String = "127.0.0.1", PORT::Integer = 8000)
     ws = WebServer(IP, PORT, routes = routes, extensions = extensions)
     ws.start(); ws
end
```
Functions can be changed by providing to the first postional argument a `Dict{Int64, Function}` with a different function for each user group, represented by an `Int64`. Users can be changed by modifying the users Vector right after it, passwords can promptly and easily be changed using the `set_pwd` method. Of course, this can also be provided via an environmental variable. When writing a Remote function, make sure that there is a method for a single positional argument either of type `AbstractConnnection` or `RemoteConnection`. If your function is annotated as an `AbstractConnection`, you could even use the same exact route that serves your website.
```julia
function home(c::AbstractConnection)
    mydivider = div("mydivider")
    push!(mydivider, h("helloworld", 1, text = "hello world!"))
    push!(mydivider, a("toolips-link", text = "toolips :)",
    href = "https://toolips.app"))
    write!(c, mydivider)
end
```
