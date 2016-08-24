__precompile__(false)  # as precompiling Winston does not work

module LaTeX

using SHA, Compat
import Images

@static if is_windows() include("wincall.jl") end

export Section, Table, Tabular, Figure, Image, ImageFileData, Code, TOC,
    Abstract, report, openpdf, document, DocumentClass, Title, Author

type TOC
end

type Abstract
    content
end

type Section
    title
    content
end

type Table
    caption
    content
end

type Tabular
    content::Array
end

type Figure
    caption
    content
end

type ImageFileData
    data::Array{UInt8}
    typ::Symbol
end

type Image
    height
    width
    data::ImageFileData
end

Image(height, width, data::Array) = Image(height, width, size(data,3) == 3 ? Images.colorim(data) : Images.grayim(data'))
function Image(height, width, image::Images.Image)
    filename = tempname()*".png"
    Images.save(filename, image)
    r = readall(filename)
    rm(filename)
    Image(height, width, ImageFileData(r, :png))
end

type Code
    code
end

# declarations: non-displayed items controlling document metadata
abstract AbstractDecl

type DocumentClass <: AbstractDecl
    class::AbstractString
    settings::Vector{AbstractString}
end

type Author <: AbstractDecl
    text::AbstractString
end

type Title <: AbstractDecl
    text::AbstractString
end

type Style <: AbstractDecl
    section::AbstractString
end

isdecl(::AbstractDecl) = true
isdecl(::Date) = true
isdecl(_) = false

function processdecl(d::DocumentClass)
    if isempty(d.settings)
        "\\documentclass{$(d.class)}"
    else
        "\\documentclass[$(join(d.settings, ','))]{$(d.class)}"
    end
end
processdecl(a::Author) = "\\author{$(a.text)}"
processdecl(t::Title) = "\\title{$(t.text)}"
processdecl(d::Date) = "\\date{$d}"
processdecl(s::Style) = "\\allsectionsfont{$(s.section)}"


isinstalled(a) = isa(Pkg.installed(a), VersionNumber)
if isinstalled("Winston")
    import Winston
    Image(height, width, a::Winston.FramedPlot) =
        Image(height, width, ImageFileData(a))
    function ImageFileData(a::Winston.FramedPlot)
        filename = tempname()*".pdf"
        Winston.savefig(a, filename)
        r = readall(filename)
        rm(filename)
        ImageFileData(r, :pdf)
    end
end

if isinstalled("Gadfly")
    import Gadfly
    Image(height, width, a::Gadfly.Plot) =
    Image(height, width, ImageFileData(height, width, a))
    function ImageFileData(height, width, a::Gadfly.Plot)
        filename = tempname()*".pdf"
        Gadfly.draw(Gadfly.PDF(filename, width*Gadfly.cm, height*Gadfly.cm), a)
        r = readall(filename)
        rm(filename)
        ImageFileData(r, :pdf)
    end
end

if isinstalled("Plots")
    import Plots
    Image{T<:Union{Plots.Plot,Plots.Subplot}}(height, width, a::T) =
        Image(height, width, ImageFileData(height, width, a))
    function ImageFileData{T<:Union{Plots.Plot,Plots.Subplot}}(height, width, a::T)
        filename = tempname()*".pdf"
        Plots.pdf(a, filename)
        r = readall(filename)
        rm(filename)
        ImageFileData(r, :pdf)
    end
end

function openpdf(latex)
    dirname = "$(tempname()).d"
    mkdir(dirname)
    texname = joinpath(dirname, "document.tex")
    pdfname = joinpath(dirname,"document.pdf")
    open(texname, "w") do file
        write(file, latex)
    end
    cd(dirname) do
        for i in 1:2
            output = readall(`pdflatex -shell-escape -halt-on-error $texname`)
            contains("Error:", output) && println(output)
        end
    end

    if OS_NAME == :Windows
        command = "cmd /K start \"\" $pdfname"
        CreateProcess(command)
    else
        spawn(`open $pdfname`)
    end
    nothing
end

flatten(a) = flatten(Any[],a)
function flatten(r, a)
    for x in a
        isa(x,Array) ? flatten(r,x) : push!(r,x)
    end
    r
end

processitem{T<:AbstractString}(p, item::T, indent) = [item]
processitem{T<:Number}(p, item::T, indent) = ["$item"]
processitem(p, decl, indent) = []

function processitem(p, items::Array, indent)
    isempty(items) && return [""]
    map(x -> processitem(p, x, indent), items)
end

function processitem(p, item::TOC, indent)
    ["\\tableofcontents"]
end

function processitem(p, item::Abstract, indent)
    r = Any["\\begin{abstract}"]
    append!(r, processitem(p, item.content, indent))
    push!(r, "\\end{abstract}")
end

function processitem(p, item::Section, indent)
    if indent > p[:maxdepth]
        cmd = last(p[:sectioncommands])
    else
        cmd = p[:sectioncommands][indent]
    end

    r = Any["\\$cmd{$(item.title)}\\nopagebreak"]
    append!(r, processitem(p, item.content, indent+1))
end

function processitem(p, item::Figure, indent)
    r = Any["\\begin{figure}[!ht]"]
    append!(r, processitem(p, item.content, indent))
    append!(r, ["\\caption{$(item.caption)}", "\\end{figure}"])
end

processitem(p, item::Code, indent) = [
    "\\usestyle{default}",
    "\\begin{pygmented}{jl}",
    split(item.code, '\n')...,
    "\\end{pygmented}"]

function processitem(p, item::Image, indent)
    filename = joinpath(tempdir(), bytes2hex(sha256(item.data.data))*".$(item.data.typ)")
    open(filename, "w") do file
        write(file, item.data.data)
    end

    r = Any["\\includegraphics["]
    if !isempty(item.width)
        if item.width <= 1
            push!(r, "width=$(item.width)\\textwidth,")
        else
            push!(r, "width=$(item.width)cm,")
        end
    end
    if !isempty(item.height)
        if item.height <= 1
            push!(r, "height=$(item.height)\\textheight,")
        else
            push!(r, "height=$(item.height)cm")
        end
    end
	escaped_filename = replace(filename,"\\","/")
    push!(r, "]{$escaped_filename}")
    flatten(r)
end

function processitem(p, item::Table, indent)
    r = Any["\\begin{table}[!ht]"]
    push!(r, processitem(p, item.content, indent))
    push!(r, ["\\caption{$(item.caption)}", "\\end{table}"])
end

function processitem(p, item::Tabular, indent)
    if ndims(item.content) == 1
        item.content = reshape(item.content, (1, length(item.content)))
    end
    sm, sn = size(item.content)
    r = Any["\\begin{tabular}[!ht]{$(repeat("c", sn))}"]
    for m = 1:sm
        for n = 1:sn
            push!(r, processitem(p, item.content[m,n], indent))
            if n < sn
                push!(r, " & ")
            end
        end
        push!(r, " \\\\")
    end
    push!(r, "\\end{tabular}")
end

# get required packages and settings for this element and all children
getrequirements(item) = Dict()
function getrequirements(items::Array)
    base = Dict()
    for i in items
        requirements = getrequirements(i)
        for (requirement, settings) in requirements
            if haskey(base, requirement)
                union!(base[requirement], settings)
            else
                base[requirement] = settings
            end
        end
    end
    base
end
getrequirements(::Code) = Dict("texments" => Set([]))
getrequirements(::Image) = Dict("graphicx" => Set([]))
getrequirements(a::Abstract) = getrequirements(a.content)
getrequirements(s::Section) = getrequirements(Any[s.title, s.content])
getrequirements(t::Table) = getrequirements(Any[t.caption, t.content])
getrequirements(t::Tabular) = getrequirements(t.content)
getrequirements(f::Figure) = getrequirements(Any[f.caption, f.content])

getrequirements(d::Style) = Dict("sectsty" => Set([]))

# add information about document class in dictionary.
function inform!(p, d::DocumentClass)
    if d.class == "report"
        p[:sectioncommands] = ["chapter", "section", "subsection",
            "subsubsection","paragraph"]
    else  # article & others
        p[:sectioncommands] = ["section", "subsection", "subsubsection",
            "paragraph"]
    end
end

document(items) = document(Dict(), items)
function document(p, items)
    # make required path
    p = merge((Dict(:maxdepth => 3, :tmppath => tempdir())), p)

    mkpath(p[:tmppath])

    # document properties
    dclass = nothing
    decls = Dict()

    # parse items tree for declarations (currently to depth 1)
    for tr in items
        if isa(tr, DocumentClass)
            dclass = tr
        elseif isdecl(tr)
            decls[typeof(tr)] = tr
        end
    end

    # modify preamble dict to reflect docclass, e.g. section headers
    inform!(p, dclass)

    # global required packages (keep small)
    require = Dict(
        "inputenc" => Set(["latin1"]),
        "fullpage" => Set(["cm"]),
        "morefloats" => Set([]),
        "placeins" => Set(["section"]))

    # add required packages (dynamic based off items)
    docrequire = getrequirements(items)

    preamble = AbstractString[]
    docbody = processitem(p, items, 1)

    # build up the document starting from the beginning
    push!(preamble, processdecl(dclass))
    for (package, settings) in merge(require, docrequire)
        if isempty(settings)
            push!(preamble, "\\usepackage{$package}")
        else
            push!(preamble, "\\usepackage[$(join(settings, ','))]{$package}")
        end
    end

    # some other default stuff
    append!(preamble, [
        [processdecl(dl) for dl in values(decls)]...,
        "\\begin{document}",  # technically not preamble anymore
        "\\maketitle"])

    # append the document
    r = vcat(preamble, docbody)
    push!(r, "\\end{document}")

    r = join(flatten(r), "\n")
    r
end

report(items; kargs...) = report(Dict(), items; kargs...)
function report(p, items; author = "", title = "Report", date = "", toc = false,
    theabstract = "")

    doctree = Any[DocumentClass("report", ["11pt", "a4paper"])]
    # make date, author, etc. if available
    isempty(date) || push!(doctree, Date(date))
    isempty(author) || push!(doctree, Author(author))
    push!(doctree, Title(title))
    isempty(theabstract) || push!(doctree, Abstract(theabstract))
    toc && push!(doctree, TOC())

    # default styling
    push!(doctree, Style("\\normalfont\\sffamily\\bfseries"))

    if isa(items, Vector)
        append!(doctree, items)
    else
        push!(doctree, items)
    end
    document(p, doctree)
end


#openpdf(report(Dict(),[]))
#openpdf(report(Dict(),["Test"]))
#openpdf(report(Section("Section header", "content"), toc = false))

#sec1 = Section("sec1", "content1")
#sec2 = Section("sec", "content1")
#ch1 = Section("ch1", [sec1, sec2])

#openpdf(report(ch1, toc=true))

#openpdf(report(Figure("caption", "content")))
#openpdf(report(Table("caption", "content")))
#openpdf(report(Tabular(['1' '2'])))


end # module
