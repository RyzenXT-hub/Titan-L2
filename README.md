# Bash Shell Auto Install Titan Node L2 - Cassini Testnet on Ubuntu 22.04+ 
- Install (version v0.1.20_246b9dd) Linux Single Node 
```
curl -O https://raw.githubusercontent.com/RyzenXT-hub/Titan-L2/main/install.sh && chmod u+x install.sh && ./install.sh
```
- If you previously used this auto script, please update your L2 with this
```
wget https://raw.githubusercontent.com/RyzenXT-hub/Titan-L2/main/update_titan.sh && chmod +x update_titan.sh && ./update_titan.sh
```
- Show Info & Config node
```
titan-edge config show && titan-edge info
```
- If errors, delete folder `.titanedge` and reinstall
```
systemctl stop titand.service && rm -rf /root/.titanedge && rm -rf /usr/local/titan && rm ./install.sh
```
- INSTALL for DOCKER nezha123/titan-edge Latest , Auto Detect IP & installation 5 nodes / 1 IP 
```
curl -O https://raw.githubusercontent.com/RyzenXT-hub/Titan-L2/main/docker.sh && chmod u+x docker.sh && ./docker.sh
```
- UNINSTALL DOCKER 
```
systemctl stop docker docker.socket && systemctl disable docker docker.socket && apt-get remove --purge -y docker.io && rm -rf /root/titan_storage_*  /usr/bin/docker /usr/local/bin/docker /usr/bin/dockerd /var/lib/docker /etc/docker && deluser docker && delgroup docker && apt-get autoremove -y && apt-get clean 
```
#What's New : 
- Improved Error Handling
- Animated Loading Feedback
- Color-Coded Messages
- Enhanced Environment Settings Update
- Configuration and Service Management
- Support installation docker 5 nodes / 1 IP 
- Automatic detect IP in your VM and created nodes
- Add custom node , now user can choose how many node they running 
````
#Contact Telegram : https://t.me/Ryzen_XT 

