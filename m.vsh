#!/usr/bin/env -S v run

result := execute('v run src/.')
println(result.output)
