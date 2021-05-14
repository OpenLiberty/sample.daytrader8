mkdir -p $HOME/.docker;
echo $'{\n    "experimental": true\n}' | sudo tee /etc/docker/daemon.json;
echo $'{\n    "experimental": "enabled"\n}' | sudo tee $HOME/.docker/config.json;
sudo service docker restart;