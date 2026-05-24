# ... custom aliases

alias vpn_on="
wg-quick up wg0
"

alias vpn_off="
wg-quick down wg0
"

alias serpspot_tun="
ssh -L localhost:9990:localhost:5433 -L localhost:9991:localhost:6379 serpspot
"
