{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "benchify.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "benchify.labels" -}}
helm.sh/chart: {{ include "benchify.chart" . }}
{{ include "benchify.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "benchify.selectorLabels" -}}
app.kubernetes.io/name: {{ include "benchify.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Release name (truncated to 63 chars)
*/}}
{{- define "benchify.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name (release name + chart name)
*/}}
{{- define "benchify.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Database URL
*/}}
{{- define "benchify.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgres://%s:%s@benchify-postgresql:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password .Values.postgresql.auth.database }}
{{- else }}
{{- printf "postgres://%s:%s@%s:%d/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password .Values.postgresql.external.host (int .Values.postgresql.external.port) .Values.postgresql.auth.database }}
{{- end }}
{{- end }}

{{/*
Server environment variables
*/}}
{{- define "benchify.serverEnv" -}}
- name: HOST
  value: "0.0.0.0"
- name: PORT
  value: {{ .Values.service.port | quote }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "benchify.fullname" . }}-secret
      key: database_url
- name: JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "benchify.fullname" . }}-secret
      key: jwt_secret
- name: CORS_ALLOWED_ORIGINS__0
  value: {{ index .Values.server.corsAllowedOrigins 0 | quote }}
- name: UPLOAD_DIR
  value: {{ .Values.server.uploadDir | quote }}
{{- if .Values.server.sso.enabled }}
- name: SSO_ENABLED
  value: "true"
- name: SSO_REDIRECT_BASE_URL
  value: {{ .Values.server.sso.redirectBaseUrl | quote }}
{{- end }}
{{- if .Values.server.jira.enabled }}
- name: JIRA_ENABLED
  value: "true"
- name: JIRA_BASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "benchify.fullname" . }}-secret
      key: jira_base_url
- name: JIRA_EMAIL
  valueFrom:
    secretKeyRef:
      name: {{ include "benchify.fullname" . }}-secret
      key: jira_email
- name: JIRA_API_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "benchify.fullname" . }}-secret
      key: jira_api_token
{{- end }}
{{- if .Values.server.smtp.host }}
- name: SMTP_HOST
  value: {{ .Values.server.smtp.host | quote }}
- name: SMTP_PORT
  value: {{ .Values.server.smtp.port | quote }}
- name: SMTP_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "benchify.fullname" . }}-secret
      key: smtp_username
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "benchify.fullname" . }}-secret
      key: smtp_password
- name: SMTP_FROM_EMAIL
  value: {{ .Values.server.smtp.fromEmail | quote }}
{{- end }}
{{- if .Values.server.slack.webhookUrl }}
- name: SLACK_WEBHOOK_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "benchify.fullname" . }}-secret
      key: slack_webhook_url
{{- end }}
{{- end }}
