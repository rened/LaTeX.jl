println("\n\n\nRunning tests ...")

using LaTeX
import LaTeX: getrequirements
using Base.Test

# Check that package dependency is working
@test haskey(
    getrequirements(Section("Code", [Code("""test_getrequirements()""")])),
    "texments")

# Test a minimal document
doc = document([
    DocumentClass("article", ["11pt", "letterpaper"]),
    Date(2015, 11, 23),
    Title("Sample Article"),
    Author("Andi Andromeda"),
    Section("Code", [Code("""# minimal example""")])])
@test split(doc, '\n')[1] == "\\documentclass[11pt,letterpaper]{article}"
@test contains(doc, "\\date{2015-11-23}")
@test contains(doc, "\\author{Andi Andromeda}")
@test contains(doc, "\\section")  # articles have section as top-level
@test contains(doc, "\\usestyle{default}")  # needed for code

# Test a minimal report
rep = report(Section("Test", "Lorum ipsum."))
@test split(rep, '\n')[1] == "\\documentclass[11pt,a4paper]{report}"
@test contains(rep, "\\chapter")  # reports have chapter as top-level

println("   ... done running tests!")

