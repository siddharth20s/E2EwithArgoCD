{{- define "demo-e2e.namespace" -}}
{{- if .Values.namespaceOverride -}}
{{ .Values.namespaceOverride }}
{{- else -}}
{{ .Release.Namespace }}
{{- end -}}
{{- end -}}
