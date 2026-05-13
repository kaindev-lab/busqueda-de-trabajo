#!/bin/bash
set -euo pipefail

API_URL="https://remotive.com/api/remote-jobs"

echo "--- Menú de Búsqueda de Empleos ---"
read -rp "Término de búsqueda (ej: developer, ai, python): " search_term
read -rp "Filtrar por ubicación (ej: USA, LATAM, Europe, Worldwide; Enter = no filtrar): " location_filter
read -rp "Filtrar por tipo (full_time, contract, freelance, part_time; Enter = no filtrar): " job_type_filter
read -rp "Solo con salario visible? (s/n): " only_salary
read -rp "Máximo de días desde publicación (ej: 7; Enter = no filtrar): " max_days
read -rp "Límite de resultados (ej: 10; Enter = 20): " result_limit

result_limit="${result_limit:-20}"

if ! command -v jq >/dev/null 2>&1; then
	echo "jq no está instalado. Instálalo con: sudo apt install jq"
	exit 1
fi

tmp_json="$(mktemp)"
tmp_out="$(mktemp)"
trap 'rm -f "$tmp_json" "$tmp_out"' EXIT

curl -sG "$API_URL" --data-urlencode "search=$search_term" >"$tmp_json"

jq_query='
  .jobs
  | map(select(
      if $location == "" then true
      else (.candidate_required_location // "" | ascii_downcase | contains($location | ascii_downcase))
      end
    ))
  | map(select(
      if $jobtype == "" then true
      else ((.job_type // "" | ascii_downcase) == ($jobtype | ascii_downcase))
      end
    ))
  | map(select(
      if $onlysalary == "s" then ((.salary // "") | length > 0 and .salary != "-")
      else true
      end
    ))
  | map(select(
      if $days == "" then true
      else (.publication_date // "" >= ($cutoff))
      end
    ))
  | sort_by(.publication_date) | reverse
  | .[:($limit | tonumber)]
  | map([
      (.publication_date // "" | split("T")[0]),
      (.title // ""),
      (.company_name // ""),
      (.candidate_required_location // ""),
      (.job_type // ""),
      (.salary // "-"),
      (.url // "")
    ])
  | .[]
  | @tsv
'

cutoff=""
if [[ -n "${max_days:-}" ]]; then
	cutoff="$(date -u -d "${max_days} days ago" +"%Y-%m-%dT%H:%M:%S")"
fi

jq -r \
	--arg location "${location_filter:-}" \
	--arg jobtype "${job_type_filter:-}" \
	--arg onlysalary "${only_salary:-n}" \
	--arg days "${max_days:-}" \
	--arg cutoff "$cutoff" \
	--arg limit "$result_limit" \
	"$jq_query" \
	"$tmp_json" >"$tmp_out"

if [[ ! -s "$tmp_out" ]]; then
	echo "No se encontraron resultados con esos filtros."
	exit 0
fi

printf "FECHA       | TÍTULO | EMPRESA | UBICACIÓN | TIPO | SALARIO | URL\n"
printf "%s\n" "---------------------------------------------------------------------------------------------------------------"
column -t -s $'\t' "$tmp_out"
