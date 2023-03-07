{{/*
Expand the name of the chart.
*/}}
{{- define "boilerplate.name" -}}
{{- default .Chart.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "boilerplate.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "boilerplate.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Common labels
*/}}
{{- define "boilerplate.labels" -}}
helm.sh/chart: {{ include "boilerplate.chart" . }}
{{ include "boilerplate.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
Selector labels
*/}}
{{- define "boilerplate.selectorLabels" -}}
app.kubernetes.io/name: {{ include "boilerplate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}



{{/*
defaults
====================================================================================================================================================================================================
defaults
*/}}


{{/*
Build payload
*/}}
{{- define "payload" }}
{{- include "payload.object.kind" . }}
{{- include "payload.object.apiVersion" . }}
{{ include "payload.object.metadata" . }}
{{ include "payload.object.spec" . }}
{{- end }}

{{/*
Build service
*/}}
{{- define "service" }}
{{ include "payload.service.kind" . }}
{{ include "payload.service.apiVersion" . }}
{{ include "payload.service.metadata" . }}
{{ include "payload.service.spec" . }}
{{- end }}


{{/*
Generate object metadata
*/}}
{{- define "payload.object.metadata" -}}
metadata:
  name: {{ include "boilerplate.fullname" . }}
  labels:
    {{- include "boilerplate.labels" . | nindent 4 }}
{{- end }}


{{/*
Generate object metadata
*/}}
{{- define "payload.service.metadata" -}}
metadata:
  name: {{ include "boilerplate.fullname" . }}
  labels:
    {{- include "boilerplate.labels" . | nindent 4 }}
  {{- with .Values.payload.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}


{{/*
Generate object Kind
*/}}
{{- define "payload.object.kind" -}}
{{- if .Values.payload.kind -}}
kind: {{ .Values.payload.kind }}
{{- else -}}
kind: Deployment
{{- end }}
{{- end }}


{{/*
Generate apiVersion
*/}}
{{- define "payload.object.apiVersion" -}}
{{- if .Values.payload.apiVersion }}
apiVersion: {{ .Values.payload.apiVersion }}
{{- else }}

{{- if eq .Values.payload.kind "Pod" }}
apiVersion: v1
{{- end }}

{{- if eq .Values.payload.kind "Deployment" }}
apiVersion: apps/v1
{{- end }}

{{- if eq .Values.payload.kind "StatefulSet" }}
apiVersion: apps/v1
{{- end }}

{{- if eq .Values.payload.kind "DaemonSet" }}
apiVersion: apps/v1
{{- end }}

{{- if eq .Values.payload.kind "ReplicaSet" }}
apiVersion: apps/v1
{{- end }}

{{- if eq .Values.payload.kind "Job" }}
apiVersion: batch/v1
{{- end }}

{{- if eq .Values.payload.kind "CronJob" }}
apiVersion: batch/v1beta1
{{- end }}

{{- end }}
{{- end }}


{{/*
Generate pod metadata
*/}}
{{- define "payload.pod.metadata" -}}
metadata:
  annotations:
  {{- if .Values.configuration }}
    configuration: {{ toJson .Values.configuration | sha256sum | quote }}
  {{- end }}
  {{- if .Values.payload.image.credentials }}
    credentials: {{ toJson .Values.payload.image.credentials | sha256sum | quote }}
  {{- end }}
  {{- $fullname := include "boilerplate.fullname" . }}
  {{- with .Values.payload.pod.annotations }}
    {{- toYaml . | replace "RELEASE_NAME" $fullname | nindent 4 }}
  {{- end }}
  labels:
    {{- include "boilerplate.selectorLabels" . | nindent 4 }}
{{- end }}


{{/*
Generate object spec
*/}}
{{- define "payload.object.spec" -}}

{{- if has .Values.payload.kind .Values.groups.first }}
{{- include "payload.pod.spec" . }}
{{- end }}

{{- if has .Values.payload.kind .Values.groups.second }}
{{- if eq .Values.payload.kind "Job" }}
{{- include "payload.job.spec" .}}
{{- else }}
{{- include "payload.cronjob.spec" .}}
{{- end }}
{{- end }}

{{- if has .Values.payload.kind .Values.groups.third }}
spec:
  {{- if and (not .Values.payload.autoscaling.enabled) (ne .Values.payload.kind "DaemonSet") }}
  replicas: {{ .Values.payload.replicas }}
  {{- end }}

  {{- if eq .Values.payload.kind "StatefulSet" }}
  # statefulset specific
  serviceName: {{ include "boilerplate.fullname" . }}
  {{- with .Values.payload.statefulset }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- if .Values.payload.volumeClaimTemplates }}
  volumeClaimTemplates:
    {{- toYaml .Values.payload.volumeClaimTemplates | nindent 4 }}
  {{- end }}
  # statefulset specific
  {{- end }}

  {{- if eq .Values.payload.kind "Deployment" }}
  # deployment specific
  {{- with .Values.payload.deployment }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  # deployment specific
  {{- end }}
  selector:
    matchLabels:
      {{- include "boilerplate.selectorLabels" . | nindent 6 }}
  template:
    {{- include "payload.pod.metadata" . | nindent 4 }}
    {{- include "payload.pod.spec" . | nindent 4 }}

{{- end }}

{{- end }}


{{/*
Generate job spec
*/}}
{{- define "payload.job.spec" -}}
spec:
  parallelism: {{ .Values.payload.job.parallelism }}
  backoffLimit: {{ .Values.payload.job.backoffLimit }}
  template:
    {{- include "payload.pod.spec" . | nindent 4 }}
      restartPolicy: {{ .Values.payload.job.restartPolicy }}
{{- end -}}


{{/*
Generate cronjob spec
*/}}
{{- define "payload.cronjob.spec" -}}
spec:
  schedule: {{ .Values.payload.cronjob.schedule | quote }}
  concurrencyPolicy: {{ .Values.payload.cronjob.concurrencyPolicy }}
  jobTemplate:
    spec:
      parallelism: {{ .Values.payload.job.parallelism }}
      template:
        {{- include "payload.pod.spec" . | nindent 8 }}
          restartPolicy: {{ .Values.payload.job.restartPolicy }}
{{- end -}}

{{/*
Generate pod spec
*/}}
{{- define "payload.pod.spec" -}}
spec:
  automountServiceAccountToken: {{ .Values.payload.automountServiceAccountToken }}

  {{- with .Values.payload.hostname }}
  hostname: {{ . }}
  {{- end }}

  {{- with .Values.payload.terminationGracePeriodSeconds }}
  terminationGracePeriodSeconds: {{ . }}
  {{- end }}

  {{- with .Values.payload.hostAliases }}
  hostAliases:
  {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with .Values.payload.hostNetwork }}
  hostNetwork: {{ . }}
  {{- end }}

  {{- with .Values.payload.dnsPolicy }}
  dnsPolicy: {{ . }}
  {{- end }}

  {{- include "payload.init" . | replace "RELEASE_NAME" .Release.Name | nindent 2 }}

  {{- if or .Values.payload.image.pullSecrets .Values.payload.image.credentials }}
  imagePullSecrets:
  {{- if .Values.payload.image.credentials }}
    - name: {{ include "boilerplate.fullname" . }}
  {{- end }}
  {{- with .Values.payload.image.pullSecrets }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}

  {{- with .Values.payload.pod.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  containers:
    {{- if .Values.payload.additionalContainers }}
    {{- toYaml .Values.payload.additionalContainers | replace "RELEASE_NAME" .Release.Name | nindent 4 }}
    {{- end }}

    {{- include "payload.container" . | nindent 4 }}
  {{- include "payload.pod.nsat" . | nindent 2 }}

  {{- if or .Values.payload.volumes .Values.configuration}}
  volumes:
    {{- if .Values.configuration }}
    - name: configmap
      configMap:
        name: {{ include "boilerplate.fullname" . }}
        defaultMode: 0777
        items:
        {{- range $el := .Values.configuration }}
          - key: {{ $el.name }}
            path: {{ $el.name }}
        {{- end }}
    {{- end }}

    {{- with .Values.payload.volumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end }}


{{/*
Generate containers
*/}}
{{- define "payload.container" -}}
- name: {{ include "boilerplate.fullname" . }}
  {{- with .Values.payload.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with .Values.payload.lifecycle }}
  lifecycle:
  {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with .Values.payload.workingDir }}
  workingDir: {{ . }}
  {{- end }}

  {{- with .Values.payload.container }}
    {{- toYaml . | nindent 2 }}
  {{- end }}

  {{- include "payload.container.image" . | nindent 2 }}
  {{- include "payload.container.ports" . | nindent 2 }}
  {{- include "payload.container.probes" . | nindent 2 }}

  {{- if .Values.payload.command }}
  command:
    {{- toYaml .Values.payload.command | nindent 4 }}
  {{- end }}

  {{- with .Values.payload.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- include "environment" . | nindent 2 }}

  {{- if or .Values.configuration .Values.payload.volumeMounts }}
  volumeMounts:
    {{- with .Values.payload.volumeMounts }}
      {{- toYaml . | nindent 4 }}
    {{- end }}

    {{- range $el := .Values.configuration }}
    - name: configmap
      mountPath: {{ $el.mount }}
      subPath: {{ $el.name }}
      readOnly: true
    {{- end }}
  {{- end }}

{{- end }}


{{/*
Generate init container(s)
*/}}
{{- define "payload.init" -}}
{{- $env := include "environment" . }}
{{- $fullname := include "boilerplate.fullname" . }}
{{- $image := include "payload.container.image" . }}
{{- if .Values.payload.init.enabled }}
initContainers:
  {{- range $container := .Values.payload.init.containers }}
  - name: {{ $container.name }}
    {{- if $container.image }}
    image: {{ $container.image }}
    {{- else }}
    {{ $image | nindent 4 }}
    {{- end }}
    {{- $env | nindent 4 }}
    {{- if $container.command }}
    command:
      {{- toYaml $container.command | nindent 6 }}
    {{- end }}
    {{- if or $.Values.configuration $.Values.payload.volumeMounts }}
    volumeMounts:
      {{- with $.Values.payload.volumeMounts }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
      {{- range $el := $.Values.configuration }}
      - name: configmap
        mountPath: {{ $el.mount }}
        subPath: {{ $el.name }}
        readOnly: true
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}


{{/*
Generate container image
*/}}
{{- define "payload.container.image" -}}
image: "{{ .Values.payload.image.repository }}:{{ .Values.payload.image.tag | default .Chart.AppVersion }}"
{{- with .Values.payload.image.pullPolicy }}
imagePullPolicy: {{ . | quote }}
{{- end }}
{{- end }}


{{/*
Generate pod NSAT (nodeSelector, affinity and tolerations)
*/}}
{{- define "payload.pod.nsat" -}}
{{- with .Values.payload.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.payload.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.payload.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}







{{/*
Generate object Kind
*/}}
{{- define "payload.service.kind" -}}
kind: Service
{{- end }}


{{/*
Generate apiVersion
*/}}
{{- define "payload.service.apiVersion" -}}
apiVersion: v1
{{- end }}


{{/*
Generate container ports
*/}}
{{- define "payload.container.ports" -}}
{{- if .Values.ports -}}
ports:
  {{- range $el := .Values.ports }}
  - name: {{ $el.name }}
    containerPort: {{ $el.containerPort }}
    protocol: {{ $el.protocol }}
  {{- end }}
{{- end }}
{{- end }}


{{/*
Generate container probes
*/}}
{{- define "payload.container.probes" -}}

{{- if .Values.payload.probe -}}

{{- with .Values.payload.probe.liveness }}
livenessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}

{{- with .Values.payload.probe.readiness }}
readinessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}

{{- end }}

{{- end }}


{{/*
Generate apiVersion
*/}}
{{- define "payload.service.spec" -}}
spec:
  {{- if .Values.payload.service }}
  {{- if .Values.payload.service.publishNotReadyAddresses }}
  publishNotReadyAddresses: {{ .Values.payload.service.publishNotReadyAddresses }}
  {{- end }}
  {{- if .Values.payload.service.type }}
  type: {{ .Values.payload.service.type }}
  {{- with .Values.payload.service.clusterIP }}
  clusterIP: {{ . }}
  {{- end }}
  {{- end }}
  {{- end }}
  ports:
    {{- range $el := .Values.ports }}
    - name: {{ $el.name }}
      targetPort: {{ $el.containerPort }}
      port: {{ $el.servicePort }}
      protocol: {{ $el.protocol }}
      {{- if and (eq $.Values.payload.service.type "NodePort") $el.nodePort }}
      nodePort: {{ $el.nodePort }}
      {{- end }}
    {{- end }}
  selector:
    {{- include "boilerplate.selectorLabels" . | nindent 4 }}
{{- end }}



{{/*
Create the imagePullSecret
*/}}
{{- define "imagePullSecret" }}
{{- if .Values.payload.image.credentials }}
{{- with .Values.payload.image.credentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}



{{- define "environment" -}}
env:
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
  - name: GOREQPROC
    valueFrom:
      resourceFieldRef:
        containerName: {{ include "boilerplate.fullname" . }}
        resource: requests.cpu
  - name: GOMAXPROC
    valueFrom:
      resourceFieldRef:
        containerName: {{ include "boilerplate.fullname" . }}
        resource: limits.cpu
  - name: GOREQMEM
    valueFrom:
      resourceFieldRef:
        containerName: {{ include "boilerplate.fullname" . }}
        resource: requests.memory
  - name: GOMAXMEM
    valueFrom:
      resourceFieldRef:
        containerName: {{ include "boilerplate.fullname" . }}
        resource: limits.memory
  {{- if eq .Values.payload.kind "StatefulSet" }}
  - name: STS_RS
    value: {{ .Values.payload.replicas | quote }}
  {{- end }}
  - name: RELEASE_NAME
    value: {{ .Release.Name | quote }}
  {{- range $key, $val := .Values.payload.env }}
  - name: {{ $key | quote }}
    value: {{ $val | quote }}
  {{- end }}

  {{- range $key, $val := .Values.payload.envSecrets }}
  {{- range $value := $val }}
  - name: {{ $value | quote }}
    valueFrom:
      secretKeyRef:
        name: {{ $key | quote }}
        key: {{ $value | quote }}
  {{- end }}
  {{- end }}

  {{- with .Values.payload.envRaw }}
  {{- toYaml . | nindent 2}}
  {{- end }}
{{- end }}
