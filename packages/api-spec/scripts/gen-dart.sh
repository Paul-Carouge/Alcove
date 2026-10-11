#!/bin/sh
# Generates the Dart client used by /mobile. Runs openapi-generator in Docker
# so contributors need neither Java nor a global install.
set -eu
cd "$(dirname "$0")/.."
GENERATOR_IMAGE="openapitools/openapi-generator-cli:v7.16.0"
OUT="clients/dart"

rm -rf "$OUT"
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/local" "$GENERATOR_IMAGE" generate \
  -i /local/openapi.yaml \
  -g dart \
  -o "/local/$OUT" \
  --additional-properties=pubName=alcove_api,pubLibrary=alcove_api,pubDescription="Generated Alcove API client",pubAuthor=Alcove \
  --global-property=apiTests=false,modelTests=false,apiDocs=false,modelDocs=false

# Keep the generated package small: no CI files, no git helper.
rm -f "$OUT/.travis.yml" "$OUT/git_push.sh"
rm -rf "$OUT/.openapi-generator" "$OUT/test" "$OUT/doc"
echo "Dart client written to $OUT"
