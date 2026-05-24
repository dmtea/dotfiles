alias serpspot!="
cd ~/dev/projects/serpspot

tmux new -s serpspot -d

###

tmux split-window -h -t serpspot
tmux split-window -h -t serpspot:1.1
tmux select-layout -t serpspot even-horizontal

tmux split-window -v -t serpspot:1.1 -l 15
tmux split-window -v -t serpspot:1.2

# tmux split-window -v -t serpspot:1.4 -l 15

tmux split-window -v -t serpspot:1.5 -l 15
tmux split-window -v -t serpspot:1.6

###

tmux send-keys -t serpspot:1.1 'cd serpspot_backend' Enter
tmux send-keys -t serpspot:1.1 'uvicorn app.main:app --reload' Enter

tmux send-keys -t serpspot:1.2 'cd serpspot_frontend' Enter
tmux send-keys -t serpspot:1.2 'npm run dev' Enter

tmux send-keys -t serpspot:1.3 'cd serpspot_backend' Enter
tmux send-keys -t serpspot:1.3 'celery -A app.tasks.celery worker --loglevel=info --concurrency=1 -Q noti -n NOTI@%h' Enter

#

tmux send-keys -t serpspot:1.4 'cd serpspot_backend' Enter
tmux send-keys -t serpspot:1.4 'python3 -m app.loader' Enter

#

tmux send-keys -t serpspot:1.5 'cd serpspot_backend' Enter
tmux send-keys -t serpspot:1.5 'celery -A app.tasks.celery worker --loglevel=info --concurrency=6 -Q ctrl -n CTRL@%h' Enter

tmux send-keys -t serpspot:1.6 'cd serpspot_backend' Enter
tmux send-keys -t serpspot:1.6 'celery -A app.tasks.celery worker --loglevel=info --concurrency=6 -Q gapi -n GAPI@%h' Enter

tmux send-keys -t serpspot:1.7 'cd serpspot_backend' Enter
tmux send-keys -t serpspot:1.7 'celery -A app.tasks.celery worker --loglevel=info --concurrency=2 -Q aggr -n AGGR@%h' Enter

###

tmux attach -t serpspot
"

alias serpspot="
tmux attach -t serpspot
"

alias kill_serpspot!="
echo 'Killing serpspot session..' && tmux kill-session -t serpspot
"

alias ssh_serpspot="
ssh -L localhost:9990:localhost:5433 -L localhost:9991:localhost:6379 serpspot
"
