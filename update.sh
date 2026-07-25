#!/bin/bash
set -eu

show_usage_and_exit() {
  >&2 cat <<'EOF'
Usage: update.sh [OPTIONS]

Options:
  -f, --force   force update and restart vLLM at pgx1 and pgx2.
  -h --help     show this help and exit.
EOF
}

force=0

while (($#)); do
  case "$1" in
  -f|--force)
    force=1
    shift
    ;;
  -h|--help)
    show_usage_and_exit
    ;;
  *)
    ;;
  esac
done

script_dir="$(cd -P -- $(dirname "${BASH_SOURCE[0]}") && pwd -P)"
recipe_dir="${script_dir}"

cd "${recipe_dir}"
git fetch origin
if [ "$(git rev-parse main)" = "$(git rev-parse origin/main)" -a "${force}" -eq 0 ]; then
  echo 'no update, exit.'
  exit 0
fi

git switch main
git reset --hard origin/main
git switch add_my_justfile
git rebase main
git push hnakamur --force-with-lease main add_my_justfile

sed -e 's/^VLLM_PORT=.*/VLLM_PORT=8000/;
  s/^DEFAULT_THINKING=.*/DEFAULT_THINKING=off/;
  s/^WORKER_HOST=.*/WORKER_HOST=192.168.177.12/;
  s/^MASTER_ADDR=.*/MASTER_ADDR=192.168.177.11/;
  s/^VLLM_HOST_IP=.*/VLLM_HOST_IP=192.168.177.11/;
  s/^WORKER_VLLM_HOST_IP=.*/WORKER_VLLM_HOST_IP=192.168.177.12/;
  s/^NCCL_IB_HCA=.*/NCCL_IB_HCA=rocep1s0f1/;
  s/^NCCL_SOCKET_IFNAME=.*/NCCL_SOCKET_IFNAME=enp1s0f1np1/;
  s/^TP_SOCKET_IFNAME=.*/NTP_SOCKET_IFNAME=enp1s0f1np1/;
  s/^GLOO_SOCKET_IFNAME=.*/GLOO_SOCKET_IFNAME=enp1s0f1np1/
' .env.dspark.example > .env.dspark

ssh pgx2 "
  cd '${recipe_dir}' &&
  git fetch origin &&
  git switch --discard-changes main &&
  git reset --hard origin/main
"
rsync .env.dspark "pgx2:${recipe_dir}"

ssh pgx1 "
  cd '${recipe_dir}' &&
  git fetch origin &&
  git switch --discard-changes main &&
  git reset --hard origin/main
"
rsync .env.dspark "pgx2:${recipe_dir}"
ssh pgx1 "
  cd '${recipe_dir}' &&
  ./stop-deepseek-v4-flash-dspark.sh || : &&
  ./start-deepseek-v4-flash-dspark.sh --host 0.0.0.0 --port 8000
"
