import .Plots

Image(height, width, a::T) where {T<:Union{Plots.Plot,Plots.Subplot}} =
    Image(height, width, ImageFileData(height, width, a))

function ImageFileData(height, width, a::T) where {T<:Union{Plots.Plot,Plots.Subplot}}
    filename = tempname()*".pdf"
    Plots.pdf(a, filename)
    r = read(filename)
    rm(filename)
    ImageFileData(r, :pdf)
end