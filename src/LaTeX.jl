module LaTeX

using SHA, Compat, Pkg, Dates, Requires
import Images

Sys.iswindows() && include("wincall.jl") 

export Section, Table, Tabular, Figure, Image, ImageFileData, Code, TOC,
    Abstract, report, makepdf, writepdf, openpdf, document, DocumentClass, Title, Author

mutable struct TOC
end

mutable struct Abstract
    content
end

mutable struct Section
    title
    content
end

mutable struct Table
    caption
    content
end

mutable struct Tabular
    content::Array
end

mutable struct Figure
    caption
    content
end

mutable struct ImageFileData
    data::Array{UInt8}
    typ::Symbol
end

mutable struct Image
    height
    width
    data::ImageFileData
end

Image(height, width, data::Array) = Image(height, width, size(data,3) == 3 ? Images.colorim(data) : Images.grayim(data'))
function Image(height, width, image)
    filename = tempname()*".png"
    Images.save(filename, image)
    r = read(filename)
    rm(filename)
    Image(height, width, ImageFileData(r, :png))
end

mutable struct Code
    code
end

# declarations: non-displayed items controlling document metadata
abstract type AbstractDecl end 

mutable struct DocumentClass <: AbstractDecl
    class::AbstractString
    settings::Vector{AbstractString}
end

mutable struct Author <: AbstractDecl
    text::AbstractString
end

mutable struct Title <: AbstractDecl
    text::AbstractString
end

mutable struct Style <: AbstractDecl
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

""" 
    makepdf(latex) 

Build pdf document in temporary directory using pdflatex and returns
its path.
"""
function makepdf(latex)
    dirname = "$(tempname()).d"
    mkdir(dirname)
    texname = joinpath(dirname, "document.tex")
    pdfname = joinpath(dirname, "document.pdf")
    open(texname, "w") do file
        write(file, latex)
    end
    cd(dirname) do
        for i in 1:2
            output = read(`pdflatex -shell-escape -halt-on-error $texname`,String)
            occursin("Error:", output) && println(output)
        end
    end
    pdfname
end

""" 
    writepdf(latex, filename)

Build pdf document and copy it to `filename`.
"""
function writepdf(latex, filename)
    pdfname = makepdf(latex)
    cp(pdfname,filename,remove_destination=false)
    nothing
end

""" 
    openpdf(latex)

Build pdf document and open it.
"""
function openpdf(latex)
    pdfname = makepdf(latex)
    if Sys.iswindows()
        command = `cmd /K start \"\" $pdfname`
        run(command)
    else
        run(`open $pdfname`)
    end
    pdfname
end

flatten(a) = flatten(Any[],a)
function flatten(r, a)
    for x in a
        isa(x,Array) ? flatten(r,x) : push!(r,x)
    end
    r
end

processitem(p, item::T, indent) where {T<:AbstractString} = [item]
processitem(p, item::T, indent) where {T<:Number} = ["$item"]
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
	escaped_filename = replace(filename,"\\" => "/")
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

function __init__()
    @require Winston = "bd07be1c-e76f-5ff0-9c0b-f51ef45303c6" include("winston.jl")
    @require Gadfly = "c91e804a-d5a3-530f-b6f0-dfbca275c004" include("gadfly.jl")
    @require Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80" include("plots.jl")
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
