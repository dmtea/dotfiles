# dm laptop only

export PATH="$PATH:$HOME/.local/share/yabridge"

export WINEARCH=win64
export WINEPREFIX=~/.wine64

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PIPENV_PYTHON="$PYENV_ROOT/shims/python"

export OLLAMA_MODELS="/mnt/nvme1n1/dev/ollama_models"

eval "$(pyenv init -)"
eval "$(pyenv init --path)"
eval "$(pyenv virtualenv-init -)"

