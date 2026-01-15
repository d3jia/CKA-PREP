#!/usr/bin/env bash
set -euo pipefail

print_menu() {
  cat <<'MENU'
[CKA MOCK EXAM] Please Reply 1~17 to initialise the Question
----------------------------------------------------------------------
 [1] ArgoCD Helm
 [2] SideCar
 [3] Gateway API Migration
 [4] WordPress Resources
 [5] Storage Class
 [6] Priority Class
 [7] Ingress Echo
 [8] CRDs
 [9] Network Policy
[10] HPA
[11] CNI Install
[12] MariaDB Restore
[13] CRI-Dockerd
[14] Kube-apiserver Fix
[15] Taints & Tolerations
[16] NodePort Service
[17] TLS Config
 [X] Exit
----------------------------------------------------------------------
MENU
}

run_question() {
  local num="$1"
  local dir="Question-$num"
  local setup="$dir/LabSetUp.bash"
  local question_file

  if [[ ! -d "$dir" ]]; then
    echo "Question directory not found: $dir" >&2
    exit 1
  fi

  if [[ ! -f "$setup" ]]; then
    echo "Setup script not found: $setup" >&2
    exit 1
  fi

  question_file="$dir/Questions.bash"
  if [[ ! -f "$question_file" ]]; then
    echo "Question file not found: $question_file" >&2
    exit 1
  fi

  bash "$setup"
  cat "$question_file"
  printf "\n----------------------------------------------------------------------\n"
}

print_menu
read -r user_choice
choice=$(printf '%s' "$user_choice" | tr '[:upper:]' '[:lower:]')

case "$choice" in
  x|q|exit)
    exit 0
    ;;
  [1-9]|1[0-7])
    run_question "$choice"
    ;;
  *)
    echo "Invalid selection. Please reply with 1~17, or x/q/exit to quit." >&2
    exit 1
    ;;
 esac
