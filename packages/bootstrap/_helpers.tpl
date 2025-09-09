{{- define "readManifest" -}}
templates:
{{- $manifestDir := (printf "%s/%s" (requiredEnv "REPO_ROOT") (.PATH | trim)) -}}
{{- range $index,$item := readDirEntries $manifestDir }}
- {{ readFile (printf "%s/%s" $manifestDir $item.Name) | toYaml }}
{{- end }}
{{- end -}}
