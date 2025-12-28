#!/usr/bin/env bash
set -euo pipefail

print_menu() {
  cat <<'MENU'
[CKA MOCK EXAM] Please Reply 1~17 to initialise the Question.
----------------------------------------------------------------------
Q1. ArgoCD Helm
Q2. SideCar
Q3. Gateway API Migration
Q4. WordPress Resources
Q5. Storage Class
Q6. Priority Class
Q7. Ingress Echo
Q8. CRDs
Q9. Network Policy
Q10. HPA
Q11. CNI Install
Q12. MariaDB Restore
Q13. CRI-Dockerd
Q14. Kube-apiserver Fix
Q15. Taints & Tolerations
Q16. NodePort Service
Q17. TLS Config
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

  question_file=$(ls "$dir"/Question*.bash 2>/dev/null | head -n 1 || true)
  if [[ -z "$question_file" ]]; then
    echo "Question script not found in $dir" >&2
    exit 1
  fi

  bash "$setup"
  bash "$question_file"
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
