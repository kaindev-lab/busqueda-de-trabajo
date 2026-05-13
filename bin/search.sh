#!/bin/bash

# Script de búsqueda general usando Remotive API
API_URL="https://remotive.com/api/remote-jobs"

echo "--- Menú de Búsqueda de Empleos ---"
read -p "Introduce el término de búsqueda (ej: developer): " search_term

if command -v jq >/dev/null 2>&1; then
	curl -s "$API_URL?search=$search_term" |
		jq -r '
    .jobs[] |
    [
      .title,
      .company_name,
      .candidate_required_location,
      .salary,
      .job_type
    ] | @tsv
  ' | column -t -s $'\t' >./resultado.txt
else
	echo "jq no está instalado" >./resultado.txt
fi
