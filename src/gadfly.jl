import .Gadfly
import Cairo, Fontconfig

Image(height, width, a::Gadfly.Plot) =
    Image(height, width, ImageFileData(height, width, a))

function ImageFileData(height, width, a::Gadfly.Plot)
    filename = tempname()*".pdf"
    Gadfly.draw(Gadfly.PDF(filename, width*Gadfly.cm, height*Gadfly.cm), a)
    r = read(filename)
    rm(filename)
    ImageFileData(r, :pdf)
end