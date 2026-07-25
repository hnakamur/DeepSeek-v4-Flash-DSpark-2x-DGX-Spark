recipe_dir := `pwd`

update:
  cd "{{recipe_dir}}"
  git fetch origin
  if [ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ]; then echo 'no update, exit.'; exit 0; fi
  git switch main
  git reset --hard origin/main
  git switch add_my_justfile
  git rebase main
  git push hnakamur --force-with-lease main add_my_justfile
  just env

sync:
  ssh pgx2 '\
  cd "{{recipe_dir}}" && \
  git fetch origin && \
  git switch --discard-changes main && \
  git reset --hard origin/main \
  '
  rsync .env.dspark "pgx2:{{recipe_dir}}"

  ssh pgx1 '\
  cd "{{recipe_dir}}" && \
  git fetch origin && \
  git switch --discard-changes main && \
  git reset --hard origin/main \
  '
  rsync .env.dspark "pgx1:{{recipe_dir}}"

start:
  ssh pgx1 'cd "{{recipe_dir}}" && ./start-deepseek-v4-flash-dspark.sh'

stop:
  ssh pgx1 'cd "{{recipe_dir}}" && ./stop-deepseek-v4-flash-dspark.sh'

env:
  sed -e 's/^VLLM_PORT=.*/VLLM_PORT=8000/;\
    s/^DEFAULT_THINKING=.*/DEFAULT_THINKING=off/;\
    s/^WORKER_HOST=.*/WORKER_HOST=192.168.177.12/;\
    s/^MASTER_ADDR=.*/MASTER_ADDR=192.168.177.11/;\
    s/^VLLM_HOST_IP=.*/VLLM_HOST_IP=192.168.177.11/;\
    s/^WORKER_VLLM_HOST_IP=.*/WORKER_VLLM_HOST_IP=192.168.177.12/;\
    s/^NCCL_IB_HCA=.*/NCCL_IB_HCA=rocep1s0f1/;\
    s/^NCCL_SOCKET_IFNAME=.*/NCCL_SOCKET_IFNAME=enp1s0f1np1/;\
    s/^TP_SOCKET_IFNAME=.*/NTP_SOCKET_IFNAME=enp1s0f1np1/;\
    s/^GLOO_SOCKET_IFNAME=.*/GLOO_SOCKET_IFNAME=enp1s0f1np1/\
  ' .env.dspark.example > .env.dspark
