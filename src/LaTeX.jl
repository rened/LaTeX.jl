module LaTeX

using SHA
import Images

@windows_only include("wincall.jl")

export Section, Table, Tabular, Figure, Image, ImageFileData, report, openpdf

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
    data::Array{Uint8}
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
    Images.imwrite(image, filename)
    r = readall(filename)
    rm(filename)
    Image(height, width, ImageFileData(r, :png))
end


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

function openpdf(latex)
dirname = "$(tempname()).d";
mkdir(dirname)
texname = joinpath(dirname, "document.tex")
pdfname = joinpath(dirname,"document.pdf")
open(texname, "w") do file
	write(file, latex)
end
readall(`pdflatex -halt-on-error -output-directory $dirname $texname`)
readall(`pdflatex -halt-on-error -output-directory $dirname $texname`)

if OS_NAME == :Windows
	command = "cmd /K start \"\" $pdfname"
	CreateProcess(command)
else
	spawn(`open $pdfname`)
end
nothing
end
processitem{T<:String}(p, item::T, indent) = {item}
processitem{T<:Number}(p, item::T, indent) = {"$item"}

flatten(a) = flatten({},a)
function flatten(r, a)
    for x in a
        isa(x,Array) ? flatten(r,x) : push!(r,x)
    end
    r
end

function processitem(p, items::Array, indent)
    isempty(items) && return {""}
    map(x -> processitem(p, x, indent), items)
end

function processitem(p, item::Section, indent)
    commands = {"chapter","section","subsection","subsubsection","paragraph"}
    if indent > p[:maxdepth]
        cmd = last(commands)
    else
        cmd = commands[indent]
    end

    r = {"\\$cmd{$(item.title)}\\nopagebreak"};
    append!(r, processitem(p, item.content, indent+1))
end

function processitem(p, item::Figure, indent)
    r = {"\\begin{figure}[!ht]"}
    append!(r, processitem(p, item.content, indent))
    append!(r, {"\\caption{$(item.caption)}", "\\end{figure}"})
end

function processitem(p, item::Image, indent)
    filename = joinpath(tempdir(), sha256(item.data.data)*".$(item.data.typ)")
    open(filename, "w") do file
        write(file, item.data.data)
    end
        
    r = {"\\includegraphics["}
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
    r = {"\\begin{table}[!ht]"}
    push!(r, processitem(p, item.content, indent))
    push!(r, {"\\caption{$(item.caption)}", "\\end{table}"})
end
    
function processitem(p, item::Tabular, indent)
    if ndims(item.content) == 1
        item.content = reshape(item.content, (1, length(item.content)))
    end
    sm, sn = size(item.content)
    r = {"\\begin{tabular}[!ht]{$(repeat("c", sn))}"}
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
report(items; kargs...) = report(Dict(), items; kargs...)
function report(p, items; author = "", title = "Report", date = "", toc = false,
    theabstract = "")
    
    p = merge({:maxdepth => 3, :tmppath => tempdir()}, p)
    

    mkpath(p[:tmppath])

    r = {
    "\\documentclass[11pt,a4paper]{report}", 
    "\\usepackage[latin1]{inputenc}", 
    "\\usepackage{graphicx}", 
    "\\usepackage[cm]{fullpage}", 
    "\\usepackage{sectsty}", 
    "\\usepackage{morefloats}", 
    "\\usepackage[section]{placeins}", 
    "\\allsectionsfont{\\normalfont\\sffamily\\bfseries}", 
    isempty(date) ? "" : "\\date{$date}", 
    isempty(author) ? "": "\\author{$author}", 
    "\\title{$title}", 
    "\\begin{document}", 
    "\\maketitle", 
    isempty(theabstract) ? "": "\\begin{abstract}$theabstract\\end{abstract}", 
    toc ? "\\tableofcontents" : ""}

    append!(r, processitem(p, items, 1))
    push!(r, "\\end{document}")

    r = join(flatten(r), "\n")
    r
end


#openpdf(report(Dict(),{}))
#openpdf(report(Dict(),{"Test"}))
#openpdf(report(Section("Section header", "content"), toc = false));

#sec1 = Section("sec1", "content1");
#sec2 = Section("sec", "content1");
#ch1 = Section("ch1", {sec1, sec2});

#openpdf(report(ch1, toc=true))

#openpdf(report(Figure("caption", "content")))
#openpdf(report(Table("caption", "content")))
#openpdf(report(Tabular({'1' '2'})))


end # module
