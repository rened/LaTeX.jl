# this is just to test locally, since we don't want 
# to impose Gadfly dependency
using Gadfly
import Cairo, Fontconfig

p = plot(x=[1])
Image0 = Image(12, 16, p)

c = Code("""
h = 1/2
F' = sin(x)
""")

l = document([
    DocumentClass("article", ["11pt", "a4paper"]),
    Title("Title"),
    Section("Section",[
        Figure("Figure", Image0),
    ]),
])

openpdf(l)