import .Winston

Image(height, width, a::Winston.FramedPlot) =
    Image(height, width, ImageFileData(a))
    
function ImageFileData(a::Winston.FramedPlot)
    filename = tempname()*".pdf"
    Winston.savefig(a, filename)
    r = read(filename)
    rm(filename)
    ImageFileData(r, :pdf)
end