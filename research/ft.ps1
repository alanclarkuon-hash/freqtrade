# Run from any directory. All Freqtrade commands execute inside Docker.
# The explicit context avoids this PC's stale desktop-linux pipe.
& docker --context default compose -f "$PSScriptRoot/compose.yaml" run --rm -T research @args
if ($LASTEXITCODE -ne 0) { throw "Freqtrade container exited with code $LASTEXITCODE" }
