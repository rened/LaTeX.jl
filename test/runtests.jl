using LaTeX
import LaTeX: getrequirements
using Test, Dates

# Check that package dependency is working
@test haskey(
    getrequirements(Section("Code", [Code("""test_getrequirements()""")])),
    "texments")

@testset "Test a minimal document" begin

    doc = document([
        DocumentClass("article", ["11pt", "letterpaper"]),
        Date(2015, 11, 23),
        Title("Sample Article"),
        Author("Andi Andromeda"),
        Section("Code", [Code("""# minimal example""")])])
    @test split(doc, '\n')[1] == "\\documentclass[11pt,letterpaper]{article}"
    @test occursin("\\date{2015-11-23}", doc)
    @test occursin("\\author{Andi Andromeda}", doc)
    @test occursin("\\section", doc)  # articles have section as top-level
    @test occursin("\\usestyle{default}", doc)  # needed for code

    # Test a minimal report
    rep = report(Section("Test", "Lorum ipsum."))
    @test split(rep, '\n')[1] == "\\documentclass[11pt,a4paper]{report}"
    @test occursin("\\chapter", rep)  # reports have chapter as top-level

end
